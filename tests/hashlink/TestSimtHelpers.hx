import quadrants.Block;
import quadrants.Kernel;
import quadrants.Shared;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.simt.BlockReduce;
import quadrants.simt.BlockScan;
import quadrants.simt.SubgroupCompat;
import quadrants.simt.Helpers;
import quadrants.simt.Tile16x16F32;
import quadrants.simt.TileSort;

class TestSimtHelpers {
  static function expectEq(name:String, got:Int, expected:Int):Void {
    if (got != expected) throw '${name}: ${got} != ${expected}';
  }

  static function u32(bytes:hl.Bytes, offset:Int):Int {
    return bytes.getUI8(offset)
      | (bytes.getUI8(offset + 1) << 8)
      | (bytes.getUI8(offset + 2) << 16)
      | (bytes.getUI8(offset + 3) << 24);
  }

  public static function run():Void {
    expectEq("simt_helper_class_count", Helpers.classes().length, 8);
    var descriptor = Kernel.descriptorBytes(macro (input:Tensor<I32>, out:Tensor<I32>, fin:Tensor<F32>, fout:Tensor<F32>) -> {
      blockDim(256);
      var lane = Block.threadIdx();
      var value = input[lane];
      var sum = BlockReduce.reduceAddI32Tile16(value);
      var scan = BlockScan.exclusiveAddI32Tile16(value);
      var sorted = TileSort.sortAscendingI32Tile16(value);
      var shuffled = SubgroupCompat.shuffleI32(value, lane);
      var first = SubgroupCompat.broadcastFirstI32(value);
      var xorValue = SubgroupCompat.shuffleXorI32(value, 1);
      var all = BlockReduce.reduceAllI32(1);
      var tile = Shared.tile16F32();
      Tile16x16F32.loadTile16x16F32(tile, fin, 0, 16);
      Tile16x16F32.transposeTile16x16F32(tile);
      Tile16x16F32.storeTile16x16F32(tile, fout, 0, 16);
      if (lane == 0) {
        out[0] = sum + scan + sorted + shuffled + first + xorValue + all;
      }
    }, {helpers: [BlockReduce, BlockScan, SubgroupCompat, TileSort, Tile16x16F32]});
    expectEq("simt_helper_descriptor_magic", u32(descriptor, 0), 0x4c484451);

    TestRuntimeSupport.runEachRequestedDeviceContext(function(_name, ctx) {
      var kernel:Kernel = null;
      var input:Tensor<I32> = null;
      var out:Tensor<I32> = null;
      try {
        input = new Tensor<I32>(ctx, [16]);
        out = new Tensor<I32>(ctx, [16]);
        input.fromArray([16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
        out.fill(0);
        kernel = Kernel.build(ctx, macro (input:Tensor<I32>, out:Tensor<I32>) -> {
          blockDim(16);
          var lane = Block.threadIdx();
          var value = input[lane];
          var sum = BlockReduce.reduceAddI32Tile16(value);
          var prefix = BlockScan.exclusiveAddI32Tile16(value);
          var sorted = TileSort.sortAscendingI32Tile16(value);
          if (lane == 0) {
            out[0] = sum;
          }
          if (lane < 16) {
            out[lane] = out[lane] + prefix + sorted - sorted;
          }
        }, {helpers: [BlockReduce, BlockScan, TileSort]});
        kernel.launch(input, out);
        ctx.sync();
        expectEq("simt_helper_reduce_runtime", out.read(0), 136);
        expectEq("simt_helper_scan_runtime_1", out.read(1), 16);
        expectEq("simt_helper_scan_runtime_2", out.read(2), 31);
      } catch (e:Dynamic) {
        if (out != null) out.close();
        if (input != null) input.close();
        TestRuntimeSupport.closeKernel(kernel);
        throw e;
      }
      out.close();
      input.close();
      TestRuntimeSupport.closeKernel(kernel);
    });
  }
}
