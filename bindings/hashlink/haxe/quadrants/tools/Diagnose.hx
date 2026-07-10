package quadrants.tools;

import haxe.Json;
import haxe.Utf8;
import quadrants.Capabilities;
import quadrants.Context;
import quadrants.Native;
import quadrants.Types.Arch;
import quadrants.VersionInfo;

/** Outcome of one in-process backend probe. */
enum abstract DiagnosticProbeStatus(String) from String to String {
  var Available = "available";
  var Unavailable = "unavailable";
  var Skipped = "skipped";
  var Error = "error";
}

/** Host facts available without invoking external processes. */
class DiagnosticPlatform {
  public final systemName:String;
  public final programPath:String;
  public final workingDirectory:String;
  public final architecture:Null<String>;
  public final architectureSource:String;

  public function new(
    systemName:String,
    programPath:String,
    workingDirectory:String,
    architecture:Null<String>,
    architectureSource:String) {
    this.systemName = systemName;
    this.programPath = programPath;
    this.workingDirectory = workingDirectory;
    this.architecture = architecture;
    this.architectureSource = architectureSource;
  }
}

/** Binding-side version expectations obtained through `VersionInfo.current()`. */
class DiagnosticBindingVersion {
  public final packageVersion:String;
  public final expectedHdllAbi:Int;
  public final expectedRuntimeAbi:Int;
  public final descriptorVersion:Int;
  public final descriptorMaxVersion:Int;

  public function new(
    packageVersion:String,
    expectedHdllAbi:Int,
    expectedRuntimeAbi:Int,
    descriptorVersion:Int,
    descriptorMaxVersion:Int) {
    this.packageVersion = packageVersion;
    this.expectedHdllAbi = expectedHdllAbi;
    this.expectedRuntimeAbi = expectedRuntimeAbi;
    this.descriptorVersion = descriptorVersion;
    this.descriptorMaxVersion = descriptorMaxVersion;
  }
}

/** Native ABI observations, including a caught compatibility-check error when present. */
class DiagnosticNativeVersion {
  public final available:Bool;
  public final compatible:Null<Bool>;
  public final hdllAbi:Null<Int>;
  public final runtimeAbi:Null<Int>;
  public final descriptorVersion:Null<Int>;
  public final error:Null<String>;

  public function new(
    available:Bool,
    compatible:Null<Bool>,
    hdllAbi:Null<Int>,
    runtimeAbi:Null<Int>,
    descriptorVersion:Null<Int>,
    error:Null<String>) {
    this.available = available;
    this.compatible = compatible;
    this.hdllAbi = hdllAbi;
    this.runtimeAbi = runtimeAbi;
    this.descriptorVersion = descriptorVersion;
    this.error = error;
  }
}

/** One relevant runtime environment variable, emitted in lexicographic key order. */
class DiagnosticEnvironmentVariable {
  public final name:String;
  public final value:String;

  public function new(name:String, value:String) {
    this.name = name;
    this.value = value;
  }
}

/** Availability and an immutable `Capabilities` snapshot for one requested backend. */
class DiagnosticBackend {
  public final arch:Arch;
  public final status:DiagnosticProbeStatus;
  public final message:Null<String>;
  public final capabilities:Null<Capabilities>;

  public function new(arch:Arch, status:DiagnosticProbeStatus, message:Null<String>, capabilities:Null<Capabilities>) {
    this.arch = arch;
    this.status = status;
    this.message = message;
    this.capabilities = capabilities;
  }
}

/**
  Fully typed result of a host diagnostic collection.

  Backend probes are opt-in. When requested they run in this process, so native
  crashes cannot be isolated by this API; ordinary exceptions are captured in
  the corresponding `DiagnosticBackend` instead.
*/
class DiagnosticReport {
  public static inline var FORMAT = "quadrants-hl.diagnose.v1";
  public static inline var BACKEND_PROBE_POLICY =
    "Backend probes are opt-in and run in-process; native crashes are not isolated.";

