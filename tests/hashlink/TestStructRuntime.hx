import quadrants.Context;
import quadrants.Kernel;
import quadrants.Struct;
import quadrants.Types.I32;

typedef PairData = {
  var first:I32;
  var second:I32;
}

typedef InnerParticle = {
  var mass:I32;
  var velocity:I32;
}

typedef ParticleData = {
  var inner:InnerParticle;
  var id:I32;
}

class TestStructRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx:Context) {
      var directKernel:Kernel = null;
      var nestedKernel:Kernel = null;
      try {
        directKernel = Kernel.build(ctx, macro (value:Int) -> {
          return {first: value, second: value + 1};
        });
        var directRaw = directKernel.launchRets(7);
        var pair:PairData = Struct.decodeSchema({first: 0, second: 0}, directRaw);
        expectEq('struct_decode_first', pair.first, 7);
        expectEq('struct_decode_second', pair.second, 8);
        directKernel.close();
        directKernel = null;

        nestedKernel = Kernel.build(ctx, macro (value:Int) -> {
          var inner = {mass: value, velocity: value + 1};
          var particle = {inner: inner, id: value + 2};
          return particle;
        });
        var nestedRaw = nestedKernel.launchRets(11);
        var particle:ParticleData = Struct.decodeSchema({inner: {mass: 0, velocity: 0}, id: 0}, nestedRaw);
        expectEq('struct_decode_nested_mass', particle.inner.mass, 11);
        expectEq('struct_decode_nested_velocity', particle.inner.velocity, 12);
        expectEq('struct_decode_nested_id', particle.id, 13);
        nestedKernel.close();
        nestedKernel = null;
      } catch (e:Dynamic) {
        if (directKernel != null) directKernel.close();
        if (nestedKernel != null) nestedKernel.close();
        throw e;
      }
    });
  }
}
