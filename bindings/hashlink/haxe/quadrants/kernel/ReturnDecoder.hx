package quadrants.kernel;

import quadrants.Struct;

class ReturnDecoder {
  public static function unsupportedReturnOnStream(kernelName:String):Dynamic {
    throw 'Quadrants typed stream launch does not support return values for kernel ${kernelName}';
  }

  public static function unsupportedReturnOnGraph(kernelName:String):Dynamic {
    throw 'Quadrants typed graph launch does not support return values for kernel ${kernelName}';
  }

  public static function decodeSchema<T>(schema:Dynamic, values:hl.NativeArray<Dynamic>):T {
    return cast Struct.decodeSchema(schema, values);
  }
}
