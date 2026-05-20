# Getting started with Haxe/HashLink

Quadrants is used from Haxe by compiling your Haxe program to HashLink bytecode (`.hl`) and running it with the HashLink JIT (`hl`). The Haxe macro frontend emits a compact kernel descriptor at Haxe compile time; `quadrants.hdll` compiles and launches that kernel through the Quadrants native runtime at run time.

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
import quadrants.Types.Arch;

class Main {
  static function main():Void {
    final n = 16;
    var ctx = new Context(Arch.Cpu);
    var input = ctx.ndarrayI32([n]);
    var output = ctx.ndarrayI32([n]);

    for (i in 0...n) {
      input.writeI32(i, i + 1);
      output.writeI32(i, 0);
    }

    var k = Kernel.build(ctx, macro (input, output, n) -> {
      for (i in 0...n) {
        output[i] = input[i] * 2;
      }
    });

    k.launch(input, output, n);
    ctx.sync();

    for (i in 0...n) {
      if (output.readI32(i) != (i + 1) * 2) {
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

- Read [Haxe/HashLink public API](haxe_api.md) for the replacement surface for the old Python binding.
- Read [Haxe kernel language](kernel_language.md) for the supported kernel DSL subset.
- Read [Supported systems](supported_systems.md) before enabling CUDA, Vulkan, Metal, or AMDGPU.
