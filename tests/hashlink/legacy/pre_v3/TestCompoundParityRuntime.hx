import quadrants.Axis;
import quadrants.CompilerHints;
import quadrants.Context;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.Mat2;
import quadrants.MatrixField;
import quadrants.MatrixNdarray;
import quadrants.Struct;
import quadrants.StructField;
import quadrants.StructMember;
import quadrants.Tensor;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.VectorField;
import quadrants.VectorNdarray;
import quadrants.packed.PackedVectorTensor;
import quadrants.packed.StructOfArraysField;

class TestCompoundParityRuntime {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function testHostCompoundTypes(ctx:Context):Void {
    var vectors = VectorNdarray.i32(ctx, 2, 2);
    vectors.write(0, Vec2.i32(3, 4));
    vectors.writeComponent(1, 0, 7);
    vectors.writeComponent(1, 1, 8);
    expectEq("vector_ndarray_host_x", vectors.readVec2(0)[0], 3);
    expectEq("vector_ndarray_host_y", vectors.read(1)[1], 8);

    var packed = PackedVectorTensor.i32(ctx, 1, 2);
    packed.write(0, Vec2.i32(9, 10));
    var adapted = VectorNdarray.fromPacked(packed);
    expectEq("vector_ndarray_from_packed", adapted.readVec2(0)[1], 10);

    var matrices = MatrixNdarray.i32(ctx, 1, 2, 2);
    matrices.writeMat2(0, Mat2.i32(1, 2, 3, 4));
    expectEq("matrix_ndarray_host", matrices.readMat2(0).get(1, 0), 3);

    var vectorField = VectorField.i32(ctx, 1, 2);
    vectorField.writeVec2(0, Vec2.i32(5, 6));
    expectEq("vector_field_host", vectorField.readComponent(0, 1), 6);

    var matrixField = MatrixField.i32(ctx, 1, 2, 2);
    matrixField.writeMat2(0, Mat2.i32(11, 12, 13, 14));
    expectEq("matrix_field_host", matrixField.readMat2(0).get(1, 1), 14);

    var mass = new Field<I32>(ctx, [2]);
    var tag = new Field<I32>(ctx, [2]);
    var massMember = new StructMember<I32>("mass");
    var tagMember = new StructMember<I32>("tag");
    var structField = new StructField().addMember(massMember, mass).addMember(tagMember, tag);
    structField.writeMember(massMember, 0, 21);
    structField.writeMember(tagMember, 0, 23);
    structField.writeMember(tagMember, 1, 22);
    expectEq("struct_field_mass", structField.readMember(massMember, 0), 21);
    expectEq("struct_field_tag", structField.readMember(tagMember, 1), 22);
    var structValue = structField.readValue2(massMember, tagMember, 0);
    expectEq("struct_field_value_mass", structValue.value0, 21);
    expectEq("struct_field_value_tag", structValue.value1, 23);
    structField.writeValue2(1, Struct.value2(massMember, 31, tagMember, 32));
    expectEq("struct_field_write_value_mass", structField.readMember(massMember, 1), 31);
    expectEq("struct_field_write_value_tag", structField.readMember(tagMember, 1), 32);
    var soa:StructOfArraysField = structField.toStructOfArrays();
    expectEq("struct_field_to_soa", soa.readValue2(massMember, tagMember, 1).value1, 32);

    vectors.close();
    packed.close();
    adapted.close();
    matrices.close();
    vectorField.close();
    matrixField.close();
    structField.close();
  }

  static function testCompoundKernelParameters(ctx:Context):Void {
    var input = VectorNdarray.i32(ctx, 1, 2);
    var output = VectorNdarray.i32(ctx, 2, 2);
    var matrices = MatrixNdarray.i32(ctx, 1, 2, 2);
    var sum = new Tensor<I32>(ctx, [1]);
    var kernel:Kernel = null;
    try {
      input.writeVec2(0, Vec2.i32(2, 5));
      matrices.writeMat2(0, Mat2.i32(1, 2, 3, 4));
      kernel = Kernel.build(ctx, macro (input:VectorNdarray<I32>, output:VectorNdarray<I32>, matrices:MatrixNdarray<I32>, sum:Tensor<I32>) -> {
        var v = input.readVec2(0);
        var shifted = Vec2.i32(v[0] + 10, v[1] + 20);
        output.writeVec2(1, shifted);
        var m = matrices.readMat2(0);
        var safe = CompilerHints.assumeInRange(0, 0, 0, 1);
        matrices.writeMat2(0, Mat2.i32(m[0] + 1, m[1], m[2], m[3] + 1));
        sum[0] = shifted[0] + shifted[1] + m[0] + m[3] + safe;
      });
      kernel.launch(input, output, matrices, sum);
      ctx.sync();
      expectEq("compound_kernel_vec_x", output.readComponent(1, 0), 12);
      expectEq("compound_kernel_vec_y", output.readComponent(1, 1), 25);
      expectEq("compound_kernel_matrix_00", matrices.readElement(0, 0, 0), 2);
      expectEq("compound_kernel_matrix_11", matrices.readElement(0, 1, 1), 5);
      expectEq("compound_kernel_sum", sum.read(0), 42);
    } catch (e:Dynamic) {
      if (kernel != null) kernel.close();
      input.close();
      output.close();
      matrices.close();
      sum.close();
      throw e;
    }
    if (kernel != null) kernel.close();
    input.close();
    output.close();
    matrices.close();
    sum.close();
  }

  static function testPlacedVectorFieldKernel(ctx:Context):Void {
    var raw = new Field<I32>(ctx);
    ctx.root.dense(Axis.i, 2).place(raw);
    ctx.root.destroy();
    var vectorField = VectorField.fromField(raw, 2);
    var sum = new Tensor<I32>(ctx, [1]);
    var kernel:Kernel = null;
    try {
      vectorField.writeVec2(0, Vec2.i32(4, 6));
      kernel = Kernel.build(ctx, macro (field:VectorField<I32>, sum:Tensor<I32>) -> {
        var v = field.readVec2(0);
        field.writeVec2(0, Vec2.i32(v[0] + 1, v[1] + 1));
        sum[0] = v[0] + v[1];
      });
      kernel.launch(vectorField, sum);
      ctx.sync();
      expectEq("vector_field_kernel_sum", sum.read(0), 10);
      expectEq("vector_field_kernel_x", vectorField.readComponent(0, 0), 5);
      expectEq("vector_field_kernel_y", vectorField.readComponent(0, 1), 7);
    } catch (e:Dynamic) {
      if (kernel != null) kernel.close();
      vectorField.close();
      sum.close();
      throw e;
    }
    if (kernel != null) kernel.close();
    vectorField.close();
    sum.close();
  }

  public static function run():Void {
    TestRuntimeSupport.runEachRuntimeContext(function(_name, ctx) {
      testHostCompoundTypes(ctx);
      testCompoundKernelParameters(ctx);
      testPlacedVectorFieldKernel(ctx);
    });
  }
}