  public final platform:DiagnosticPlatform;
  public final bindingVersion:DiagnosticBindingVersion;
  public final nativeVersion:DiagnosticNativeVersion;
  public final environment:Array<DiagnosticEnvironmentVariable>;
  public final backends:Array<DiagnosticBackend>;
  public final backendProbesRequested:Bool;

  public function new(
    platform:DiagnosticPlatform,
    bindingVersion:DiagnosticBindingVersion,
    nativeVersion:DiagnosticNativeVersion,
    environment:Array<DiagnosticEnvironmentVariable>,
    backends:Array<DiagnosticBackend>,
    backendProbesRequested:Bool) {
    this.platform = platform;
    this.bindingVersion = bindingVersion;
    this.nativeVersion = nativeVersion;
    this.environment = environment;
    this.backends = backends;
    this.backendProbesRequested = backendProbesRequested;
  }

  /** Renders a deterministic, human-readable report. */
  public function toText():String {
    var output = new StringBuf();
    output.add("Quadrants HashLink diagnostic report\n\n");
    output.add("Platform\n");
    output.add("  system: ");
    output.add(oneLine(platform.systemName));
    output.add("\n  program: ");
    output.add(oneLine(platform.programPath));
    output.add("\n  working directory: ");
    output.add(oneLine(platform.workingDirectory));
    output.add("\n  architecture: ");
    output.add(platform.architecture == null ? "unavailable" : oneLine(platform.architecture));
    output.add("\n  architecture source: ");
    output.add(oneLine(platform.architectureSource));
    output.add("\n\nBinding versions\n");
    output.add("  package: ");
    output.add(oneLine(bindingVersion.packageVersion));
    output.add("\n  expected HashLink HDLL ABI: ");
    output.add(Std.string(bindingVersion.expectedHdllAbi));
    output.add("\n  expected runtime ABI: ");
    output.add(Std.string(bindingVersion.expectedRuntimeAbi));
    output.add("\n  descriptor schema: ");
    output.add(Std.string(bindingVersion.descriptorVersion));
    output.add(" (max ");
    output.add(Std.string(bindingVersion.descriptorMaxVersion));
    output.add(")\n\nNative bridge\n");
    output.add("  available: ");
    output.add(boolText(nativeVersion.available));
    output.add("\n  compatible: ");
    output.add(nullableBoolText(nativeVersion.compatible));
    output.add("\n  HashLink HDLL ABI: ");
    output.add(nullableIntText(nativeVersion.hdllAbi));
    output.add("\n  runtime ABI: ");
    output.add(nullableIntText(nativeVersion.runtimeAbi));
    output.add("\n  descriptor schema: ");
    output.add(nullableIntText(nativeVersion.descriptorVersion));
    if (nativeVersion.error != null) {
      output.add("\n  observation: ");
      output.add(oneLine(nativeVersion.error));
    }

    output.add("\n\nEnvironment (QD_/QUADRANTS_)\n");
    if (environment.length == 0) {
      output.add("  (none)\n");
    } else {
      for (entry in environment) {
        output.add("  ");
        output.add(entry.name);
        output.add("=");
        output.add(oneLine(entry.value));
        output.add("\n");
      }
    }

    output.add("\nBackend probes\n  requested: ");
    output.add(boolText(backendProbesRequested));
    output.add("\n  policy: ");
    output.add(BACKEND_PROBE_POLICY);
    output.add("\n\nBackends\n");
    for (backend in backends) {
      output.add("  ");
      output.add(archName(backend.arch));
      output.add(": ");
      output.add(cast backend.status);
      if (backend.message != null) {
        output.add(" — ");
        output.add(oneLine(backend.message));
      }
      output.add("\n");
      if (backend.capabilities != null) {
        output.add("    ");
        output.add(capabilitySummary(backend.capabilities));
        output.add("\n");
        for (warning in backend.capabilities.runtimeConfigWarnings) {
          output.add("    configuration warning: ");
          output.add(oneLine(warning));
          output.add("\n");
        }
      }
    }
    return output.toString();
  }

