# Quadrants

Quadrants is a high-performance compiler for CPU/GPU kernels used from Haxe through HashLink. The haxelib package provides Haxe interface sources, while the native `quadrants.hdll` bridge is installed separately as a HashLink native extension. Programs run as HashLink JIT bytecode (`haxe -hl`, then `hl`).

```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;

var ctx = Context.create({arch: Arch.Cpu});
var a = new Tensor<I32>(ctx, [4]);
var out = new Tensor<I32>(ctx, [4]);

final k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>) -> {
  for (i in 0...4) {
    out[i] = a[i] * 2;
  }
});
```

## Documentation

- [User guide](user_guide/index.md)
