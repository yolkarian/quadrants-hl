package quadrants;

enum abstract LayoutPolicy(Int) from Int to Int {
  var Default = 0;
  var RowMajor = 1;
  var ColumnMajor = 2;
  var AOS = 3;
  var SOA = 4;
}