  /** Renders a deterministic JSON object without exposing an untyped public API. */
  public function toJson():String {
    var output = new StringBuf();
    output.add("{\"format\":");
    appendJsonString(output, FORMAT);
    output.add(",\"platform\":");
    appendPlatformJson(output, platform);
    output.add(",\"bindingVersion\":");
    appendBindingVersionJson(output, bindingVersion);
    output.add(",\"nativeVersion\":");
    appendNativeVersionJson(output, nativeVersion);
    output.add(",\"environment\":[");
    for (index in 0...environment.length) {
      if (index > 0) {
        output.add(",");
      }
      var entry = environment[index];
      output.add("{\"name\":");
      appendJsonString(output, entry.name);
      output.add(",\"value\":");
      appendJsonString(output, entry.value);
      output.add("}");
    }
    output.add("],\"backendProbesRequested\":");
    appendJsonBool(output, backendProbesRequested);
    output.add(",\"backendProbePolicy\":");
    appendJsonString(output, BACKEND_PROBE_POLICY);
    output.add(",\"backends\":[");
    for (index in 0...backends.length) {
      if (index > 0) {
        output.add(",");
      }
      appendBackendJson(output, backends[index]);
    }
    output.add("]}");
    return output.toString();
  }

  private static function appendPlatformJson(output:StringBuf, value:DiagnosticPlatform):Void {
    output.add("{\"systemName\":");
    appendJsonString(output, value.systemName);
    output.add(",\"programPath\":");
    appendJsonString(output, value.programPath);
    output.add(",\"workingDirectory\":");
    appendJsonString(output, value.workingDirectory);
    output.add(",\"architecture\":");
    appendJsonNullableString(output, value.architecture);
    output.add(",\"architectureSource\":");
    appendJsonString(output, value.architectureSource);
    output.add("}");
  }

  private static function appendBindingVersionJson(output:StringBuf, value:DiagnosticBindingVersion):Void {
    output.add("{\"packageVersion\":");
    appendJsonString(output, value.packageVersion);
    output.add(",\"expectedHdllAbi\":");
    output.add(Std.string(value.expectedHdllAbi));
    output.add(",\"expectedRuntimeAbi\":");
    output.add(Std.string(value.expectedRuntimeAbi));
    output.add(",\"descriptorVersion\":");
    output.add(Std.string(value.descriptorVersion));
    output.add(",\"descriptorMaxVersion\":");
    output.add(Std.string(value.descriptorMaxVersion));
    output.add("}");
  }

  private static function appendNativeVersionJson(output:StringBuf, value:DiagnosticNativeVersion):Void {
    output.add("{\"available\":");
    appendJsonBool(output, value.available);
    output.add(",\"compatible\":");
    appendJsonNullableBool(output, value.compatible);
    output.add(",\"hdllAbi\":");
    appendJsonNullableInt(output, value.hdllAbi);
    output.add(",\"runtimeAbi\":");
    appendJsonNullableInt(output, value.runtimeAbi);
    output.add(",\"descriptorVersion\":");
    appendJsonNullableInt(output, value.descriptorVersion);
    output.add(",\"error\":");
    appendJsonNullableString(output, value.error);
    output.add("}");
  }

  private static function appendBackendJson(output:StringBuf, value:DiagnosticBackend):Void {
    output.add("{\"arch\":");
    appendJsonString(output, archName(value.arch));
    output.add(",\"status\":");
    appendJsonString(output, cast value.status);
    output.add(",\"message\":");
    appendJsonNullableString(output, value.message);
    output.add(",\"capabilities\":");
    if (value.capabilities == null) {
      output.add("null");
    } else {
      appendCapabilitiesJson(output, value.capabilities);
    }
    output.add("}");
  }

