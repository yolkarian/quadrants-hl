package quadrants;

enum abstract OptLevel(String) to String {
  var O0 = "O0";
  var O1 = "O1";
  var O2 = "O2";
  var O3 = "O3";

  public function toInt():Int {
    return switch (this) {
      case "O0": 0;
      case "O1": 1;
      case "O2": 2;
      case "O3": 3;
      default: throw "Quadrants opt level must be O0, O1, O2, or O3";
    };
  }
}
