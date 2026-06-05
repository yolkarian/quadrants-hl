import quadrants.Context;
import quadrants.Field;
import quadrants.StructField;
import quadrants.StructMember;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.VectorNdarray;
import quadrants.compat.PerfBaseline;
import quadrants.packed.PackedVectorTensor;

class TestReleaseReadinessRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectTrue(name:String, value:Bool):Void {
    if (!value) throw '${name}: expected true';
  }

  static function testMigrationExamples(ctx:Context):Void {
    var packed = PackedVectorTensor.i32(ctx, 1, 2);
    packed.write(0, Vec2.i32(3, 4));
    var finalVector = VectorNdarray.fromPacked(packed);
    expectEq("release_migrate_vector", finalVector.readVec2(0)[1], 4);
    var packedAgain = finalVector.toPacked();
    expectEq("release_migrate_vector_back", packedAgain.readComponent(0, 0), 3);

    var id = new StructMember<I32>("id");
    var idField = new Field<I32>(ctx, [1]);
    var particles = new StructField().addMember(id, idField);
    particles.writeMember(id, 0, 17);
    expectEq("release_typed_struct_member", particles.readMember(id, 0), 17);

    particles.close();
    finalVector.close();
  }

  static function testPerfBaselineHarness(ctx:Context):Void {
    var values = new Tensor<I32>(ctx, [4]);
    var sample = PerfBaseline.measure("release-noop-baseline", 3, function() {
      values.write(0, values.read(0) + 1);
    });
    expectEq("release_perf_iterations", sample.iterations, 3);
    expectTrue("release_perf_seconds", sample.seconds >= 0.0);
    expectTrue("release_perf_seconds_per_iteration", sample.secondsPerIteration >= 0.0);
    values.close();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testMigrationExamples(ctx);
      testPerfBaselineHarness(ctx);
    });
  }
}
