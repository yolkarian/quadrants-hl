import quadrants.Block;
import quadrants.Grid;
import quadrants.Kernel;
import quadrants.Subgroup;
import quadrants.Workgroup;
import quadrants.Types.I8;

class TestSimtApi {
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
    var descriptor = Kernel.descriptorBytes(macro (out, n) -> {
      Block.sync();
      Block.memFence();
      Block.warpSync(Grid.activeMask());
      Workgroup.sync();
      Workgroup.memFence();
      Workgroup.gridMemFence();
      Subgroup.sync();
      Subgroup.memFence();
      var lane = Subgroup.invocationId();
      var size = Subgroup.size();
      var elect = Subgroup.elect();
      var localId = Workgroup.localInvocationId();
      var globalId = Workgroup.globalInvocationId();
      var blockIdx = Block.threadIdx();
      var shuffled = Subgroup.shuffle(n, lane);
      var up = Subgroup.shuffleUp(shuffled, 1);
      var down = Subgroup.shuffleDown(up, 1);
      var broadcast = Subgroup.broadcast(down, 0);
      var all = Block.barrierAnd(elect);
      var any = Block.barrierOr(elect);
      var count = Block.barrierCount(elect);
      out[0] = blockIdx + size + localId + globalId + broadcast + all + any + count;
    });
    expectEq("simt_descriptor_magic", u32(descriptor, 0), 0x4c484451);
    expectEq("simt_descriptor_version", u32(descriptor, 4), 2);
  }
}
