import quadrants.Algorithms;
import quadrants.Context;
import quadrants.Diagnostics;
import quadrants.Field;
import quadrants.Kernel;
import quadrants.LayoutPolicy;
import quadrants.Matrix;
import quadrants.Mesh;
import quadrants.Profiler;
import quadrants.Quant;
import quadrants.Spec;
import quadrants.StructTensor;
import quadrants.Tape;
import quadrants.Tensor;
import quadrants.Vec3;
import quadrants.Vector;
import quadrants.algorithms.Scratch;
import quadrants.funcs.Linalg;
import quadrants.mesh.Edge;
import quadrants.mesh.MeshAttribute;
import quadrants.mesh.MeshKinds;
import quadrants.mesh.MeshRelation;
import quadrants.mesh.Vertex;
import quadrants.quant.QuantizedF32Tensor;
import quadrants.Types.Arch;
import quadrants.Types.F32;
import quadrants.Types.I32;

@:build(quadrants.macro.QdArgs.build())
class V3SmokeState {
  public var out:Tensor<I32>;
  public var n:Int;

  public function new(ctx:Context, n:Int) {
    this.out = new Tensor<I32>(ctx, [n]);
    this.n = n;
  }

  @:kernel
  public function clear():Void {
    for (i in 0...n) {
      out[i] = 0;
    }
  }
}

@:build(quadrants.macro.QdStruct.build())
class V3Particle {
  public var id:I32;
  public var mass:F32;
  public var pos:Vec3;
}

@:build(quadrants.macro.QdStruct.build())
class V3Wrapper {
  public var particle:V3Particle;
  public var tag:I32;
}

