# Haxe/HashLink integration

Quadrants ships an optional HashLink native bridge, `quadrants.hdll`, for Haxe DSL experiments. Haxe owns the syntax and macro-time descriptor generation; the native bridge owns Quadrants context creation, kernel compilation, ndarray memory, launch, and synchronization.

Build the bridge explicitly. For a build-tree CUDA run on x86_64 Linux, also stage the LLVM runtime bitcode that the standalone HashLink process needs at JIT time:

```bash
cmake -S . -B build/hashlink-bridge -DQD_WITH_HASHLINK=ON -DQD_HASHLINK_ROOT=../hashlink -DQD_WITH_CUDA=ON -DCUDAToolkit_ROOT=/usr/local/cuda -DQD_WITH_VULKAN=OFF -DQD_WITH_METAL=OFF
cmake --build build/hashlink-bridge --target quadrants.hdll generate_llvm_runtime_x64 generate_llvm_runtime_cuda
mkdir -p build/hashlink-bridge/runtime
cp quadrants/runtime/llvm/runtime_module/runtime_{x64,cuda}.bc external/cuda_libdevice/slim_libdevice.10.bc build/hashlink-bridge/runtime/
```

Compile Haxe code with the bindings on the class path. Put `quadrants.hdll` on the dynamic-library path, and point `QD_LIB_DIR` at the staged runtime bitcode directory:

```bash
haxe -cp bindings/hashlink/haxe -cp bindings/hashlink/tests -main HashLinkBridgeTest -hl hashlink_bridge_test.hl
LD_LIBRARY_PATH="$PWD/build/hashlink-bridge:/usr/local/cuda/lib64:$LD_LIBRARY_PATH" QD_LIB_DIR="$PWD/build/hashlink-bridge/runtime" hl hashlink_bridge_test.hl
```

Minimal API:

```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

var ctx = new Context(Arch.Cuda);
var a = ctx.ndarrayI32([16]);
var b = ctx.ndarrayI32([16]);
var out = ctx.ndarrayI32([16]);
// Or use the generic form for another primitive dtype:
// var f:quadrants.Tensor<quadrants.Types.F32> = ctx.ndarrayF32([16]);
// Multi-dimensional host indexing helpers are available as readI32At/writeI32At, readF32At/writeF32At, etc.

final k = Kernel.build(ctx, macro (a, b, out, n) -> {
  for (i in 0...n) {
    out[i] = a[i] + b[i];
  }
});

k.launch(a, b, out, 16);
ctx.sync();
k.close();
ctx.close();
```

The bridge supports contexts for the backend enabled in the native build and primitive ndarrays (`I8`, `I16`, `I32`, `I64`, `U8`, `U16`, `U32`, `U64`, `F32`, `F64`). The descriptor decoder and launcher validate primitive scalar/ndarray dtypes; typed kernel arguments such as `Tensor<quadrants.Types.F32>` and scalar `Int`/`Float`/`haxe.Int64` are reflected into the descriptor. The macro supports one-dimensional and nested ndarray indexing, range-for loops, `while`, `break`, `continue`, `if`, expression-level `if`/select, local variable assignment, ndarray element stores, atomic `+=`/`-=`, arithmetic (`+`, `-`, `*`, `/`, `%`), comparison, boolean, integer bitwise expressions, unary `!`, unary `-`, bitwise `~`, basic math calls (`abs`, `sin`, `cos`, `tan`, `exp`, `log`, `sqrt`, `floor`, `ceil`, `min`, `max`), and explicit casts to supported primitive scalar types. Lightweight host-side `Vector` and `Matrix` helpers are also available for elementwise Haxe code. Unsupported Haxe constructs are rejected by the macro instead of being lowered silently.

Call `close()` on kernels and contexts when finished. Native finalizers are a safety net, not the primary lifetime mechanism.
