package quadrants;

/**
 * Generic typed view implemented by every concrete Tensor<T> generated dtype class.
 *
 * `Tensor<T>` is a generic-build facade and can only materialize concrete dtype
 * classes such as `Tensor<I32>`. Public APIs that need to relate several tensor
 * dtype parameters use this interface through the `Tensor<T>` facade in generic
 * contexts.
 */
interface TensorArg<T> extends TensorHandle {
  public function elementCount():Int;
  public function read(flatIndex:Int):T;
  public function write(flatIndex:Int, value:T):Void;
}
