package quadrants;

class Layout {
  public final policy:LayoutPolicy;
  public final order:Array<Int>;

  function new(policy:LayoutPolicy, ?order:Array<Int>) {
    this.policy = policy;
    this.order = order == null ? [] : order.copy();
  }

  public static function permutation(order:Array<Int>):Layout {
    if (order == null || order.length == 0) {
      throw "Quadrants Layout.permutation requires a non-empty order";
    }
    return new Layout(LayoutPolicy.Default, order);
  }

  public static function rowMajor():Layout {
    return new Layout(LayoutPolicy.RowMajor);
  }

  public static function columnMajor():Layout {
    return new Layout(LayoutPolicy.ColumnMajor);
  }

  public function toString():String {
    return 'Layout(policy=${policy}, order=${order.join(",")})';
  }
}
