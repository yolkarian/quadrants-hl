package quadrants.perf;

class PerfDispatchSelection<TGeometry, TResult> {
  public final key:String;
  public final candidateName:String;
  public final result:TResult;
  public final cacheHit:Bool;

  public function new(key:String, candidateName:String, result:TResult, cacheHit:Bool) {
    this.key = key;
    this.candidateName = candidateName;
    this.result = result;
    this.cacheHit = cacheHit;
  }
}
