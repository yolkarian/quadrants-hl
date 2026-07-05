# Getting started with Haxe/HashLink

Quadrants is used from Haxe by compiling your Haxe program to HashLink bytecode (`.hl`) and running it with the HashLink JIT (`hl`). The Haxe macro frontend emits a QDHL v3 descriptor with canonical type/arg/resource tables and KernelIr at Haxe compile time; `quadrants.hdll` validates, specializes, compiles, and launches that kernel through the Quadrants native runtime at run time.

## Prerequisites

- `haxe` and `hl` on `PATH`.
- `quadrants.hdll` installed as a HashLink native extension; see [Haxe/HashLink integration](hashlink.md#build-and-install).
- Runtime bitcode installed next to the native extension, usually `runtime_x64.bc` or `runtime_arm64.bc` for `Arch.Cpu`.

## Install-tree quick start

After installing the native HashLink component and installing/registering the haxelib interface, create a program:


```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class Main {
  static function main():Void {
    final n = 16;
    var ctx = Context.create({arch: Arch.Cpu});
    var input = new Tensor<I32>(ctx, [n]);
    var output = new Tensor<I32>(ctx, [n]);

    for (i in 0...n) {
      input.write(i, i + 1);
      output.write(i, 0);
    }

    var k = Kernel.build(ctx, macro (input:Tensor<I32>, output:Tensor<I32>, n:Int) -> {
      for (i in 0...n) {
        output[i] = input[i] * 2;
      }
    });

    k.launch(input, output, n);
    ctx.sync();

    for (i in 0...n) {
      if (output.read(i) != (i + 1) * 2) {
        throw 'bad result at $i';
      }
    }

    k.close();
    ctx.close();
    Sys.println("quadrants hashlink ok");
  }
}
```

Compile to HashLink bytecode and run it with the JIT:

```bash
haxe -lib quadrants -main Main -hl build/main.hl
hl build/main.hl
```

Expected output:

```text
quadrants hashlink ok
```

## Build-tree quick start

When using a HashLink checkout/build tree directly, install the native files next to that checkout's `hl`, then compile normally. The `.hl` file records only the logical native library name `quadrants`.

```bash
scripts/install_hashlink_native.sh \
  --build-dir "$QD_BUILD_DIR" \
  --runtime-dir "$QD_BUILD_DIR/runtime" \
  --hashlink-dir "$QD_HASHLINK_ROOT"
haxe -cp bindings/hashlink/haxe -main Main -hl build/main.hl
"$QD_HASHLINK_ROOT/hl" build/main.hl
```

For a no-sudo prefix install, install HashLink and Quadrants under the same user prefix, for example `$HOME/.local`, and run the matching `$HOME/.local/bin/hl`.

## Next steps

- Read [Haxe/HashLink API](haxe_api.md) for the typed public API.
- Read [Haxe kernels](haxe_kernel_v3.md) and [Haxe kernel language](kernel_language.md) for the supported kernel DSL subset.
- Read [Supported systems](supported_systems.md) before enabling CUDA, Vulkan, Metal, or AMDGPU.
