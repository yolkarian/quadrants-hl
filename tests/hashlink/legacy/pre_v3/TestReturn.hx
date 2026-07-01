import quadrants.Context;
import quadrants.Kernel;
import quadrants.Types.Arch;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Types.F16;
import quadrants.Types.F32;

class TestReturn {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectBool(name:String, got:Bool, expected:Bool):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    var ctx = new Context(Arch.Cpu);
    var sum:Kernel = null;
    var positive:Kernel = null;
    var scale:Kernel = null;
    var tuple:Kernel = null;
    var vectorRet:Kernel = null;
    var matrixRet:Kernel = null;
    var structRet:Kernel = null;
    var half:Kernel = null;
    try {
      var values = new Tensor<I32>(ctx, [4]);
      for (i in 0...4) values.write(i, i + 1);

      sum = Kernel.build(ctx, macro (values, n) -> {
        var acc = 0;
        for (i in 0...n) {
          acc += values[i];
        }
        return acc;
      });
      var got:Int = sum.launchRet(values, 4);
      expectEq("return_sum", got, 10);
      sum.close();
      sum = null;

      positive = Kernel.build(ctx, macro (value:Int) -> {
        return value > 0;
      });
      var isPositive:Bool = positive.launchRet(3);
      expectBool("return_bool_true", isPositive, true);
      isPositive = positive.launchRet(-1);
      expectBool("return_bool_false", isPositive, false);
      positive.close();
      positive = null;

      scale = Kernel.build(ctx, macro (value:quadrants.Types.F32) -> {
        return value * 2.0;
      });
      var scaled:Float = scale.launchRet(1.25);
      if (Math.abs(scaled - 2.5) > 0.0001) throw 'return_f32: ${scaled} != 2.5';
      scale.close();
      scale = null;

      half = Kernel.build(ctx, macro (value:quadrants.Types.F16) -> {
        return value + 1.5;
      });
      var halfOut:Float = half.launchRet(2.0);
      if (Math.abs(halfOut - 3.5) > 0.0001) throw 'return_f16: ${halfOut} != 3.5';
      half.close();
      half = null;

      tuple = Kernel.build(ctx, macro (value:Int) -> {
        return [value + 1, value * 3];
      });
      var tupleOut = tuple.launchRets(4);
      expectEq("return_tuple_len", tupleOut.length, 2);
      expectEq("return_tuple0", tupleOut[0], 5);
      expectEq("return_tuple1", tupleOut[1], 12);
      tuple.close();
      tuple = null;

      vectorRet = Kernel.build(ctx, macro (value:Int) -> {
        var v = quadrants.Vec3.i32(value, value + 1, value + 2);
        return v;
      });
      var vectorOut = vectorRet.launchRets(7);
      expectEq("return_vector_len", vectorOut.length, 3);
      expectEq("return_vector0", vectorOut[0], 7);
      expectEq("return_vector1", vectorOut[1], 8);
      expectEq("return_vector2", vectorOut[2], 9);
      vectorRet.close();
      vectorRet = null;

      matrixRet = Kernel.build(ctx, macro (value:Int) -> {
        var m = quadrants.Matrix.ofArray(2, 2, [value, value + 1, value + 2, value + 3]);
        return m;
      });
      var matrixOut = matrixRet.launchRets(3);
      expectEq("return_matrix_len", matrixOut.length, 4);
      expectEq("return_matrix0", matrixOut[0], 3);
      expectEq("return_matrix1", matrixOut[1], 4);
      expectEq("return_matrix2", matrixOut[2], 5);
      expectEq("return_matrix3", matrixOut[3], 6);
      matrixRet.close();
      matrixRet = null;

      structRet = Kernel.build(ctx, macro (value:Int) -> {
        var s = quadrants.Struct.of3("first", value, "second", value + 1, "third", value + 2);
        return s;
      });
      var structOut = structRet.launchRets(11);
      expectEq("return_struct_len", structOut.length, 3);
      expectEq("return_struct0", structOut[0], 11);
      expectEq("return_struct1", structOut[1], 12);
      expectEq("return_struct2", structOut[2], 13);
      structRet.close();
      structRet = null;


      ctx.close();
    } catch (e:Dynamic) {
      if (sum != null) sum.close();
      if (positive != null) positive.close();
      if (scale != null) scale.close();
      if (half != null) half.close();
      if (tuple != null) tuple.close();
      if (vectorRet != null) vectorRet.close();
      if (matrixRet != null) matrixRet.close();
      if (structRet != null) structRet.close();
      ctx.close();
      throw e;
    }
  }
}
