package quadrants;

abstract QContext(hl.Abstract<"qd_context">) {}
abstract QKernel(hl.Abstract<"qd_kernel">) {}
abstract QNdarray(hl.Abstract<"qd_ndarray">) {}
abstract QStream(hl.Abstract<"qd_stream">) {}
abstract QStreamEvent(hl.Abstract<"qd_event">) {}
abstract QSNodeTree(hl.Abstract<"qd_snode_tree">) {}
abstract QCudaGlResource(hl.Abstract<"qd_cuda_gl_resource">) {}
abstract QSparseMatrix(hl.Abstract<"qd_sparse_matrix">) {}
abstract QSparseSolver(hl.Abstract<"qd_sparse_solver">) {}
abstract QMeshRelation(hl.Abstract<"qd_mesh_relation">) {}

@:build(quadrants.macro.NativeLibrary.build())
class Native {
  static var configured = false;
  static final packagedRuntimeLibDir:String = quadrants.macro.NativeLibrary.runtimeLibDir();

  public static function ensureConfigured():Void {
    if (configured) {
      return;
    }
    configured = true;

    var runtimeLibDir = Sys.getEnv("QD_LIB_DIR");
    if (runtimeLibDir == null || runtimeLibDir.length == 0) {
      runtimeLibDir = Sys.getEnv("QUADRANTS_RUNTIME_DIR");
    }
    if (runtimeLibDir == null || runtimeLibDir.length == 0) {
      runtimeLibDir = packagedRuntimeLibDir;
    }
    if (runtimeLibDir != null && runtimeLibDir.length > 0) {
      @:privateAccess runtime_set_lib_dir(runtimeLibDir.toUtf8());
    }
  }

