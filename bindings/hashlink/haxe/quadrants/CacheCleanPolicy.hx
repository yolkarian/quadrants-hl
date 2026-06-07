package quadrants;

enum abstract CacheCleanPolicy(String) to String {
  var Lru = "lru";
  var Never = "never";
}
