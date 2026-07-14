package quadrants.sparse;

import quadrants.Context;
import quadrants.Field;
import quadrants.FieldRuntime;
import quadrants.FieldsBuilder;
import quadrants.Kernel;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.F64;
import quadrants.Types.I32;
import quadrants.kernel.QKernel2;

/**
 * Bitmasked sparse grid with named member fields sharing one bitmasked parent,
 * mirroring the Python binding's `qd.sparse.grid(...)` / `qd.sparse.usage(...)` helpers.
 *
 * Declare members before `commit()`; writes (host or kernel) activate cells, and
 * `activeCount()` / `usage()` report bitmasked occupancy by iterating active cells
 * with a field struct-for.
 */
class SparseGrid {
  public final context:Context;
  public final dims:Array<Int>;
  final memberNames:Array<String> = [];
  final memberRuntimes:Array<FieldRuntime> = [];
  final membersByName = new Map<String, Dynamic>();
  var committed:Bool = false;
  var closed:Bool = false;
  var countKernel2F32:QKernel2<Field<F32>, Tensor<I32>, Void> = null;
  var countKernel2I32:QKernel2<Field<I32>, Tensor<I32>, Void> = null;
  var countKernel2F64:QKernel2<Field<F64>, Tensor<I32>, Void> = null;
  var countKernel3F32:QKernel2<Field<F32>, Tensor<I32>, Void> = null;
  var countKernel3I32:QKernel2<Field<I32>, Tensor<I32>, Void> = null;
  var countKernel3F64:QKernel2<Field<F64>, Tensor<I32>, Void> = null;

  function new(context:Context, dims:Array<Int>) {
    if (context == null) {
      throw "Quadrants SparseGrid requires a Context";
    }
    if (dims == null || (dims.length != 2 && dims.length != 3)) {
      throw "Quadrants SparseGrid supports 2D and 3D grids";
    }
    for (dim in dims) {
      if (dim <= 0) {
        throw "Quadrants SparseGrid dimensions must be positive";
      }
    }
    this.context = context;
    this.dims = [for (dim in dims) dim];
  }

  public static function create2(context:Context, width:Int, height:Int):SparseGrid {
    return new SparseGrid(context, [width, height]);
  }

  public static function create3(context:Context, width:Int, height:Int, depth:Int):SparseGrid {
    return new SparseGrid(context, [width, height, depth]);
  }

  function requireMutable(name:String):Void {
    if (closed) {
      throw "Quadrants SparseGrid is closed";
    }
    if (committed) {
      throw "Quadrants SparseGrid members must be declared before commit()";
    }
    if (name == null || name.length == 0) {
      throw "Quadrants SparseGrid member name is required";
    }
    if (membersByName.exists(name)) {
      throw 'Quadrants SparseGrid member ${name} is already declared';
    }
  }

  function register(name:String, runtime:FieldRuntime, member:Dynamic):Void {
    memberNames.push(name);
    memberRuntimes.push(runtime);
    membersByName.set(name, member);
  }

  public function addF32(name:String):Field<F32> {
    requireMutable(name);
    var field = new Field<F32>(context, null);
    register(name, cast field, field);
    return field;
  }

  public function addF64(name:String):Field<F64> {
    requireMutable(name);
    var field = new Field<F64>(context, null);
    register(name, cast field, field);
    return field;
  }

  public function addI32(name:String):Field<I32> {
    requireMutable(name);
    var field = new Field<I32>(context, null);
    register(name, cast field, field);
    return field;
  }

  public function commit():SparseGrid {
    if (closed) {
      throw "Quadrants SparseGrid is closed";
    }
    if (committed) {
      throw "Quadrants SparseGrid is already committed";
    }
    if (memberRuntimes.length == 0) {
      throw "Quadrants SparseGrid requires at least one member field";
    }
    var steps:Array<FieldPlacementStep> = [
      {kind: FieldsBuilder.SNODE_BITMASKED, axes: [for (axis in 0...dims.length) axis], sizes: [for (dim in dims) dim], chunkSize: 128},
    ];
    FieldsBuilder.placeFieldsWithSteps(context, memberRuntimes, dims, steps);
    committed = true;
    return this;
  }

