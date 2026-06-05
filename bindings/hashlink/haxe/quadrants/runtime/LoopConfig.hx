package quadrants.runtime;

class LoopConfig {
  public static inline function blockDim(value:Int):Void {}
  public static inline function block_dim(value:Int):Void {}
  public static inline function parallelize(count:Int):Void {}
  public static inline function serialize():Void {}
  public static inline function strictlySerialize():Void {}
}
