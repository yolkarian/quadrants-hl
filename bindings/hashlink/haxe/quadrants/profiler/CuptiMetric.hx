package quadrants.profiler;

@:final class CuptiMetric {
  static inline var BytesScale:Float = 1.0 / 1024.0 / 1024.0;
  static inline var ThroughputScale:Float = 1.0 / 1024.0 / 1024.0 / 1024.0;

  public final name:CuptiMetricName;
  public final header:String;
  public final valueFormat:String;
  public final scale:Float;

  public function new(name:CuptiMetricName, header:String = "unnamed_header", valueFormat:String = "     {:8.0f} ", scale:Float = 1.0) {
    this.name = name;
    this.header = header;
    this.valueFormat = valueFormat;
    this.scale = scale;
  }

  public inline function nativeName():String {
    return (name : String);
  }

  public static function dramUtilization():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramUtilization, " global.uti ", "   {:6.2f} % ");
  }

  public static function dramBytesSum():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramBytesSum, "  global.R&W ", "{:9.3f} MB ", BytesScale);
  }

  public static function dramBytesThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramBytesThroughput, " global.R&W/s ", "{:8.3f} GB/s ", ThroughputScale);
  }

  public static function dramBytesRead():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramBytesRead, "   global.R ", "{:8.3f} MB ", BytesScale);
  }

  public static function dramReadThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramReadThroughput, "   global.R/s ", "{:8.3f} GB/s ", ThroughputScale);
  }

  public static function dramBytesWrite():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramBytesWrite, "   global.W ", "{:8.3f} MB ", BytesScale);
  }

  public static function dramWriteThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramWriteThroughput, "   global.W/s ", "{:8.3f} GB/s ", ThroughputScale);
  }

  public static function sharedUtilization():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SharedUtilization, " uqd.shared ", "   {:6.2f} % ");
  }

  public static function sharedTransactionsLoad():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SharedTransactionsLoad, " shared.trans.W ", "     {:10.0f} ");
  }

  public static function sharedTransactionsStore():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SharedTransactionsStore, " shared.trans.R ", "     {:10.0f} ");
  }

  public static function sharedBankConflictsStore():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SharedBankConflictsStore, " bank.conflict.W ", "      {:10.0f} ");
  }

  public static function sharedBankConflictsLoad():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SharedBankConflictsLoad, " bank.conflict.R ", "      {:10.0f} ");
  }

  public static function globalOpAtom():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.GlobalOpAtom, " global.atom ", "    {:8.0f} ");
  }

  public static function globalOpReduction():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.GlobalOpReduction, " global.red ", "   {:8.0f} ");
  }

  public static function smThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.SmThroughput, " core.uti ", " {:6.2f} % ");
  }

  public static function dramThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.DramThroughput, "  mem.uti ", " {:6.2f} % ");
  }

  public static function l1TexThroughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.L1TexThroughput, "   L1.uti ", " {:6.2f} % ");
  }

  public static function l2Throughput():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.L2Throughput, "   L2.uti ", " {:6.2f} % ");
  }

  public static function l1HitRate():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.L1HitRate, "   L1.hit ", " {:6.2f} % ");
  }

  public static function l2HitRate():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.L2HitRate, "   L2.hit ", " {:6.2f} % ");
  }

  public static function achievedOccupancy():CuptiMetric {
    return new CuptiMetric(CuptiMetricName.AchievedOccupancy, " occupancy", "   {:6.0f} ");
  }

  public static function preset(preset:CuptiMetricPreset):Array<CuptiMetric> {
    return switch (preset) {
      case Default:
        [dramBytesSum()];
      case GlobalAccess:
        [dramBytesSum(), dramBytesThroughput(), dramBytesRead(), dramReadThroughput(), dramBytesWrite(), dramWriteThroughput()];
      case SharedAccess:
        [sharedTransactionsLoad(), sharedTransactionsStore(), sharedBankConflictsStore(), sharedBankConflictsLoad()];
      case AtomicAccess:
        [globalOpAtom(), globalOpReduction()];
      case CacheHitRate:
        [l1HitRate(), l2HitRate()];
      case DeviceUtilization:
        [smThroughput(), dramThroughput(), sharedUtilization(), l1TexThroughput(), l2Throughput()];
      default:
        [dramBytesSum()];
    }
  }
}