  private static function appendCapabilitiesJson(output:StringBuf, value:Capabilities):Void {
    output.add("{\"backend\":");
    appendJsonString(output, archName(value.backend));
    output.add(",\"streams\":{\"available\":");
    appendJsonBool(output, value.streams.available);
    output.add(",\"events\":");
    appendJsonBool(output, value.streams.events);
    output.add(",\"parallelBlocks\":");
    appendJsonBool(output, value.streams.parallelBlocks);
    output.add("},\"graph\":{\"launch\":");
    appendJsonBool(output, value.graph.launch);
    output.add(",\"hostWhile\":");
    appendJsonBool(output, value.graph.hostWhile);
    output.add(",\"nativeDoWhile\":");
    appendJsonBool(output, value.graph.nativeDoWhile);
    output.add("},\"descriptor\":{\"version\":");
    output.add(Std.string(value.descriptor.version));
    output.add(",\"maxVersion\":");
    output.add(Std.string(value.descriptor.maxVersion));
    output.add(",\"typedKernelLaunch\":");
    appendJsonBool(output, value.descriptor.typedKernelLaunch);
    output.add(",\"typedMetadata\":");
    appendJsonBool(output, value.descriptor.typedMetadata);
    output.add("},\"sparse\":{\"hostReference\":");
    appendJsonBool(output, value.sparse.hostReference);
    output.add(",\"nativeBackend\":");
    appendJsonBool(output, value.sparse.nativeBackend);
    output.add("},\"mesh\":{\"hostHandles\":");
    appendJsonBool(output, value.mesh.hostHandles);
    output.add(",\"kernelRelations\":");
    appendJsonBool(output, value.mesh.kernelRelations);
    output.add(",\"kernelAttributes\":");
    appendJsonBool(output, value.mesh.kernelAttributes);
    output.add(",\"indexConversion\":");
    appendJsonBool(output, value.mesh.indexConversion);
    output.add("},\"quant\":{\"quantArrayPlacement\":");
    appendJsonBool(output, value.quant.quantArrayPlacement);
    output.add(",\"bitStructPlacement\":");
    appendJsonBool(output, value.quant.bitStructPlacement);
    output.add(",\"floatPlacement\":");
    appendJsonBool(output, value.quant.floatPlacement);
    output.add(",\"kernelParameters\":");
    appendJsonBool(output, value.quant.kernelParameters);
    output.add("},\"profiler\":{\"kernel\":");
    appendJsonBool(output, value.profiler.kernel);
    output.add(",\"scoped\":");
    appendJsonBool(output, value.profiler.scoped);
    output.add(",\"memory\":");
    appendJsonBool(output, value.profiler.memory);
    output.add("},\"interop\":{\"zeroCopy\":");
    appendJsonBool(output, value.interop.zeroCopy);
    output.add(",\"dlpack\":");
    appendJsonBool(output, value.interop.dlpack);
    output.add(",\"externalPointerImport\":");
    appendJsonBool(output, value.interop.externalPointerImport);
    output.add(",\"cudaGlInterop\":");
    appendJsonBool(output, value.interop.cudaGlInterop);
    output.add("},\"version\":{\"packageVersion\":");
    appendJsonString(output, value.version.packageVersion);
    output.add(",\"expectedHdllAbi\":");
    output.add(Std.string(value.version.expectedHdllAbi));
    output.add(",\"expectedRuntimeAbi\":");
    output.add(Std.string(value.version.expectedRuntimeAbi));
    output.add(",\"descriptorVersion\":");
    output.add(Std.string(value.version.descriptorVersion));
    output.add(",\"descriptorMaxVersion\":");
    output.add(Std.string(value.version.descriptorMaxVersion));
    output.add("},\"fieldResourceParam\":");
    appendJsonBool(output, value.fieldResourceParam);
    output.add(",\"structTensor\":");
    appendJsonBool(output, value.structTensor);
    output.add(",\"meshKernelAccess\":");
    appendJsonBool(output, value.meshKernelAccess);
    output.add(",\"quantKernelParam\":");
    appendJsonBool(output, value.quantKernelParam);
    output.add(",\"streamParallel\":");
    appendJsonBool(output, value.streamParallel);
    output.add(",\"nativeSparse\":");
    appendJsonBool(output, value.nativeSparse);
    output.add(",\"memoryProfiler\":");
    appendJsonBool(output, value.memoryProfiler);
    output.add(",\"runtimeConfigWarnings\":[");
    for (index in 0...value.runtimeConfigWarnings.length) {
      if (index > 0) {
        output.add(",");
      }
      appendJsonString(output, value.runtimeConfigWarnings[index]);
    }
    output.add("]}");
  }