  @:hlNative("quadrants", "hashlink_hdll_abi_version")
  public static function hashlink_hdll_abi_version():Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "hashlink_runtime_abi_version")
  public static function hashlink_runtime_abi_version():Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "hashlink_descriptor_schema_version")
  public static function hashlink_descriptor_schema_version():Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "runtime_set_lib_dir")
  static function runtime_set_lib_dir(path:hl.Bytes):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_create")
  public static function context_create(arch:Int):QContext {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_create_configured")
  public static function context_create_configured(arch:Int, enableProfiler:Int):QContext {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_sync")
  public static function context_sync(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_close")
  public static function context_close(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_create")
  public static function stream_create(ctx:QContext):QStream {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_supports_events")
  public static function stream_supports_events(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_event_create")
  public static function stream_event_create(ctx:QContext):QStreamEvent {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_event_record")
  public static function stream_event_record(ctx:QContext, event:QStreamEvent, stream:QStream):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_event_sync")
  public static function stream_event_sync(ctx:QContext, event:QStreamEvent):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_wait_event")
  public static function stream_wait_event(ctx:QContext, stream:QStream, event:QStreamEvent):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_event_close")
  public static function stream_event_close(event:QStreamEvent):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_sync")
  public static function stream_sync(ctx:QContext, stream:QStream):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "stream_close")
  public static function stream_close(stream:QStream):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_offline_cache")
  public static function context_set_offline_cache(ctx:QContext, enabled:Int, path:hl.Bytes):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_start")
  public static function profiler_start(ctx:QContext, kernelName:hl.Bytes):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_stop")
  public static function profiler_stop(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_adstack_config")
  public static function context_set_adstack_config(ctx:QContext, experimentalEnabled:Int, stackSize:Int, sparseThresholdBytes:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_debug_dump")
  public static function context_set_debug_dump(ctx:QContext, path:hl.Bytes, printIr:Int, printPreprocessedIr:Int, printIrDebugInfo:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_random_seed")
  public static function context_set_random_seed(ctx:QContext, seed:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }


  @:hlNative("quadrants", "context_set_cpu_max_num_threads")
  public static function context_set_cpu_max_num_threads(ctx:QContext, threadCount:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_fast_math")
  public static function context_set_fast_math(ctx:QContext, enabled:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "context_set_bounds_check")
  public static function context_set_bounds_check(ctx:QContext, enabled:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }
  @:hlNative("quadrants", "profiler_clear")
  public static function profiler_clear(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_total_time")
  public static function profiler_total_time(ctx:QContext):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_query_count")
  public static function profiler_query_count(ctx:QContext, kernelName:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_query_min")
  public static function profiler_query_min(ctx:QContext, kernelName:hl.Bytes):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_query_max")
  public static function profiler_query_max(ctx:QContext, kernelName:hl.Bytes):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_query_avg")
  public static function profiler_query_avg(ctx:QContext, kernelName:hl.Bytes):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_is_enabled")
  public static function profiler_is_enabled(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_scoped_available")
  public static function profiler_scoped_available(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_memory_available")
  public static function profiler_memory_available(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_memory_print")
  public static function profiler_memory_print(ctx:QContext):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_kernel_available")
  public static function profiler_kernel_available(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_set_toolkit")
  public static function profiler_set_toolkit(ctx:QContext, toolkitName:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "profiler_set_metrics")
  public static function profiler_set_metrics(ctx:QContext, metricNames:hl.NativeArray<hl.Bytes>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_backend_kind")
  public static function sparse_backend_kind(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_supports_native_backend")
  public static function sparse_supports_native_backend(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_supports_dtype")
  public static function sparse_supports_dtype(ctx:QContext, dtype:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_create")
  public static function sparse_matrix_create(ctx:QContext, rows:Int, cols:Int, dtype:Int, storageFormat:Int):QSparseMatrix {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_close")
  public static function sparse_matrix_close(matrix:QSparseMatrix):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_clear")
  public static function sparse_matrix_clear(ctx:QContext, matrix:QSparseMatrix):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_rows")
  public static function sparse_matrix_rows(ctx:QContext, matrix:QSparseMatrix):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_cols")
  public static function sparse_matrix_cols(ctx:QContext, matrix:QSparseMatrix):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_nnz")
  public static function sparse_matrix_nnz(ctx:QContext, matrix:QSparseMatrix):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_set_f32")
  public static function sparse_matrix_set_f32(ctx:QContext, matrix:QSparseMatrix, row:Int, col:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_get_f32")
  public static function sparse_matrix_get_f32(ctx:QContext, matrix:QSparseMatrix, row:Int, col:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_matvec_f32")
  public static function sparse_matrix_matvec_f32(ctx:QContext, matrix:QSparseMatrix, x:QNdarray, y:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_set_f64")
  public static function sparse_matrix_set_f64(ctx:QContext, matrix:QSparseMatrix, row:Int, col:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_get_f64")
  public static function sparse_matrix_get_f64(ctx:QContext, matrix:QSparseMatrix, row:Int, col:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_matrix_matvec_f64")
  public static function sparse_matrix_matvec_f64(ctx:QContext, matrix:QSparseMatrix, x:QNdarray, y:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_create")
  public static function sparse_solver_create(ctx:QContext, dtype:Int, solverType:hl.Bytes, ordering:hl.Bytes, allowHostDenseFallback:Int):QSparseSolver {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_close")
  public static function sparse_solver_close(solver:QSparseSolver):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_compute")
  public static function sparse_solver_compute(ctx:QContext, solver:QSparseSolver, matrix:QSparseMatrix):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_info")
  public static function sparse_solver_info(ctx:QContext, solver:QSparseSolver):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_solve_f32")
  public static function sparse_solver_solve_f32(ctx:QContext, solver:QSparseSolver, matrix:QSparseMatrix, b:QNdarray, x:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_solver_solve_f64")
  public static function sparse_solver_solve_f64(ctx:QContext, solver:QSparseSolver, matrix:QSparseMatrix, b:QNdarray, x:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_cg_solve_f32")
  public static function sparse_cg_solve_f32(ctx:QContext, matrix:QSparseMatrix, b:QNdarray, x:QNdarray, maxIterations:Int, tolerance:Float):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "sparse_cg_solve_f64")
  public static function sparse_cg_solve_f64(ctx:QContext, matrix:QSparseMatrix, b:QNdarray, x:QNdarray, maxIterations:Int, tolerance:Float):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "mesh_relation_create")
  public static function mesh_relation_create(ctx:QContext,
      fromType:Int,
      toType:Int,
      counts:hl.NativeArray<Int>,
      ownedOffsets:hl.NativeArray<Int>,
      totalOffsets:hl.NativeArray<Int>,
      valueSNodeId:Int,
      offsetSNodeId:Int,
      patchOffsetSNodeId:Int,
      fixed:Int,
      fixedDegree:Int):QMeshRelation {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "mesh_relation_close")
  public static function mesh_relation_close(relation:QMeshRelation):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_create")
  public static function ndarray_create(ctx:QContext, dtype:Int, shape:hl.NativeArray<Int>):QNdarray {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_import_dlpack")
  public static function ndarray_import_dlpack(ctx:QContext, dtype:Int, handle:haxe.Int64):QNdarray {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_import_external_pointer")
  public static function ndarray_import_external_pointer(ctx:QContext, pointer:haxe.Int64, dtype:Int, shape:hl.NativeArray<Int>):QNdarray {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "cuda_gl_interop_available")
  public static function cuda_gl_interop_available(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "cuda_gl_register_buffer")
  public static function cuda_gl_register_buffer(ctx:QContext, buffer:Dynamic, byteSize:Int):QCudaGlResource {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "cuda_gl_map")
  public static function cuda_gl_map(ctx:QContext, resource:QCudaGlResource):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "cuda_gl_unmap")
  public static function cuda_gl_unmap(ctx:QContext, resource:QCudaGlResource):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "cuda_gl_unregister")
  public static function cuda_gl_unregister(resource:QCudaGlResource):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_close")
  public static function ndarray_close(arr:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }
  @:hlNative("quadrants", "ndarray_clear_autodiff_handles")
  public static function ndarray_clear_autodiff_handles(arr:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_set_grad_handle")
  public static function ndarray_set_grad_handle(arr:QNdarray, grad:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_set_dual_handle")
  public static function ndarray_set_dual_handle(arr:QNdarray, dual:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }


  @:hlNative("quadrants", "ndarray_fill_i8")
  public static function ndarray_fill_i8(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i8")
  public static function ndarray_read_i8(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i8")
  public static function ndarray_write_i8(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i16")
  public static function ndarray_fill_i16(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i16")
  public static function ndarray_read_i16(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i16")
  public static function ndarray_write_i16(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i32")
  public static function ndarray_fill_i32(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i32")
  public static function ndarray_read_i32(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i32")
  public static function ndarray_write_i32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_i64")
  public static function ndarray_fill_i64(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_i64")
  public static function ndarray_read_i64(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_i64")
  public static function ndarray_write_i64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u8")
  public static function ndarray_fill_u8(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u8")
  public static function ndarray_read_u8(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u8")
  public static function ndarray_write_u8(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u16")
  public static function ndarray_fill_u16(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u16")
  public static function ndarray_read_u16(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u16")
  public static function ndarray_write_u16(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u32")
  public static function ndarray_fill_u32(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u32")
  public static function ndarray_read_u32(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u32")
  public static function ndarray_write_u32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u64")
  public static function ndarray_fill_u64(ctx:QContext, arr:QNdarray, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u64")
  public static function ndarray_read_u64(ctx:QContext, arr:QNdarray, flatIndex:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u64")
  public static function ndarray_write_u64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_u1")
  public static function ndarray_fill_u1(ctx:QContext, arr:QNdarray, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_u1")
  public static function ndarray_read_u1(ctx:QContext, arr:QNdarray, flatIndex:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_u1")
  public static function ndarray_write_u1(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_f32")
  public static function ndarray_fill_f32(ctx:QContext, arr:QNdarray, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_f16")
  public static function ndarray_fill_f16(ctx:QContext, arr:QNdarray, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_bytes")
  public static function ndarray_read_bytes(ctx:QContext, arr:QNdarray, dtype:Int, flatStart:Int, count:Int, out:hl.Bytes, outByteOffset:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_bytes")
  public static function ndarray_write_bytes(ctx:QContext, arr:QNdarray, dtype:Int, flatStart:Int, count:Int, input:hl.Bytes, inputByteOffset:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f32")
  public static function ndarray_read_f32(ctx:QContext, arr:QNdarray, flatIndex:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f32_bytes")
  public static function ndarray_read_f32_bytes(ctx:QContext, arr:QNdarray, flatStart:Int, count:Int, out:hl.Bytes, outByteOffset:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_f32")
  public static function ndarray_write_f32(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f16")
  public static function ndarray_read_f16(ctx:QContext, arr:QNdarray, flatIndex:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_f16")
  public static function ndarray_write_f16(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_fill_f64")
  public static function ndarray_fill_f64(ctx:QContext, arr:QNdarray, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_read_f64")
  public static function ndarray_read_f64(ctx:QContext, arr:QNdarray, flatIndex:Int):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_write_f64")
  public static function ndarray_write_f64(ctx:QContext, arr:QNdarray, flatIndex:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_supports_zero_copy")
  public static function ndarray_supports_zero_copy(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_supports_external_pointer_import")
  public static function ndarray_supports_external_pointer_import(ctx:QContext):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_export_device_pointer")
  public static function ndarray_export_device_pointer(ctx:QContext, arr:QNdarray):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "ndarray_export_dlpack")
  public static function ndarray_export_dlpack(ctx:QContext, arr:QNdarray):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_release")
  public static function dlpack_release(handle:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_device_type")
  public static function dlpack_device_type(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_device_id")
  public static function dlpack_device_id(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_dtype_code")
  public static function dlpack_dtype_code(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_dtype_bits")
  public static function dlpack_dtype_bits(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_dtype_lanes")
  public static function dlpack_dtype_lanes(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_ndim")
  public static function dlpack_ndim(handle:haxe.Int64):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_shape")
  public static function dlpack_shape(handle:haxe.Int64, axis:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_stride")
  public static function dlpack_stride(handle:haxe.Int64, axis:Int):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "dlpack_data_pointer")
  public static function dlpack_data_pointer(handle:haxe.Int64):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_create")
  public static function snode_tree_create(ctx:QContext):QSNodeTree {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_root_id")
  public static function snode_tree_root_id(tree:QSNodeTree):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_child")
  public static function snode_tree_child(tree:QSNodeTree, parentSNodeId:Int, snodeType:Int, axes:hl.NativeArray<Int>, sizes:hl.NativeArray<Int>, chunkSize:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_bit_struct_quant_child")
  public static function snode_tree_bit_struct_quant_child(tree:QSNodeTree,
      parentSNodeId:Int,
      computeDType:Int,
      quantKind:Int,
      bits:Int,
      signed:Int,
      fractionalBits:Int,
      exponentBits:Int,
      fractionBits:Int,
      scale:Float,
      maxBits:Int):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_place")
  public static function snode_tree_place(tree:QSNodeTree, parentSNodeId:Int, dtype:Int, name:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_place_with_offset")
  public static function snode_tree_place_with_offset(tree:QSNodeTree, parentSNodeId:Int, dtype:Int, offsets:hl.NativeArray<Int>, name:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_place_quant")
  public static function snode_tree_place_quant(tree:QSNodeTree,
      parentSNodeId:Int,
      computeDType:Int,
      quantKind:Int,
      bits:Int,
      signed:Int,
      fractionalBits:Int,
      exponentBits:Int,
      fractionBits:Int,
      scale:Float,
      name:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_place_quant_with_offset")
  public static function snode_tree_place_quant_with_offset(tree:QSNodeTree,
      parentSNodeId:Int,
      computeDType:Int,
      quantKind:Int,
      bits:Int,
      signed:Int,
      fractionalBits:Int,
      exponentBits:Int,
      fractionBits:Int,
      scale:Float,
      offsets:hl.NativeArray<Int>,
      name:hl.Bytes):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_commit")
  public static function snode_tree_commit(ctx:QContext, tree:QSNodeTree):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_tree_close")
  public static function snode_tree_close(tree:QSNodeTree):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_i8")
  public static function snode_read_i8(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_i8")
  public static function snode_write_i8(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_i16")
  public static function snode_read_i16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_i16")
  public static function snode_write_i16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_i32")
  public static function snode_read_i32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_i32")
  public static function snode_write_i32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_i64")
  public static function snode_read_i64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_i64")
  public static function snode_write_i64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_u8")
  public static function snode_read_u8(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_u8")
  public static function snode_write_u8(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_u16")
  public static function snode_read_u16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_u16")
  public static function snode_write_u16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_u32")
  public static function snode_read_u32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_u32")
  public static function snode_write_u32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_u64")
  public static function snode_read_u64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):haxe.Int64 {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_u64")
  public static function snode_write_u64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_u1")
  public static function snode_read_u1(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Int {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_u1")
  public static function snode_write_u1(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_f32")
  public static function snode_read_f32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_f32")
  public static function snode_write_f32(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_f16")
  public static function snode_read_f16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_f16")
  public static function snode_write_f16(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_read_f64")
  public static function snode_read_f64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>):Float {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_write_f64")
  public static function snode_write_f64(ctx:QContext, snodeId:Int, indices:hl.NativeArray<Int>, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_i8")
  public static function snode_fill_i8(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_i16")
  public static function snode_fill_i16(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_i32")
  public static function snode_fill_i32(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_i64")
  public static function snode_fill_i64(ctx:QContext, snodeId:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_u8")
  public static function snode_fill_u8(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_u16")
  public static function snode_fill_u16(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_u32")
  public static function snode_fill_u32(ctx:QContext, snodeId:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_u64")
  public static function snode_fill_u64(ctx:QContext, snodeId:Int, value:haxe.Int64):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_u1")
  public static function snode_fill_u1(ctx:QContext, snodeId:Int, value:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_f16")
  public static function snode_fill_f16(ctx:QContext, snodeId:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_f32")
  public static function snode_fill_f32(ctx:QContext, snodeId:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_fill_f64")
  public static function snode_fill_f64(ctx:QContext, snodeId:Int, value:Float):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_copy_to_ndarray")
  public static function snode_copy_to_ndarray(ctx:QContext, snodeId:Int, dtype:Int, arr:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_copy_from_ndarray")
  public static function snode_copy_from_ndarray(ctx:QContext, snodeId:Int, dtype:Int, arr:QNdarray):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_register_adjoint")
  public static function snode_register_adjoint(ctx:QContext, primalSnodeId:Int, adjointSnodeId:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "snode_register_dual")
  public static function snode_register_dual(ctx:QContext, primalSnodeId:Int, dualSnodeId:Int):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }
  @:hlNative("quadrants", "kernel_compile")
  public static function kernel_compile(ctx:QContext, descriptor:hl.Bytes, length:Int, autodiffMode:Int):QKernel {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch")
  public static function kernel_launch(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_specialized")
  public static function kernel_launch_specialized(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_on")
  public static function kernel_launch_on(ctx:QContext, kernel:QKernel, stream:QStream, args:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_on_specialized")
  public static function kernel_launch_on_specialized(ctx:QContext, kernel:QKernel, stream:QStream, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_graph")
  public static function kernel_launch_graph(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_graph_specialized")
  public static function kernel_launch_graph_specialized(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_graph_do_while")
  public static function kernel_launch_graph_do_while(ctx:QContext, kernel:QKernel, controlArgId:Int, args:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_graph_do_while_specialized")
  public static function kernel_launch_graph_do_while_specialized(ctx:QContext, kernel:QKernel, controlArgId:Int, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_ret")
  public static function kernel_launch_ret(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>):Dynamic {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_ret_specialized")
  public static function kernel_launch_ret_specialized(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):Dynamic {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_rets")
  public static function kernel_launch_rets(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>):hl.NativeArray<Dynamic> {
    throw "Quadrants HashLink native bridge is not loaded";
  }

  @:hlNative("quadrants", "kernel_launch_rets_specialized")
  public static function kernel_launch_rets_specialized(ctx:QContext, kernel:QKernel, args:hl.NativeArray<Dynamic>, specs:hl.NativeArray<Dynamic>):hl.NativeArray<Dynamic> {
    throw "Quadrants HashLink native bridge is not loaded";
  }


  @:hlNative("quadrants", "kernel_close")
  public static function kernel_close(kernel:QKernel):Void {
    throw "Quadrants HashLink native bridge is not loaded";
  }
}
