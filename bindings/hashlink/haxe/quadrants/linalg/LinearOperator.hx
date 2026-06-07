package quadrants.linalg;

import quadrants.TensorArg;

interface LinearOperator<T> {
  public function apply(x:TensorArg<T>, y:TensorArg<T>):Void;
}
