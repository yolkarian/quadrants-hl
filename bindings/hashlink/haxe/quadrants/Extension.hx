package quadrants;

enum abstract Extension(Int) from Int to Int {
  var Cuda = 0;
  var CudaGlInterop = 1;
  var StreamEvents = 2;
  var KernelProfiler = 3;
  var ScopedProfiler = 4;
  var MemoryProfiler = 5;
  var ZeroCopy = 6;
  var ExternalPointerImport = 7;
}
