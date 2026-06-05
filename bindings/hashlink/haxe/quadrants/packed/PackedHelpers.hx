package quadrants.packed;

import quadrants.Mat2;
import quadrants.Mat3;
import quadrants.Mat4;
import quadrants.Matrix;
import quadrants.Tensor;
import quadrants.Types.F32;
import quadrants.Types.I32;
import quadrants.Vec2;
import quadrants.Vec3;
import quadrants.Vec4;
import quadrants.Vector;

class PackedHelpers {
  public static function readVec2I32(storage:Tensor<I32>, index:Int):Vector<I32> {
    return Vec2.i32(storage.kernelRead(index * 2), storage.kernelRead(index * 2 + 1));
  }

  public static function writeVec2I32(storage:Tensor<I32>, index:Int, value:Vector<I32>):Void {
    storage.kernelWrite(index * 2, value[0]);
    storage.kernelWrite(index * 2 + 1, value[1]);
  }

  public static function readVec3I32(storage:Tensor<I32>, index:Int):Vector<I32> {
    return Vec3.i32(storage.kernelRead(index * 3), storage.kernelRead(index * 3 + 1), storage.kernelRead(index * 3 + 2));
  }

  public static function writeVec3I32(storage:Tensor<I32>, index:Int, value:Vector<I32>):Void {
    storage.kernelWrite(index * 3, value[0]);
    storage.kernelWrite(index * 3 + 1, value[1]);
    storage.kernelWrite(index * 3 + 2, value[2]);
  }

  public static function readVec4I32(storage:Tensor<I32>, index:Int):Vector<I32> {
    return Vec4.i32(storage.kernelRead(index * 4), storage.kernelRead(index * 4 + 1), storage.kernelRead(index * 4 + 2), storage.kernelRead(index * 4 + 3));
  }

  public static function writeVec4I32(storage:Tensor<I32>, index:Int, value:Vector<I32>):Void {
    storage.kernelWrite(index * 4, value[0]);
    storage.kernelWrite(index * 4 + 1, value[1]);
    storage.kernelWrite(index * 4 + 2, value[2]);
    storage.kernelWrite(index * 4 + 3, value[3]);
  }

  public static function readVec2F32(storage:Tensor<F32>, index:Int):Vector<F32> {
    return Vec2.f32(storage.kernelRead(index * 2), storage.kernelRead(index * 2 + 1));
  }

  public static function writeVec2F32(storage:Tensor<F32>, index:Int, value:Vector<F32>):Void {
    storage.kernelWrite(index * 2, value[0]);
    storage.kernelWrite(index * 2 + 1, value[1]);
  }

  public static function readVec3F32(storage:Tensor<F32>, index:Int):Vector<F32> {
    return Vec3.f32(storage.kernelRead(index * 3), storage.kernelRead(index * 3 + 1), storage.kernelRead(index * 3 + 2));
  }

  public static function writeVec3F32(storage:Tensor<F32>, index:Int, value:Vector<F32>):Void {
    storage.kernelWrite(index * 3, value[0]);
    storage.kernelWrite(index * 3 + 1, value[1]);
    storage.kernelWrite(index * 3 + 2, value[2]);
  }

  public static function readVec4F32(storage:Tensor<F32>, index:Int):Vector<F32> {
    return Vec4.f32(storage.kernelRead(index * 4), storage.kernelRead(index * 4 + 1), storage.kernelRead(index * 4 + 2), storage.kernelRead(index * 4 + 3));
  }

  public static function writeVec4F32(storage:Tensor<F32>, index:Int, value:Vector<F32>):Void {
    storage.kernelWrite(index * 4, value[0]);
    storage.kernelWrite(index * 4 + 1, value[1]);
    storage.kernelWrite(index * 4 + 2, value[2]);
    storage.kernelWrite(index * 4 + 3, value[3]);
  }

  public static function readMat2I32(storage:Tensor<I32>, index:Int):Matrix<I32> {
    return Mat2.i32(storage.kernelRead(index * 4), storage.kernelRead(index * 4 + 1), storage.kernelRead(index * 4 + 2), storage.kernelRead(index * 4 + 3));
  }

  public static function writeMat2I32(storage:Tensor<I32>, index:Int, value:Dynamic):Void {
    storage.kernelWrite(index * 4, value[0]);
    storage.kernelWrite(index * 4 + 1, value[1]);
    storage.kernelWrite(index * 4 + 2, value[2]);
    storage.kernelWrite(index * 4 + 3, value[3]);
  }

  public static function readMat3I32(storage:Tensor<I32>, index:Int):Matrix<I32> {
    return Mat3.i32(storage.kernelRead(index * 9), storage.kernelRead(index * 9 + 1), storage.kernelRead(index * 9 + 2), storage.kernelRead(index * 9 + 3), storage.kernelRead(index * 9 + 4), storage.kernelRead(index * 9 + 5), storage.kernelRead(index * 9 + 6), storage.kernelRead(index * 9 + 7), storage.kernelRead(index * 9 + 8));
  }

  public static function readMat4I32(storage:Tensor<I32>, index:Int):Matrix<I32> {
    return Mat4.i32(storage.kernelRead(index * 16), storage.kernelRead(index * 16 + 1), storage.kernelRead(index * 16 + 2), storage.kernelRead(index * 16 + 3), storage.kernelRead(index * 16 + 4), storage.kernelRead(index * 16 + 5), storage.kernelRead(index * 16 + 6), storage.kernelRead(index * 16 + 7), storage.kernelRead(index * 16 + 8), storage.kernelRead(index * 16 + 9), storage.kernelRead(index * 16 + 10), storage.kernelRead(index * 16 + 11), storage.kernelRead(index * 16 + 12), storage.kernelRead(index * 16 + 13), storage.kernelRead(index * 16 + 14), storage.kernelRead(index * 16 + 15));
  }

  public static function readMat2F32(storage:Tensor<F32>, index:Int):Matrix<F32> {
    return Mat2.f32(storage.kernelRead(index * 4), storage.kernelRead(index * 4 + 1), storage.kernelRead(index * 4 + 2), storage.kernelRead(index * 4 + 3));
  }

  public static function writeMat2F32(storage:Tensor<F32>, index:Int, value:Dynamic):Void {
    storage.kernelWrite(index * 4, value[0]);
    storage.kernelWrite(index * 4 + 1, value[1]);
    storage.kernelWrite(index * 4 + 2, value[2]);
    storage.kernelWrite(index * 4 + 3, value[3]);
  }

  public static function readMemberI32(member:Tensor<I32>, index:Int):I32 {
    return member.kernelRead(index);
  }

  public static function writeMemberI32(member:Tensor<I32>, index:Int, value:I32):Void {
    member.kernelWrite(index, value);
  }

  public static function readMemberF32(member:Tensor<F32>, index:Int):F32 {
    return member.kernelRead(index);
  }

  public static function writeMemberF32(member:Tensor<F32>, index:Int, value:F32):Void {
    member.kernelWrite(index, value);
  }
}
