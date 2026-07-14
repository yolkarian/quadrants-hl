import quadrants.Context;
import quadrants.Kernel;
import quadrants.SpecialOps;
import quadrants.Subgroup;
import quadrants.Tensor;
import quadrants.Types.Arch;
import quadrants.Types.I32;
import quadrants.Types.I64;
import quadrants.Types.U64;

class Wave2OpsSemantic {
  static function expect(name:String, condition:Bool):Void {
    if (!condition) {
      throw 'Wave2OpsSemantic ${name} failed';
    }
  }

  static function testRand64(ctx:Context):Void {
    var out = new Tensor<I64>(ctx, [8]);
    var outU = new Tensor<U64>(ctx, [8]);
    var k = Kernel.build(ctx, macro (out:Tensor<I64>, outU:Tensor<U64>) -> {
      for (i in 0...8) {
        out[i] = randI64();
        outU[i] = randU64();
      }
    });
    k.launch(out, outU);
    ctx.sync();
    var values = out.toArray();
    var distinct = false;
    for (i in 1...8) {
      if (haxe.Int64.compare(values[i], values[0]) != 0) {
        distinct = true;
      }
    }
    expect("rand_i64_distinct", distinct);
    var unsignedValues = outU.toArray();
    var unsignedDistinct = false;
    for (i in 1...8) {
      if (haxe.Int64.compare(unsignedValues[i], unsignedValues[0]) != 0) {
        unsignedDistinct = true;
      }
    }
    expect("rand_u64_distinct", unsignedDistinct);
    out.close();
    outU.close();
  }

  static function testClock(ctx:Context):Void {
    var out = new Tensor<I64>(ctx, [2]);
    var k = Kernel.build(ctx, macro (out:Tensor<I64>) -> {
      out[0] = SpecialOps.clockI64();
      out[1] = SpecialOps.clockI64();
    });
    k.launch(out);
    ctx.sync();
    // The CPU runtime clock stub returns 0; the contract here is that the
    // expression compiles, launches, and produces a non-negative counter.
    var values = out.toArray();
    expect("clock_non_negative", haxe.Int64.compare(values[0], haxe.Int64.ofInt(0)) >= 0);
    out.close();
  }

  static function testBallotCpu(ctx:Context):Void {
    var input = new Tensor<I32>(ctx, [4]);
    var out = new Tensor<U64>(ctx, [4]);
    input.fromArray([1, 0, 7, 0]);
    var k = Kernel.build(ctx, macro (a:Tensor<I32>, out:Tensor<U64>) -> {
      for (i in 0...4) {
        out[i] = Subgroup.ballot(a[i]);
      }
    });
    k.launch(input, out);
    ctx.sync();
    // Width-1 CPU subgroups: the ballot is the lane's own predicate bit.
    var values = out.toArray();
    expect("ballot_lane0", haxe.Int64.compare(values[0], haxe.Int64.ofInt(1)) == 0);
    expect("ballot_lane1", haxe.Int64.compare(values[1], haxe.Int64.ofInt(0)) == 0);
    expect("ballot_lane2", haxe.Int64.compare(values[2], haxe.Int64.ofInt(1)) == 0);
    input.close();
    out.close();
  }

  static function testMatchRequiresCuda(ctx:Context):Void {
    var rejected = false;
    try {
      var k = Kernel.build(ctx, macro (mask:quadrants.Types.U32, out:Tensor<U64>) -> {
        out[0] = quadrants.Grid.matchAnySync(mask, 3);
      });
      k.launch(haxe.Int64.ofInt(-1), new Tensor<U64>(ctx, [1]));
    } catch (e:Dynamic) {
      rejected = Std.string(e).indexOf("CUDA") >= 0;
    }
    expect("match_requires_cuda", rejected);
  }
  public static function run():Void {
    var ctx = Context.create({arch: Arch.Cpu, boundsCheck: true});
    try {
      testRand64(ctx);
      testClock(ctx);
      testBallotCpu(ctx);
      testMatchRequiresCuda(ctx);
    } catch (e:Dynamic) {
      ctx.close();
      throw e;
    }
    ctx.close();
  }

  static function main():Void {
    run();
    Sys.println("wave2 ops semantic ok");
  }
}
