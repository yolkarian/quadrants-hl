package quadrants;

import quadrants.Types.Arch;
import quadrants.linalg.SparseBackendFeatures;
import quadrants.profiler.ProfilerBridge;

typedef StreamCapabilities = {
  var available:Bool;
  var events:Bool;
  var parallelBlocks:Bool;
}

typedef GraphCapabilities = {
  var launch:Bool;
  var hostWhile:Bool;
  var nativeDoWhile:Bool;
}

typedef DescriptorCapabilities = {
  var version:Int;
  var maxVersion:Int;
  var typedKernelLaunch:Bool;
  var typedMetadata:Bool;
}

typedef SparseCapabilities = {
  var hostReference:Bool;
  var nativeBackend:Bool;
}

typedef MeshCapabilities = {
  var hostHandles:Bool;
  var kernelRelations:Bool;
  var kernelAttributes:Bool;
  var indexConversion:Bool;
}

typedef QuantCapabilities = {
  var quantArrayPlacement:Bool;
  var bitStructPlacement:Bool;
  var floatPlacement:Bool;
  var kernelParameters:Bool;
}

typedef ProfilerCapabilities = {
  var kernel:Bool;
  var scoped:Bool;
  var memory:Bool;
}

typedef InteropCapabilities = {
  var zeroCopy:Bool;
  var dlpack:Bool;
  var externalPointerImport:Bool;
  var cudaGlInterop:Bool;
}

typedef VersionCapabilities = {
  var packageVersion:String;
  var expectedHdllAbi:Int;
  var expectedRuntimeAbi:Int;
  var descriptorVersion:Int;
  var descriptorMaxVersion:Int;
}

class Capabilities {
  public final backend:Arch;
  public final streams:StreamCapabilities;
  public final graph:GraphCapabilities;
  public final descriptor:DescriptorCapabilities;
  public final sparse:SparseCapabilities;
  public final mesh:MeshCapabilities;
  public final quant:QuantCapabilities;
  public final profiler:ProfilerCapabilities;
  public final interop:InteropCapabilities;
  public final version:VersionCapabilities;
  public final fieldResourceParam:Bool;
  public final structTensor:Bool;
  public final meshKernelAccess:Bool;
  public final quantKernelParam:Bool;
  public final streamParallel:Bool;
  public final nativeSparse:Bool;
  public final memoryProfiler:Bool;
  public final runtimeConfigWarnings:Array<String>;

  public function new(context:Context) {
    backend = context.arch;
    var streamAvailable = probeStreamAvailability(context);
    var sparseFeatures = SparseBackendFeatures.probe(context);
    var profilerFeatures = ProfilerBridge.features(context);
    streams = {
      available: streamAvailable,
      events: streamAvailable && context.supportsStreamEvents(),
      parallelBlocks: false,
    };
    graph = {
      launch: true,
      hostWhile: true,
      nativeDoWhile: true,
    };
    descriptor = {
      version: VersionInfo.DESCRIPTOR_VERSION,
      maxVersion: VersionInfo.DESCRIPTOR_MAX_VERSION,
      typedKernelLaunch: true,
      typedMetadata: true,
    };
    sparse = {
      hostReference: sparseFeatures.hostReferenceBackend,
      nativeBackend: sparseFeatures.nativeSparseBackend,
    };
    mesh = {
      hostHandles: true,
      kernelRelations: true,
      kernelAttributes: true,
      indexConversion: true,
    };
    quant = {
      quantArrayPlacement: true,
      bitStructPlacement: true,
      floatPlacement: true,
      kernelParameters: true,
    };
    profiler = {
      kernel: profilerFeatures.kernel,
      scoped: profilerFeatures.scoped,
      memory: profilerFeatures.memory,
    };
    var zeroCopy = context.isExtensionEnabled(Extension.ZeroCopy);
    interop = {
      zeroCopy: zeroCopy,
      dlpack: zeroCopy,
      externalPointerImport: context.isExtensionEnabled(Extension.ExternalPointerImport),
      cudaGlInterop: context.isExtensionEnabled(Extension.CudaGlInterop),
    };
    version = VersionInfo.current();
    fieldResourceParam = true;
    structTensor = true;
    meshKernelAccess = mesh.kernelRelations && mesh.kernelAttributes;
    quantKernelParam = quant.kernelParameters;
    streamParallel = streams.parallelBlocks;
    nativeSparse = sparse.nativeBackend;
    memoryProfiler = profiler.memory;
    runtimeConfigWarnings = context.optionWarnings();
  }

  public function toDynamic():Dynamic {
    return {
      backend: backend,
      streams: streams,
      graph: graph,
      descriptor: descriptor,
      sparse: sparse,
      mesh: mesh,
      quant: quant,
      profiler: profiler,
      interop: interop,
      version: version,
      fieldResourceParam: fieldResourceParam,
      structTensor: structTensor,
      meshKernelAccess: meshKernelAccess,
      quantKernelParam: quantKernelParam,
      streamParallel: streamParallel,
      nativeSparse: nativeSparse,
      memoryProfiler: memoryProfiler,
      runtimeConfigWarnings: [for (warning in runtimeConfigWarnings) warning],
    };
  }

  static function probeStreamAvailability(context:Context):Bool {
    var stream:Stream = null;
    try {
      stream = context.stream();
      stream.close();
      return true;
    } catch (_:Dynamic) {
      if (stream != null) {
        try stream.close() catch (_:Dynamic) {}
      }
      return false;
    }
  }
}
