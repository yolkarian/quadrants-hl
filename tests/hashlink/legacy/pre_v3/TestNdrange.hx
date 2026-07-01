import quadrants.Context;
import quadrants.AxisOrder;
import quadrants.Kernel;
import quadrants.Grid;
import quadrants.Grouped;
import quadrants.Ndrange;
import quadrants.Tensor;
import quadrants.Types.I32;

class TestNdrange {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static inline var SECTION_STATEMENTS = 7;
  static inline var STMT_RANGE_FOR = 3;

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static function sectionOffset(bytes:hl.Bytes, kind:Int):Int {
    var sectionCount = u32(bytes, 8);
    for (i in 0...sectionCount) {
      var entry = 20 + i * 12;
      if (u32(bytes, entry) == kind) {
        return u32(bytes, entry + 4);
      }
    }
    throw 'descriptor section ${kind} is missing';
  }

  static function expectOuterLoopLocalId(name:String, descriptor:hl.Bytes, expected:Int):Void {
    var statementsOffset = sectionOffset(descriptor, SECTION_STATEMENTS);
    var firstStatement = statementsOffset + 8;
    expectEq('${name}_opcode', descriptor.getUI8(firstStatement), STMT_RANGE_FOR);
    expectEq('${name}_local', u32(descriptor, firstStatement + 1), expected);
  }

  static function testAxesDescriptor():Void {
    var identity = Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32) -> {
      for (I in Ndrange.of2(rows, cols)) {
        out[0] = I[0] + I[1];
      }
    });
    expectOuterLoopLocalId("ndrange_axes_identity", identity, 0);

    var swapped = Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32) -> {
      for (I in Ndrange.of2Axes(rows, cols, AxisOrder.of2(1, 0))) {
        out[0] = I[0] + I[1];
      }
    });
    expectOuterLoopLocalId("ndrange_axes_swapped", swapped, 1);

    var grouped = Kernel.descriptorBytes(macro (out:Tensor<I32>, rows:I32, cols:I32, depth:I32) -> {
      for (G in Grouped.of(Ndrange.of3Axes(rows, cols, depth, AxisOrder.of3(2, 0, 1)))) {
        out[0] = G[0] + G[1] + G[2];
      }
    });
    expectOuterLoopLocalId("grouped_axes_order", grouped, 2);
  }

  public static function run():Void {
    testAxesDescriptor();
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      var k:Kernel = null;
      try {
        var out = new Tensor<I32>(ctx, [6]);
        var axesOut = new Tensor<I32>(ctx, [6]);
        var groupedOut = new Tensor<I32>(ctx, [24]);
        k = Kernel.build(ctx, macro (b:Tensor<I32>, axes:Tensor<I32>, grouped:Tensor<I32>, rows:I32, cols:I32, depth:I32) -> {
          for (i in 0...b.shape(0)) {
            b[i] = -1;
          }
          for (i in 0...axes.shape(0)) {
            axes[i] = -1;
          }
          for (i in 0...grouped.shape(0)) {
            grouped[i] = -1;
          }
          for (I in Ndrange.of(rows, cols)) {
            b[I[0] * cols + I[1]] = I[0] * 10 + I[1] + (Grid.threadIdx() >= 0 ? 0 : Grid.threadIdx());
          }
          for (I in Ndrange.ranges(1, rows, 1, cols)) {
            b[I[0] * cols + I[1]] += 100;
          }
          for (J in Grouped.of(cols)) {
            b[J[0]] += 10;
          }
          for (I in Ndrange.of2Axes(rows, cols, AxisOrder.of2(1, 0))) {
            axes[I[0] * cols + I[1]] = I[0] * 10 + I[1];
          }
          for (G in Grouped.of(Ndrange.of3Axes(rows, cols, depth, AxisOrder.of3(2, 0, 1)))) {
            grouped[(G[0] * cols + G[1]) * depth + G[2]] = G[0] * 100 + G[1] * 10 + G[2];
          }
        });
        k.launch(out, axesOut, groupedOut, 2, 3, 4);
        ctx.sync();
        expectEq("ndrange0", out.read(0), 10);
        expectEq("ndrange4", out.read(4), 111);
        expectEq("ndrange5", out.read(5), 112);
        expectEq("ndrange_axes0", axesOut.read(0), 0);
        expectEq("ndrange_axes4", axesOut.read(4), 11);
        expectEq("ndrange_axes5", axesOut.read(5), 12);
        expectEq("grouped_axes0", groupedOut.read(0), 0);
        expectEq("grouped_axes6", groupedOut.read(6), 12);
        expectEq("grouped_axes23", groupedOut.read(23), 123);
      } catch (e:Dynamic) {
        TestRuntimeSupport.closeKernel(k);
        throw e;
      }
      TestRuntimeSupport.closeKernel(k);
    });
  }
}
