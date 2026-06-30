import quadrants.Kernel;
import quadrants.CompilerHints;
import quadrants.Block;
import quadrants.Vec3;
import quadrants.Vector;
import quadrants.Spec;
import quadrants.Static;
import quadrants.Shared;
import quadrants.Struct;
import quadrants.Mat2;
import quadrants.Matrix;
import quadrants.MatrixNdarray;
import quadrants.Tensor;
import quadrants.Field;
import quadrants.Mesh;
import quadrants.VectorNdarray;
import quadrants.mesh.Edge;
import quadrants.mesh.MeshRelation;
import quadrants.mesh.Vertex;
import quadrants.Types.I8;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U32;
import quadrants.Types.U1;
import quadrants.Types.F16;
import quadrants.Types.F32;
import quadrants.simt.BlockReduce;
import quadrants.simt.BlockScan;

class TestDescriptorSnapshot {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  static inline var PARAM_SCALAR = 0;
  static inline var PARAM_NDARRAY = 1;
  static inline var PARAM_FIELD = 2;
  static inline var PARAM_MESH_RELATION = 3;
  static inline var PARAM_FLAG_SPEC = 2;
  static inline var DTYPE_I32 = 2;
  static inline var SECTION_SYMBOLS = 5;
  static inline var SECTION_STATEMENTS = 7;
  static inline var SECTION_FUNCTIONS = 8;
  static inline var SECTION_TYPE_TABLE = 11;
  static inline var SECTION_RESOURCE_TABLE = 12;
  static inline var SECTION_STRUCT_TABLE = 13;
  static inline var SECTION_SPEC_TABLE = 14;
  static inline var SECTION_ARG_TABLE = 15;
  static inline var STMT_RETURN_VALUE = 12;
  static inline var EXPR_CAST = 25;
  static inline var EXPR_ASSUME_IN_RANGE = 87;
  static inline var STMT_MESH_FOR = 36;
  static inline var STMT_SNODE_ACTIVATE = 37;
  static inline var EXPR_SNODE_APPEND = 92;
  static inline var EXPR_SNODE_LENGTH = 93;
  static inline var EXPR_MESH_RELATION_GET = 96;

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

  static function sectionLength(bytes:hl.Bytes, kind:Int):Int {
    var sectionCount = u32(bytes, 8);
    for (i in 0...sectionCount) {
      var entry = 20 + i * 12;
      if (u32(bytes, entry) == kind) {
        return u32(bytes, entry + 8);
      }
    }
    throw 'descriptor section ${kind} is missing';
  }

  static function expectParam(name:String, bytes:hl.Bytes, index:Int, kind:Int, dtype:Int, rank:Int):Void {
    var symbolsOffset = sectionOffset(bytes, SECTION_SYMBOLS);
    var paramsOffset = symbolsOffset + 4;
    var count = u32(bytes, paramsOffset);
    if (index < 0 || index >= count) {
      throw '${name}: descriptor parameter index ${index} out of bounds for ${count} parameter(s)';
    }
    var paramOffset = paramsOffset + 4 + index * 8;
    expectEq('${name}_kind', bytes.getUI8(paramOffset), kind);
    expectEq('${name}_dtype', bytes.getUI8(paramOffset + 1), dtype);
    expectEq('${name}_rank', bytes.getUI8(paramOffset + 2), rank);
  }

  static function expectParamFlags(name:String, bytes:hl.Bytes, index:Int, flags:Int):Void {
    var symbolsOffset = sectionOffset(bytes, SECTION_SYMBOLS);
    var paramsOffset = symbolsOffset + 4;
    var count = u32(bytes, paramsOffset);
    if (index < 0 || index >= count) {
      throw '${name}: descriptor parameter index ${index} out of bounds for ${count} parameter(s)';
    }
    var paramOffset = paramsOffset + 4 + index * 8;
    expectEq('${name}_flags', bytes.getUI8(paramOffset + 3), flags);
  }

  static function expectSingleReturnDType(name:String, bytes:hl.Bytes, dtype:Int):Void {
    var statementsOffset = sectionOffset(bytes, SECTION_STATEMENTS);
    var tailOffset = statementsOffset + sectionLength(bytes, SECTION_STATEMENTS) - 7;
    expectEq('${name}_has_return', bytes.getUI8(tailOffset), 1);
    expectEq('${name}_return_dtype', bytes.getUI8(tailOffset + 1), dtype);
    expectEq('${name}_return_count', u32(bytes, tailOffset + 2), 1);
    expectEq('${name}_return_dtype_list', bytes.getUI8(tailOffset + 6), dtype);
  }