  public function fieldF32(name:String):Field<F32> {
    return cast requireMember(name);
  }

  public function fieldF64(name:String):Field<F64> {
    return cast requireMember(name);
  }

  public function fieldI32(name:String):Field<I32> {
    return cast requireMember(name);
  }

  function requireMember(name:String):Dynamic {
    if (!membersByName.exists(name)) {
      throw 'Quadrants SparseGrid has no member ${name}';
    }
    return membersByName.get(name);
  }

  public function memberCount():Int {
    return memberNames.length;
  }

  public function total():Int {
    var count = 1;
    for (dim in dims) {
      count *= dim;
    }
    return count;
  }

  public function activeCount():Int {
    requireCommitted();
    var counter = new Tensor<I32>(context, [1]);
    try {
      counter.fill(0);
      var probe = memberRuntimes[0];
      launchCount(probe, counter);
      context.sync();
      var active = counter.toArray()[0];
      counter.close();
      return active;
    } catch (e:Dynamic) {
      counter.close();
      throw e;
    }
  }

  public function usage():Float {
    return activeCount() / total();
  }

  function requireCommitted():Void {
    if (closed) {
      throw "Quadrants SparseGrid is closed";
    }
    if (!committed) {
      throw "Quadrants SparseGrid requires commit() before use";
    }
  }

  function launchCount(probe:FieldRuntime, counter:Tensor<I32>):Void {
    var name = memberNames[0];
    var member = membersByName.get(name);
    switch (probe.dtype) {
      case quadrants.Types.DType.F32:
        if (dims.length == 2) {
          if (countKernel2F32 == null) {
            countKernel2F32 = Kernel.build(context, macro (cells:Field<F32>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 2)) {
                out[0] += 1;
              }
            });
          }
          countKernel2F32.launch(cast member, counter);
        } else {
          if (countKernel3F32 == null) {
            countKernel3F32 = Kernel.build(context, macro (cells:Field<F32>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 3)) {
                out[0] += 1;
              }
            });
          }
          countKernel3F32.launch(cast member, counter);
        }
      case quadrants.Types.DType.I32:
        if (dims.length == 2) {
          if (countKernel2I32 == null) {
            countKernel2I32 = Kernel.build(context, macro (cells:Field<I32>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 2)) {
                out[0] += 1;
              }
            });
          }
          countKernel2I32.launch(cast member, counter);
        } else {
          if (countKernel3I32 == null) {
            countKernel3I32 = Kernel.build(context, macro (cells:Field<I32>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 3)) {
                out[0] += 1;
              }
            });
          }
          countKernel3I32.launch(cast member, counter);
        }
      case quadrants.Types.DType.F64:
        if (dims.length == 2) {
          if (countKernel2F64 == null) {
            countKernel2F64 = Kernel.build(context, macro (cells:Field<F64>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 2)) {
                out[0] += 1;
              }
            });
          }
          countKernel2F64.launch(cast member, counter);
        } else {
          if (countKernel3F64 == null) {
            countKernel3F64 = Kernel.build(context, macro (cells:Field<F64>, out:Tensor<I32>) -> {
              for (I in quadrants.Grouped.of(cells, 3)) {
                out[0] += 1;
              }
            });
          }
          countKernel3F64.launch(cast member, counter);
        }
      default:
        throw "Quadrants SparseGrid usage counting supports I32, F32, and F64 members";
    }
  }

  public function close():Void {
    if (closed) {
      return;
    }
    if (countKernel2F32 != null) countKernel2F32.close();
    if (countKernel2I32 != null) countKernel2I32.close();
    if (countKernel2F64 != null) countKernel2F64.close();
    if (countKernel3F32 != null) countKernel3F32.close();
    if (countKernel3I32 != null) countKernel3I32.close();
    if (countKernel3F64 != null) countKernel3F64.close();
    for (runtime in memberRuntimes) {
      runtime.close();
    }
    closed = true;
  }
}
