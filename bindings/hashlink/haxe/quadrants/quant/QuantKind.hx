package quadrants.quant;

enum abstract QuantKind(Int) from Int to Int {
  var IntStorage = 1;
  var Fixed = 2;
  var FloatStorage = 3;
}
