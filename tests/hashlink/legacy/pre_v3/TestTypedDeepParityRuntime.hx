import quadrants.Axis;
import quadrants.Context;
import quadrants.Field;
import quadrants.Mesh;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.mesh.MeshKinds;
import quadrants.quant.Quant;
import quadrants.quant.QuantBits;
import quadrants.quant.QuantSignedness;
import quadrants.quant.QuantizedF32Tensor;
import quadrants.snode.FieldTree;

class TestTypedDeepParityRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function expectNear(name:String, got:Float, expected:Float):Void {
    if (Math.abs(got - expected) > 0.0001) throw '${name}: ${got} != ${expected}';
  }

  static function expectThrowsContains(name:String, body:()->Void, fragment:String):Void {
    try {
      body();
    } catch (e:Dynamic) {
      if (Std.string(e).indexOf(fragment) >= 0) {
        return;
      }
      throw '${name}: wrong error ${Std.string(e)}';
    }
    throw '${name}: expected error containing ${fragment}';
  }

  static function testTypedMesh(ctx:Context):Void {
    var mesh = new Mesh(3, 1, 1);
    var vertices = mesh.typedVertices();
    var faces = mesh.typedFaces();
    var v1 = vertices.get(1);
    var f0 = faces.get(0);
    var vertexToFace = mesh.relation(MeshKinds.vertex, MeshKinds.face);
    vertexToFace.set(v1, [f0]);
    expectEq("typed_mesh_relation_size", vertexToFace.size(v1), 1);
    expectEq("typed_mesh_relation_access", vertexToFace.get(v1, 0).index, 0);

    var sum = 0;
    for (vertex in vertices) {
      sum += vertex.index;
    }
    expectEq("typed_mesh_traversal", sum, 3);

    var mass = new Field<I32>(ctx, [vertices.count()]);
    var massAttr = mesh.attribute(MeshKinds.vertex, mass);
    massAttr.write(v1, 42);
    expectEq("typed_mesh_attribute", massAttr.read(v1), 42);
    mass.close();
  }

  static function testTypedQuant(ctx:Context):Void {
    var spec = Quant.fixedF32(QuantBits.Bits8, QuantSignedness.Signed, 4);
    var values = new QuantizedF32Tensor(ctx, [2], spec);
    values.write(0, 1.5);
    values.write(1, -2.0);
    expectEq("typed_quant_raw_0", values.readRaw(0), 24);
    expectEq("typed_quant_raw_1", values.readRaw(1), -32);
    expectNear("typed_quant_value_0", values.read(0), 1.5);
    expectNear("typed_quant_value_1", values.read(1), -2.0);
    values.close();

    expectThrowsContains("typed_quant_invalid_fractional_bits", function() {
      Quant.fixedF32(QuantBits.Bits8, QuantSignedness.Signed, 8);
    }, "fractional bits");

    var qfloatField = new Field<F32>(ctx);
    var qfloatSpec = Quant.floatF32(5, 10, QuantSignedness.Signed);
    ctx.root.dense(Axis.i, 1).bitStruct(QuantBits.Bits32).placeQuant(qfloatField, qfloatSpec);
    qfloatField.write(0, 1.5);
    expectNear("typed_quant_bitstruct_float", qfloatField.read(0), 1.5);
    qfloatField.close();

    var nativeField = new Field<F32>(ctx);
    ctx.root.quantArray(Axis.i, 4, QuantBits.Bits32).placeQuant(nativeField, spec);
    var nativeRuntime:quadrants.FieldRuntime = cast nativeField;
    if (!nativeRuntime.hasSNode()) {
      throw "typed_quant_native_field: expected SNode placement";
    }
    nativeField.write(0, 1.53);
    nativeField.write(1, -2.0);
    expectNear("typed_quant_native_value_0", nativeField.read(0), 1.5);
    expectNear("typed_quant_native_value_1", nativeField.read(1), -2.0);
    nativeField.close();
    ctx.root.destroy();
  }

  static function testTypedSNodePath(ctx:Context):Void {
    var a = new Field<I32>(ctx);
    var b = new Field<I32>(ctx);
    var path = ctx.root.dense(Axis.i, 2).finalize();
    path.placeFields([a, b]);
    a.write(0, 7);
    b.write(1, 11);
    expectEq("typed_snode_place_a", a.read(0), 7);
    expectEq("typed_snode_place_b", b.read(1), 11);
    var grad = FieldTree.lazyFieldGrad(a);
    grad.write(0, 13);
    expectEq("typed_snode_grad", a.grad.read(0), 13);
    ctx.root.destroy();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testTypedMesh(ctx);
      testTypedQuant(ctx);
      testTypedSNodePath(ctx);
    });
  }
}
