package quadrants;

import quadrants.Native.QNdarray;
import quadrants.Types.DType;

interface TensorHandle {
  public var context(default, null):Context;
  public var shape(default, null):Array<Int>;
  public var dtype(default, null):DType;
  public function nativeHandle():QNdarray;
  public function close():Void;
}