  private static inline function appendJsonString(output:StringBuf, value:String):Void {
    output.add(Json.stringify(value));
  }

  private static function appendJsonNullableString(output:StringBuf, value:Null<String>):Void {
    if (value == null) {
      output.add("null");
    } else {
      appendJsonString(output, value);
    }
  }

  private static inline function appendJsonBool(output:StringBuf, value:Bool):Void {
    output.add(value ? "true" : "false");
  }

  private static function appendJsonNullableBool(output:StringBuf, value:Null<Bool>):Void {
    if (value == null) {
      output.add("null");
    } else {
      appendJsonBool(output, value);
    }
  }

  private static function appendJsonNullableInt(output:StringBuf, value:Null<Int>):Void {
    output.add(value == null ? "null" : Std.string(value));
  }

  private static function capabilitySummary(value:Capabilities):String {
    return 'streams available=${value.streams.available}, events=${value.streams.events}; '
      + 'sparse host=${value.sparse.hostReference}, native=${value.sparse.nativeBackend}; '
      + 'profiler kernel=${value.profiler.kernel}, scoped=${value.profiler.scoped}, memory=${value.profiler.memory}; '
      + 'interop zeroCopy=${value.interop.zeroCopy}, dlpack=${value.interop.dlpack}, '
      + 'externalPointerImport=${value.interop.externalPointerImport}, cudaGlInterop=${value.interop.cudaGlInterop}';
  }

  private static function archName(arch:Arch):String {
    return switch (arch) {
      case Arch.Cpu: "cpu";
      case Arch.Cuda: "cuda";
      case Arch.Vulkan: "vulkan";
      case Arch.Metal: "metal";
      case Arch.Amdgpu: "amdgpu";
    };
  }

  private static inline function boolText(value:Bool):String {
    return value ? "true" : "false";
  }

  private static function nullableBoolText(value:Null<Bool>):String {
    return value == null ? "unavailable" : boolText(value);
  }

  private static function nullableIntText(value:Null<Int>):String {
    return value == null ? "unavailable" : Std.string(value);
  }

  private static function oneLine(value:String):String {
    return StringTools.replace(StringTools.replace(value, "\r", " "), "\n", " ");
  }
}

/** Pure-Haxe host diagnostic collection and command-line entry point. */
class Diagnose {
  /**
    Collects a report without launching external commands. Architecture probing
    is disabled by default because it creates native contexts in this process.
  */
  public static function collect(probeBackends:Bool = false):DiagnosticReport {
    var version = VersionInfo.current();
    var bindingVersion = new DiagnosticBindingVersion(
      version.packageVersion,
      version.expectedHdllAbi,
      version.expectedRuntimeAbi,
      version.descriptorVersion,
      version.descriptorMaxVersion);
    return new DiagnosticReport(
      collectPlatform(),
      bindingVersion,
      collectNativeVersion(),
      collectEnvironment(),
      collectBackends(probeBackends),
      probeBackends);
  }