class Smoke {
  static function main():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true, profiler: true});
    var x = new Tensor<I32>(ctx, [4]);
    var y = new Tensor<I32>(ctx, [4]);
    var add = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<I32>, n:Spec<Int>) -> {
      for (i in 0...n) {
        out[i] = a[i] + 1;
      }
    }, {name: "v3_smoke_add"});
    for (i in 0...4) x.write(i, i);
    if (x.rank() != 1 || x.numel() != 4) throw "Tensor rank/numel failed";
    y.copyFrom(x);
    if (y.readAt([2]) != 2) throw "Tensor copy/readAt failed";
    add.launch(x, y, Spec.of(4));
    ctx.sync();
    if (y.read(3) != 4) throw 'typed Kernel.build failed: ${y.read(3)}';
    for (i in 0...4) y.write(i, 0);
    add.launch(x, y, Spec.of(2));
    ctx.sync();
    if (y.read(0) != 1 || y.read(1) != 2 || y.read(2) != 0) throw "Spec<T> specialization cache failed";
    add.launch(x, y, Spec.of(4));
    ctx.sync();
    var tape = new Tape();
    add.launchTape(tape, x, y, Spec.of(4));
    if (tape.length != 1) throw "typed Tape launch did not record";
    var reduced = new Tensor<I32>(ctx, [1]);
    var scratch = Scratch.create(ctx);
    scratch.reserve(64);
    scratch.clear();
    Algorithms.reduceAdd(ctx, y, reduced, scratch);
    ctx.sync();
    if (reduced.read(0) != 10) throw 'Algorithms.reduceAdd failed: ${reduced.read(0)}';

    var state = new V3SmokeState(ctx, 4);
    state.clear();
    ctx.sync();
    if (state.out.read(0) != 0) throw "QdArgs @:kernel failed";

    var caps:Dynamic = Diagnostics.dumpCapabilities(ctx);
    if (!caps.fieldResourceParam) throw "Diagnostics.dumpCapabilities failed";
    Profiler.withScope(ctx, "v3_scope", function() ctx.sync());
    if (ctx.profiler().traceEvents().length == 0) throw "Profiler.traceEvents failed";
    var qi8 = Quant.intI32({bits: 8, signed: true});
    if (qi8 == null) throw "Quant.intI32 failed";
    var solved = Linalg.solve2(Matrix.ofArray(2, 2, [2.0, 0.0, 0.0, 4.0]), Vector.ofArray([6.0, 8.0]));
    if (Math.abs(solved[0] - 3.0) > 1.0e-6 || Math.abs(solved[1] - 2.0) > 1.0e-6) throw "Linalg.solve2 failed";
    var eig = Linalg.symEig2(Matrix.ofArray(2, 2, [2.0, 0.0, 0.0, 4.0]));
    if (Math.abs(eig.values[0] - 4.0) > 1.0e-6 || Math.abs(eig.values[1] - 2.0) > 1.0e-6) throw "Linalg.symEig2 failed";
    var svd = Linalg.svd2(Matrix.ofArray(2, 2, [3.0, 0.0, 0.0, 2.0]));
    if (Math.abs(svd.sigma[0] - 3.0) > 1.0e-6 || Math.abs(svd.sigma[1] - 2.0) > 1.0e-6) throw "Linalg.svd2 failed";

    var dense = new Tensor<F32>(ctx, [2, 2]);
    dense.write(0, 2.0);
    dense.write(1, 0.0);
    dense.write(2, 0.0);
    dense.write(3, 5.0);
    var sparse = new quadrants.linalg.SparseMatrix<F32>(ctx, 2, 2, quadrants.Types.DType.F32);
    sparse.buildFromTensor(dense, {eps: 0.0});
    if (sparse.nnz != 2) throw 'SparseMatrix.buildFromTensor failed: ${sparse.nnz}';
    var sparsePath = "build/v3_sparse_smoke.mtx";
    sparse.mmwrite(sparsePath);
    if (!sys.FileSystem.exists(sparsePath)) throw "SparseMatrix.mmwrite failed";
    sparse.close();
    dense.close();

    var particles:StructTensor<V3Particle> = StructTensor.alloc(ctx, [2], LayoutPolicy.AOS);
    particles.writeMember("id", 0, 7);
    var posTensor:Dynamic = particles.member("pos");
    posTensor.writeAt([0, 0], 1.0);
    if (particles.readMember("id", 0) != 7) throw "QdStruct StructTensor host storage failed";
    var bumpParticle = Kernel.build(ctx, macro (particles:StructTensor<V3Particle>, n:Spec<Int>) -> {
      for (i in 0...n) {
        var p = particles[i];
        p.id = p.id + 1;
        p.pos.x = p.pos.x + 2.0;
        particles[i] = p;
      }
    }, {name: "v3_smoke_struct_tensor"});
    bumpParticle.launch(particles, Spec.of(1));
    ctx.sync();
    if (particles.readMember("id", 0) != 8 || Math.abs((posTensor.readAt([0, 0]) : Float) - 3.0) > 1.0e-5) throw "QdStruct StructTensor kernel load/store failed";
    bumpParticle.close();
    particles.close();

    var wrappers:StructTensor<V3Wrapper> = StructTensor.alloc(ctx, [1], LayoutPolicy.AOS);
    wrappers.writeMember("particle.id", 0, 3);
    var nestedKernel = Kernel.build(ctx, macro (wrappers:StructTensor<V3Wrapper>) -> {
      var w = wrappers[0];
      w.particle.id = w.particle.id + 4;
      wrappers[0] = w;
    }, {name: "v3_smoke_nested_struct_tensor"});
    nestedKernel.launch(wrappers);
    ctx.sync();
    if (wrappers.readMember("particle.id", 0) != 7) throw "QdStruct nested StructTensor kernel load/store failed";
    nestedKernel.close();
    wrappers.close();

    var mesh = new Mesh(2, 1);
    var edge0 = mesh.element(MeshKinds.edge, 0);
    var v0 = mesh.element(MeshKinds.vertex, 0);
    var v1 = mesh.element(MeshKinds.vertex, 1);
    var edgeVertices:MeshRelation<Edge, Vertex> = mesh.relation(MeshKinds.edge, MeshKinds.vertex);
    edgeVertices.set(edge0, [v0, v1]);
    var massField = new Field<I32>(ctx, [2]);
    var mass:MeshAttribute<Vertex, I32> = mesh.attribute(MeshKinds.vertex, massField);
    mass.write(v0, 5);
    mass.write(v1, 6);
    var edgeSum = new Tensor<I32>(ctx, [1]);
    var meshKernel = Kernel.build(ctx, macro (edgeVertices:MeshRelation<Edge, Vertex>, mass:MeshAttribute<Vertex, I32>, edgeSum:Tensor<I32>) -> {
      var sum = 0;
      for (j in 0...edgeVertices.size(0)) {
        sum = sum + mass.read(edgeVertices.get(0, j));
      }
      edgeSum[0] = sum;
    }, {name: "v3_smoke_mesh_relation_attribute"});
    meshKernel.launch(edgeVertices, mass, edgeSum);
    ctx.sync();
    if (edgeSum.read(0) != 11) throw 'Mesh relation/attribute kernel access failed: ${edgeSum.read(0)}';
    meshKernel.close();
    edgeSum.close();
    massField.close();

    var qspec = quadrants.quant.Quant.fixedF32(quadrants.quant.QuantBits.Bits8, quadrants.quant.QuantSignedness.Signed, 4);
    var qvalues = new QuantizedF32Tensor(ctx, [1], qspec);
    qvalues.write(0, 1.25);
    var qout = new Tensor<F32>(ctx, [1]);
    var qKernel = Kernel.build(ctx, macro (qvalues:QuantizedF32Tensor, qout:Tensor<F32>) -> {
      var value:F32 = qvalues.read(0) + 1.0;
      qout[0] = value;
      qvalues.write(0, value);
    }, {name: "v3_smoke_quant_param"});
    qKernel.launch(qvalues, qout);
    ctx.sync();
    var qread:Float = qout.read(0);
    var qraw:Int = qvalues.readRaw(0);
    if (Math.abs(qread - 2.25) > 1.0e-5 || qraw != 36) throw 'QuantizedF32Tensor kernel param failed: read=${qread} raw=${qraw}';
    qKernel.close();
    qout.close();
    qvalues.close();

    var qfloatField = new Field<F32>(ctx);
    var qfloatSpec = quadrants.quant.Quant.floatF32(5, 10, quadrants.quant.QuantSignedness.Signed);
    ctx.root.dense(quadrants.Axis.i, 1).bitStruct(32).placeQuant(qfloatField, qfloatSpec);
    qfloatField.write(0, 1.5);
    if (Math.abs((qfloatField.read(0) : Float) - 1.5) > 0.1) throw "Quant float bitStruct placement failed";
    qfloatField.close();

    add.close();
    x.close();
    y.close();
    reduced.close();
    state.out.close();
    ctx.close();
    Sys.println("hashlink v3 smoke ok");
  }
}
