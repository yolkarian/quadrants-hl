// EXPECT_ERROR: Float should be quadrants.I32
import quadrants.Context;
import quadrants.Field;
import quadrants.StructField;
import quadrants.StructMember;
import quadrants.Types.Arch;
import quadrants.Types.I32;

class StructMemberTypeAssumption {
  static function main():Void {
    var ctx = new Context(Arch.Cpu);
    var value = new StructMember<I32>("value");
    var storage = new Field<I32>(ctx, [1]);
    var struct = new StructField();
    struct.addMember(value, storage);
    struct.writeMember(value, 0, 1.5);
  }
}
