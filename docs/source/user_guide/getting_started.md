# Getting started with Haxe/HashLink

Quadrants is used from Haxe by compiling your Haxe program to HashLink bytecode (`.hl`) and running it with the HashLink JIT (`hl`). The Haxe macro frontend emits a QDHL v3 descriptor with canonical type/arg/resource tables and KernelIr at Haxe compile time; `quadrants.hdll` validates, specializes, compiles, and launches that kernel through the Quadrants native runtime at run time.

## Prerequisites

- `haxe` and `hl` on `PATH`.
- A built or installed `quadrants.hdll`; see [Haxe/HashLink integration](hashlink.md#build-and-install).
- Runtime bitcode for JIT backends, usually `runtime_x64.bc` or `runtime_arm64.bc` for `Arch.Cpu`.

## Install-tree quick start

After installing the HashLink component, register the Haxe package:

```bash
haxelib dev quadrants "$QD_INSTALL_DIR/share/quadrants/hashlink"
```

Create `Main.hx`:

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

When using the source tree directly, point the Haxe macro at the bridge and runtime directory while compiling:

```bash
QUADRANTS_HDLL="$QD_BUILD_DIR/quadrants.hdll" \
QUADRANTS_RUNTIME_DIR="$QD_BUILD_DIR/runtime" \
haxe -cp bindings/hashlink/haxe -main Main -hl build/main.hl
QD_LIB_DIR="$QD_BUILD_DIR/runtime" \
LD_LIBRARY_PATH="$QD_BUILD_DIR:${LD_LIBRARY_PATH:-}" \
hl build/main.hl
```

The same values can also be passed as Haxe defines:

```bash
haxe -cp bindings/hashlink/haxe -D quadrants_hdll_path="$QD_BUILD_DIR/quadrants.hdll" -D quadrants_runtime_dir="$QD_BUILD_DIR/runtime" -main Main -hl build/main.hl
```

## Next steps

- Read [Haxe/HashLink API v3](haxe_api_v3.md) for the recommended typed API.
- Read [Haxe kernels v3](haxe_kernel_v3.md) and [Haxe kernel language](kernel_language.md) for the supported kernel DSL subset.
- Read [Supported systems](supported_systems.md) before enabling CUDA, Vulkan, Metal, or AMDGPU.