  /**
    CLI options: `--json` selects JSON output and `--probe-backends` opts into
    in-process backend probes. Unavailable backends are reported, not treated
    as a process failure.
  */
  public static function main():Void {
    var json = false;
    var probeBackends = false;
    try {
      for (argument in Sys.args()) {
        switch (argument) {
          case "--json":
            json = true;
          case "--probe-backends":
            probeBackends = true;
          case "--help":
            Sys.stdout().writeString("Usage: Diagnose [--json] [--probe-backends]\n");
            return;
          default:
            throw 'Unknown Diagnose argument: ${argument}';
        }
      }
      var report = collect(probeBackends);
      Sys.stdout().writeString(json ? report.toJson() : report.toText());
      Sys.stdout().writeByte(10);
    } catch (error:Dynamic) {
      Sys.stderr().writeString('Quadrants diagnose failed: ${Std.string(error)}\n');
      Sys.exit(1);
    }
  }

  private static function collectPlatform():DiagnosticPlatform {
    return new DiagnosticPlatform(
      Sys.systemName(),
      Sys.programPath(),
      Sys.getCwd(),
      null,
      "HashLink Sys API does not expose host architecture");
  }

  private static function collectNativeVersion():DiagnosticNativeVersion {
    try {
      Native.ensureConfigured();
      var hdllAbi = Native.hashlink_hdll_abi_version();
      var runtimeAbi = Native.hashlink_runtime_abi_version();
      var descriptorVersion = Native.hashlink_descriptor_schema_version();
      var compatibilityError:Null<String> = null;
      try {
        VersionInfo.checkNativeCompatibility();
      } catch (error:Dynamic) {
        compatibilityError = Std.string(error);
      }
      return new DiagnosticNativeVersion(
        true,
        compatibilityError == null,
        hdllAbi,
        runtimeAbi,
        descriptorVersion,
        compatibilityError);
    } catch (error:Dynamic) {
      return new DiagnosticNativeVersion(false, null, null, null, null, Std.string(error));
    }
  }

  private static function collectEnvironment():Array<DiagnosticEnvironmentVariable> {
    var values = Sys.environment();
    var names = new Array<String>();
    for (name in values.keys()) {
      if (StringTools.startsWith(name, "QD_") || StringTools.startsWith(name, "QUADRANTS_")) {
        names.push(name);
      }
    }
    names.sort(Utf8.compare);

    var result = new Array<DiagnosticEnvironmentVariable>();
    for (name in names) {
      var value = values.get(name);
      if (value != null) {
        result.push(new DiagnosticEnvironmentVariable(name, value));
      }
    }
    return result;
  }

  private static function collectBackends(probeBackends:Bool):Array<DiagnosticBackend> {
    var targets:Array<Arch> = [Arch.Cpu, Arch.Cuda, Arch.Vulkan, Arch.Metal, Arch.Amdgpu];
    var result = new Array<DiagnosticBackend>();
    for (arch in targets) {
      if (probeBackends) {
        result.push(probeBackend(arch));
      } else {
        result.push(new DiagnosticBackend(
          arch,
          DiagnosticProbeStatus.Skipped,
          "Backend probing is disabled; pass --probe-backends or collect(true) to opt in.",
          null));
      }
    }
    return result;
  }

  private static function probeBackend(arch:Arch):DiagnosticBackend {
    var context:Context = null;
    var status:DiagnosticProbeStatus = DiagnosticProbeStatus.Unavailable;
    var message:Null<String> = null;
    var capabilities:Null<Capabilities> = null;
    try {
      context = Context.create({arch: arch});
      capabilities = context.capabilities();
      status = DiagnosticProbeStatus.Available;
    } catch (error:Dynamic) {
      message = Std.string(error);
    }

    if (context != null) {
      try {
        context.close();
      } catch (error:Dynamic) {
        var closeMessage = 'Context close failed: ${Std.string(error)}';
        status = DiagnosticProbeStatus.Error;
        message = message == null ? closeMessage : message + "; " + closeMessage;
      }
    }
    return new DiagnosticBackend(arch, status, message, capabilities);
  }
}
