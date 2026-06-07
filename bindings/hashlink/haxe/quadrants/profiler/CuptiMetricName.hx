package quadrants.profiler;

enum abstract CuptiMetricName(String) to String {
  var DramUtilization = "dram__throughput.avg.pct_of_peak_sustained_elapsed";
  var DramBytesSum = "dram__bytes.sum";
  var DramBytesThroughput = "dram__bytes.sum.per_second";
  var DramBytesRead = "dram__bytes_read.sum";
  var DramReadThroughput = "dram__bytes_read.sum.per_second";
  var DramBytesWrite = "dram__bytes_write.sum";
  var DramWriteThroughput = "dram__bytes_write.sum.per_second";
  var SharedUtilization = "l1tex__data_pipe_lsu_wavefronts_mem_shared.avg.pct_of_peak_sustained_elapsed";
  var SharedTransactionsLoad = "l1tex__data_pipe_lsu_wavefronts_mem_shared_op_ld.sum";
  var SharedTransactionsStore = "l1tex__data_pipe_lsu_wavefronts_mem_shared_op_st.sum";
  var SharedBankConflictsStore = "l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_st.sum";
  var SharedBankConflictsLoad = "l1tex__data_bank_conflicts_pipe_lsu_mem_shared_op_ld.sum";
  var GlobalOpAtom = "l1tex__t_set_accesses_pipe_lsu_mem_global_op_atom.sum";
  var GlobalOpReduction = "l1tex__t_set_accesses_pipe_lsu_mem_global_op_red.sum";
  var SmThroughput = "smsp__cycles_active.avg.pct_of_peak_sustained_elapsed";
  var DramThroughput = "gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed";
  var L1TexThroughput = "l1tex__throughput.avg.pct_of_peak_sustained_elapsed";
  var L2Throughput = "lts__throughput.avg.pct_of_peak_sustained_elapsed";
  var L1HitRate = "l1tex__t_sector_hit_rate.pct";
  var L2HitRate = "lts__t_sector_hit_rate.pct";
  var AchievedOccupancy = "sm__warps_active.avg.pct_of_peak_sustained_active";

  public static inline function custom(name:String):CuptiMetricName {
    return cast name;
  }
}