  static function expectFirstFunctionReturnDType(name:String, bytes:hl.Bytes, dtype:Int):Void {
    var functionsOffset = sectionOffset(bytes, SECTION_FUNCTIONS);
    expectEq('${name}_function_count', u32(bytes, functionsOffset), 1);
    expectEq('${name}_function_return_dtype', bytes.getUI8(functionsOffset + 9), dtype);
  }

  @:qdFunc
  static function typedReturn(x:I32):I32 {
    return x;
  }

  public static function run():Void {
    var descriptor = Kernel.descriptorBytes(macro (out, n) -> {
      blockDim(64);
      parallelize(2);
      serialize();
      var bits = bitCast(1.0, "I32");
      assert(n >= 0, "n must be non-negative");
      print("descriptor snapshot");
      for (i in 0...n) {
        out[i] = i + 1 + bits - bits;
      }
    });
    expectEq("descriptor_magic", u32(descriptor, 0), 0x4c484451);
    expectEq("descriptor_version", u32(descriptor, 4), 3);
    expectEq("descriptor_section_count", u32(descriptor, 8), 15);
    expectEq("descriptor_section_table", u32(descriptor, 12), 20);
    expectEq("descriptor_first_section_strings", u32(descriptor, 20), 1);
    expectEq("descriptor_symbols_section", u32(descriptor, 20 + 4 * 12), 5);
    expectEq("descriptor_statements_section", u32(descriptor, 20 + 6 * 12), 7);
    expectEq("descriptor_source_section", u32(descriptor, 20 + 1 * 12), 2);
    var sourceSectionOffset = u32(descriptor, 20 + 1 * 12 + 4);
    expectEq("descriptor_source_span_count", u32(descriptor, sourceSectionOffset), 1);
    if (u32(descriptor, sourceSectionOffset + 8) <= 0) throw "descriptor source span line must be positive";

    var scalarAnnotationDescriptor = Kernel.descriptorBytes(macro (x:I32) -> {
      return x;
    });
    expectParam("scalar_annotation_param", scalarAnnotationDescriptor, 0, PARAM_SCALAR, DTYPE_I32, 0);
    expectSingleReturnDType("scalar_annotation", scalarAnnotationDescriptor, DTYPE_I32);

    var specDescriptor = Kernel.descriptorBytes(macro (n:Spec<Int>) -> {
      return n;
    });
    expectParam("spec_param", specDescriptor, 0, PARAM_SCALAR, DTYPE_I32, 0);
    expectParamFlags("spec_param", specDescriptor, 0, PARAM_FLAG_SPEC);
    expectEq("spec_type_table_count", u32(specDescriptor, sectionOffset(specDescriptor, SECTION_TYPE_TABLE)), 1);
    var specTableOffset = sectionOffset(specDescriptor, SECTION_SPEC_TABLE);
    expectEq("spec_table_count", u32(specDescriptor, specTableOffset), 1);
    expectEq("spec_table_param", u32(specDescriptor, specTableOffset + 4), 0);
    expectSingleReturnDType("spec_param", specDescriptor, DTYPE_I32);

    var tensorParamDescriptor = Kernel.descriptorBytes(macro (a:Tensor<I32>) -> {
      return a[0];
    });
    expectParam("tensor_param", tensorParamDescriptor, 0, PARAM_NDARRAY, DTYPE_I32, 1);
    var resourceTableOffset = sectionOffset(tensorParamDescriptor, SECTION_RESOURCE_TABLE);
    expectEq("tensor_resource_table_count", u32(tensorParamDescriptor, resourceTableOffset), 1);
    expectEq("tensor_resource_table_param", u32(tensorParamDescriptor, resourceTableOffset + 4), 0);
    expectSingleReturnDType("tensor_param", tensorParamDescriptor, DTYPE_I32);

    var scalarTensorDescriptor = Kernel.descriptorBytes(macro (a:Tensor<I32>) -> {
      return a.scalarRead();
    });
    expectParam("scalar_tensor_param", scalarTensorDescriptor, 0, PARAM_NDARRAY, DTYPE_I32, 0);
    expectSingleReturnDType("scalar_tensor_param", scalarTensorDescriptor, DTYPE_I32);

    var fieldParamDescriptor = Kernel.descriptorBytes(macro (field:Field<I32>) -> {
      field[0] = field[0] + 1;
    });
    expectParam("field_param", fieldParamDescriptor, 0, PARAM_FIELD, DTYPE_I32, 1);

    var fieldAppendDescriptor = Kernel.descriptorBytes(macro (field:Field<I32>) -> {
      return field.append(0, 1);
    });
    expectParam("field_append_param", fieldAppendDescriptor, 0, PARAM_FIELD, DTYPE_I32, 2);
    var fieldAppendStatementsOffset = sectionOffset(fieldAppendDescriptor, SECTION_STATEMENTS);
    expectEq("field_append_return_opcode", fieldAppendDescriptor.getUI8(fieldAppendStatementsOffset + 8), STMT_RETURN_VALUE);
    expectEq("field_append_expr_opcode", fieldAppendDescriptor.getUI8(fieldAppendStatementsOffset + 9), EXPR_SNODE_APPEND);

    var fieldLengthDescriptor = Kernel.descriptorBytes(macro (field:Field<I32>) -> {
      return field.length(0);
    });
    expectParam("field_length_param", fieldLengthDescriptor, 0, PARAM_FIELD, DTYPE_I32, 2);
    var fieldLengthStatementsOffset = sectionOffset(fieldLengthDescriptor, SECTION_STATEMENTS);
    expectEq("field_length_expr_opcode", fieldLengthDescriptor.getUI8(fieldLengthStatementsOffset + 9), EXPR_SNODE_LENGTH);

    var fieldActivateDescriptor = Kernel.descriptorBytes(macro (field:Field<I32>) -> {
      field.activate(0);
    });
    expectParam("field_activate_param", fieldActivateDescriptor, 0, PARAM_FIELD, DTYPE_I32, 1);
    var fieldActivateStatementsOffset = sectionOffset(fieldActivateDescriptor, SECTION_STATEMENTS);
    expectEq("field_activate_stmt_opcode", fieldActivateDescriptor.getUI8(fieldActivateStatementsOffset + 8), STMT_SNODE_ACTIVATE);

    var vectorNdarrayParamDescriptor = Kernel.descriptorBytes(macro (vectors:VectorNdarray<I32>) -> {
      var v = vectors.readVec2(0);
      return v[0] + v[1];
    });
    expectParam("vector_ndarray_param", vectorNdarrayParamDescriptor, 0, PARAM_NDARRAY, DTYPE_I32, 1);
    expectSingleReturnDType("vector_ndarray_param", vectorNdarrayParamDescriptor, DTYPE_I32);

    var matrixNdarrayParamDescriptor = Kernel.descriptorBytes(macro (matrices:MatrixNdarray<I32>) -> {
      var m = matrices.readMat2(0);
      return m[0] + m[3];
    });
    expectParam("matrix_ndarray_param", matrixNdarrayParamDescriptor, 0, PARAM_NDARRAY, DTYPE_I32, 1);
    expectSingleReturnDType("matrix_ndarray_param", matrixNdarrayParamDescriptor, DTYPE_I32);

    var assumeInRangeDescriptor = Kernel.descriptorBytes(macro (x:I32) -> {
      return CompilerHints.assumeInRange(x, 0, 0, 8);
    });
    var assumeStatementsOffset = sectionOffset(assumeInRangeDescriptor, SECTION_STATEMENTS);
    expectEq("assume_statement_count", u32(assumeInRangeDescriptor, assumeStatementsOffset + 4), 1);
    expectEq("assume_statement_opcode", assumeInRangeDescriptor.getUI8(assumeStatementsOffset + 8), STMT_RETURN_VALUE);
    expectEq("assume_expression_opcode", assumeInRangeDescriptor.getUI8(assumeStatementsOffset + 9), EXPR_ASSUME_IN_RANGE);
    expectSingleReturnDType("assume_in_range_descriptor", assumeInRangeDescriptor, DTYPE_I32);

    var bufferViewParamDescriptor = Kernel.descriptorBytes(macro (view:quadrants.BufferView<I32>) -> {
      return view[0];
    });
    expectParam("buffer_view_param_tensor", bufferViewParamDescriptor, 0, PARAM_NDARRAY, DTYPE_I32, 1);
    expectParam("buffer_view_param_start", bufferViewParamDescriptor, 1, PARAM_SCALAR, DTYPE_I32, 0);
    expectParam("buffer_view_param_length", bufferViewParamDescriptor, 2, PARAM_SCALAR, DTYPE_I32, 0);
    expectSingleReturnDType("buffer_view_param", bufferViewParamDescriptor, DTYPE_I32);

    var castDescriptor = Kernel.descriptorBytes(macro (x:F32) -> {
      return (x : I32);
    });
    var castStatementsOffset = sectionOffset(castDescriptor, SECTION_STATEMENTS);
    expectEq("cast_statement_count", u32(castDescriptor, castStatementsOffset + 4), 1);
    expectEq("cast_statement_opcode", castDescriptor.getUI8(castStatementsOffset + 8), STMT_RETURN_VALUE);
    expectEq("cast_expression_opcode", castDescriptor.getUI8(castStatementsOffset + 9), EXPR_CAST);
    expectEq("cast_expression_dtype", castDescriptor.getUI8(castStatementsOffset + 10), DTYPE_I32);
    expectSingleReturnDType("cast_descriptor", castDescriptor, DTYPE_I32);

    var functionReturnDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>, x:I32) -> {
      out[0] = typedReturn(x);
    });
    expectFirstFunctionReturnDType("function_return_annotation", functionReturnDescriptor, DTYPE_I32);

    var structForDescriptor = Kernel.descriptorBytes(macro (field:Field<I32>, tensor:Tensor<I32>) -> {
      for (i in field) {
        field[i] = field[i] + tensor[i];
      }
    });
    expectEq("struct_for_descriptor_magic", u32(structForDescriptor, 0), 0x4c484451);


    var meshForDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      for (v in Mesh.forVertices(4)) {
        out[v] = v;
      }
    });
    var meshForStatementsOffset = sectionOffset(meshForDescriptor, SECTION_STATEMENTS);
    expectEq("mesh_for_statement_count", u32(meshForDescriptor, meshForStatementsOffset + 4), 1);
    expectEq("mesh_for_statement_opcode", meshForDescriptor.getUI8(meshForStatementsOffset + 8), STMT_MESH_FOR);
    expectEq("mesh_for_element_type", meshForDescriptor.getUI8(meshForStatementsOffset + 13), 0);
    expectEq("mesh_for_vertex_count", u32(meshForDescriptor, meshForStatementsOffset + 14), 4);

    var meshRelationDescriptor = Kernel.descriptorBytes(macro (rel:MeshRelation<Edge, Vertex>) -> {
      return rel.get(0, 0);
    });
    expectParam("mesh_relation_param", meshRelationDescriptor, 0, PARAM_MESH_RELATION, DTYPE_I32, 0);
    var meshRelationStatementsOffset = sectionOffset(meshRelationDescriptor, SECTION_STATEMENTS);
    expectEq("mesh_relation_return_opcode", meshRelationDescriptor.getUI8(meshRelationStatementsOffset + 8), STMT_RETURN_VALUE);
    expectEq("mesh_relation_expr_opcode", meshRelationDescriptor.getUI8(meshRelationStatementsOffset + 9), EXPR_MESH_RELATION_GET);
    var meshArgTableOffset = sectionOffset(meshRelationDescriptor, SECTION_ARG_TABLE);
    expectEq("mesh_relation_arg_table_count", u32(meshRelationDescriptor, meshArgTableOffset), 1);
    var vectorDescriptor = Kernel.descriptorBytes(macro (out:Tensor<F32>) -> {
      var v = Vec3.f32(1.0, 2.0, 3.0);
      var w = Vector.ofArray([4.0, 5.0, 6.0]);
      var s = v + w;
      var c = v.cross(w);
      s.x = s.x + c.y;
      out[0] = s.dot(w) + c.norm();
    });
    expectEq("vector_descriptor_magic", u32(vectorDescriptor, 0), 0x4c484451);

    var selectDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>, flag:Bool) -> {
      out[0] = select(flag, 3, 4) + select(isnan(0.0), 1, 0) + select(isinf(1.0), 2, 0);
    });
    expectEq("select_descriptor_magic", u32(selectDescriptor, 0), 0x4c484451);

    var randomDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      out[0] = randI32() + (randU32() : I32);
    });
    expectEq("random_descriptor_magic", u32(randomDescriptor, 0), 0x4c484451);

    var typedConstantDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var big:quadrants.Types.I64 = 0x100000000;
      var single:quadrants.Types.F32 = 1;
      out[0] = (big > 0 ? 1 : 0) + (single > 0.0 ? 1 : 0);
    });
    expectEq("typed_constant_descriptor_magic", u32(typedConstantDescriptor, 0), 0x4c484451);

    var atomicCasDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var old = atomicCompareExchange(out[0], 0, 1);
      out[0] = old;
    });
    expectEq("atomic_cas_descriptor_magic", u32(atomicCasDescriptor, 0), 0x4c484451);

    var bufferViewDescriptor = Kernel.descriptorBytes(macro (view:quadrants.BufferView<I32>, out:Tensor<I32>) -> {
      out[0] = view[1] + view.shape(0);
    });
    expectEq("buffer_view_descriptor_magic", u32(bufferViewDescriptor, 0), 0x4c484451);

    var matrixDescriptor = Kernel.descriptorBytes(macro (out:Tensor<F32>) -> {
      var a = Mat2.f32(1.0, 2.0, 3.0, 4.0);
      var b = Matrix.ofArray(2, 2, [5.0, 6.0, 7.0, 8.0]);
      var c = a.matmul(b);
      var t = c.transpose();
      t[0][1] = t[0][1] + c[1][0];
      out[0] = t[0][1];
    });
    expectEq("matrix_descriptor_magic", u32(matrixDescriptor, 0), 0x4c484451);

    var staticForDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      for (i in Static.range(0, 3)) {
        out[i] = i + 1;
      }
    });
    expectEq("static_for_descriptor_magic", u32(staticForDescriptor, 0), 0x4c484451);

    var sharedDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var scratch = Shared.arrayI32(4);
      scratch[0] = 7;
      var tile = Shared.tile16I32();
      tile[15] = scratch[0];
      var flags = Shared.arrayU1(2);
      flags[0] = true;
      var halfTile = Shared.tile16F16();
      halfTile[0] = 1.5;
      out[0] = tile[15] + (flags[0] ? 1 : 0) + (halfTile[0] > 1.0 ? 1 : 0);
    });
    expectEq("shared_descriptor_magic", u32(sharedDescriptor, 0), 0x4c484451);

    var helperExpandedDescriptor = Kernel.descriptorBytes(macro (input:Tensor<I32>, out:Tensor<I32>) -> {
      blockDim(16);
      var lane = Block.threadIdx();
      var value = input[lane];
      var prefix = BlockScan.exclusiveAddI32Tile16(value);
      var sum = BlockReduce.reduceAddI32Tile16(value);
      out[lane] = prefix + sum;
    }, {helpers: [BlockReduce, BlockScan]});
    var helperFunctionsOffset = sectionOffset(helperExpandedDescriptor, SECTION_FUNCTIONS);
    expectEq("helper_expanded_descriptor_magic", u32(helperExpandedDescriptor, 0), 0x4c484451);
    expectEq("helper_expanded_function_count", u32(helperExpandedDescriptor, helperFunctionsOffset), 44);

    var structDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var particle = Struct.of2("mass", 2, "velocity", 3);
      particle.mass += particle.velocity;
      var extended = Struct.of5("a", 1, "b", 2, "c", 3, "d", 4, "e", 5);
      extended.e += extended.d;
      out[0] = particle.mass + extended.e;
    });
    expectEq("struct_descriptor_magic", u32(structDescriptor, 0), 0x4c484451);

    var nestedStructDescriptor = Kernel.descriptorBytes(macro (out:Tensor<I32>) -> {
      var inner = Struct.of2("mass", 2, "velocity", 3);
      var outer = Struct.of2("particle", inner, "id", 4);
      outer.particle.mass += outer.id;
      out[0] = outer.particle.mass + outer.particle.velocity;
    });
    expectEq("nested_struct_descriptor_magic", u32(nestedStructDescriptor, 0), 0x4c484451);
  }
}
