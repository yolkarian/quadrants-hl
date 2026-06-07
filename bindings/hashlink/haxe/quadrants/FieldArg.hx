package quadrants;

/**
 * Generic typed view implemented by every concrete Field<T> generated dtype class.
 *
 * Like Tensor<T>, Field<T> is a generic-build facade. This interface preserves
 * dtype relationships for public generic APIs while concrete storage remains the
 * generated Field_<DType> classes.
 */
interface FieldArg<T> extends TensorHandle {
  public function elementCount():Int;
  public function read(flatIndex:Int):T;
  public function write(flatIndex:Int, value:T):Void;
  public function scalarRead():T;
  public function scalarWrite(value:T):Void;
  public function append(index:Int, value:T):Int;
  public function length(index:Int):Int;
  public function isActive(index:Int):Bool;
  public function activate(index:Int):Void;
  public function deactivate(index:Int):Void;
  public function lazyGrad():Field<T>;
  public function lazyDual():Field<T>;
}
