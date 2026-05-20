# Quadrants

Quadrants is a high-performance compiler for CPU/GPU kernels used from Haxe through HashLink. The public package consists of haxelib-compatible Haxe sources and the native `quadrants.hdll` bridge, executed as HashLink JIT bytecode (`haxe -hl`, then `hl`).

```haxe
import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;

var ctx = new Context(Arch.Cpu);
var a = ctx.ndarrayI32([4]);
var out = ctx.ndarrayI32([4]);

final k = Kernel.build(ctx, macro (a, out) -> {
  for (i in 0...4) {
    out[i] = a[i] * 2;
  }
});
```

```{toctree}
:caption: Quadrants
:maxdepth: 2

user_guide/index
```
