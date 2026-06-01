#pragma once

#define HL_NAME(n) quadrants_##n
#include <hl.h>

#define _QD_CONTEXT _ABSTRACT(qd_context)
#define _QD_KERNEL _ABSTRACT(qd_kernel)
#define _QD_NDARRAY _ABSTRACT(qd_ndarray)
#define _QD_STREAM _ABSTRACT(qd_stream)
#define _QD_EVENT _ABSTRACT(qd_event)
#define _QD_SNODE_TREE _ABSTRACT(qd_snode_tree)
#define _QD_CUDA_GL_RESOURCE _ABSTRACT(qd_cuda_gl_resource)

struct qd_context;
struct qd_kernel;
struct qd_ndarray;
struct qd_stream;
struct qd_event;
struct qd_snode_tree;
struct qd_cuda_gl_resource;

HL_PRIM void HL_NAME(runtime_set_lib_dir)(vbyte *path);
HL_PRIM qd_context *HL_NAME(context_create)(int arch);
HL_PRIM qd_context *HL_NAME(context_create_configured)(int arch, int enable_profiler);
HL_PRIM void HL_NAME(context_sync)(qd_context *ctx);
HL_PRIM void HL_NAME(context_close)(qd_context *ctx);
HL_PRIM qd_stream *HL_NAME(stream_create)(qd_context *ctx);
HL_PRIM int HL_NAME(stream_supports_events)(qd_context *ctx);
HL_PRIM qd_event *HL_NAME(stream_event_create)(qd_context *ctx);
HL_PRIM void HL_NAME(stream_event_record)(qd_context *ctx, qd_event *event, qd_stream *stream);
HL_PRIM void HL_NAME(stream_event_sync)(qd_context *ctx, qd_event *event);
HL_PRIM void HL_NAME(stream_wait_event)(qd_context *ctx, qd_stream *stream, qd_event *event);
HL_PRIM void HL_NAME(stream_event_close)(qd_event *event);
HL_PRIM void HL_NAME(stream_sync)(qd_context *ctx, qd_stream *stream);
HL_PRIM void HL_NAME(stream_close)(qd_stream *stream);
HL_PRIM void HL_NAME(context_set_offline_cache)(qd_context *ctx, int enabled, vbyte *path);
HL_PRIM void HL_NAME(context_set_adstack_config)(qd_context *ctx, int experimental_enabled, int stack_size, int sparse_threshold_bytes);
HL_PRIM void HL_NAME(context_set_debug_dump)(qd_context *ctx, vbyte *path, int print_ir, int print_preprocessed_ir, int print_ir_debug_info);
HL_PRIM void HL_NAME(context_set_random_seed)(qd_context *ctx, int seed);
HL_PRIM void HL_NAME(context_set_cpu_max_num_threads)(qd_context *ctx, int thread_count);
HL_PRIM void HL_NAME(context_set_fast_math)(qd_context *ctx, int enabled);
HL_PRIM void HL_NAME(context_set_bounds_check)(qd_context *ctx, int enabled);
HL_PRIM void HL_NAME(profiler_start)(qd_context *ctx, vbyte *kernel_name);
HL_PRIM void HL_NAME(profiler_stop)(qd_context *ctx);
HL_PRIM void HL_NAME(profiler_clear)(qd_context *ctx);
HL_PRIM double HL_NAME(profiler_total_time)(qd_context *ctx);
HL_PRIM int HL_NAME(profiler_query_count)(qd_context *ctx, vbyte *kernel_name);
HL_PRIM double HL_NAME(profiler_query_min)(qd_context *ctx, vbyte *kernel_name);
HL_PRIM double HL_NAME(profiler_query_max)(qd_context *ctx, vbyte *kernel_name);
HL_PRIM double HL_NAME(profiler_query_avg)(qd_context *ctx, vbyte *kernel_name);

HL_PRIM qd_ndarray *HL_NAME(ndarray_create)(qd_context *ctx, int dtype, varray *shape);
HL_PRIM qd_ndarray *HL_NAME(ndarray_import_dlpack)(qd_context *ctx, int dtype, int64 handle);
HL_PRIM qd_ndarray *HL_NAME(ndarray_import_external_pointer)(qd_context *ctx, int64 pointer, int dtype, varray *shape);
HL_PRIM int HL_NAME(cuda_gl_interop_available)(qd_context *ctx);
HL_PRIM qd_cuda_gl_resource *HL_NAME(cuda_gl_register_buffer)(qd_context *ctx, vdynamic *buffer, int byte_size);
HL_PRIM int64 HL_NAME(cuda_gl_map)(qd_context *ctx, qd_cuda_gl_resource *resource);
HL_PRIM void HL_NAME(cuda_gl_unmap)(qd_context *ctx, qd_cuda_gl_resource *resource);
HL_PRIM void HL_NAME(cuda_gl_unregister)(qd_cuda_gl_resource *resource);
HL_PRIM void HL_NAME(ndarray_close)(qd_ndarray *arr);
HL_PRIM void HL_NAME(ndarray_fill_i8)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_i8)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_i8)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_i16)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_i16)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_i16)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_i32)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_i32)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_i32)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_i64)(qd_context *ctx, qd_ndarray *arr, int64 value);
HL_PRIM int64 HL_NAME(ndarray_read_i64)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_i64)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value);
HL_PRIM void HL_NAME(ndarray_fill_u8)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_u8)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_u8)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_u16)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_u16)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_u16)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_u32)(qd_context *ctx, qd_ndarray *arr, int64 value);
HL_PRIM int64 HL_NAME(ndarray_read_u32)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_u32)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value);
HL_PRIM void HL_NAME(ndarray_fill_u64)(qd_context *ctx, qd_ndarray *arr, int64 value);
HL_PRIM int64 HL_NAME(ndarray_read_u64)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_u64)(qd_context *ctx, qd_ndarray *arr, int flat_index, int64 value);
HL_PRIM void HL_NAME(ndarray_fill_u1)(qd_context *ctx, qd_ndarray *arr, int value);
HL_PRIM int HL_NAME(ndarray_read_u1)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_u1)(qd_context *ctx, qd_ndarray *arr, int flat_index, int value);
HL_PRIM void HL_NAME(ndarray_fill_f32)(qd_context *ctx, qd_ndarray *arr, double value);
HL_PRIM void HL_NAME(ndarray_fill_f16)(qd_context *ctx, qd_ndarray *arr, double value);
HL_PRIM void HL_NAME(ndarray_read_bytes)(qd_context *ctx,
                                         qd_ndarray *arr,
                                         int dtype,
                                         int flat_start,
                                         int count,
                                         vbyte *out,
                                         int out_byte_offset);
HL_PRIM void HL_NAME(ndarray_write_bytes)(qd_context *ctx,
                                          qd_ndarray *arr,
                                          int dtype,
                                          int flat_start,
                                          int count,
                                          vbyte *input,
                                          int input_byte_offset);
HL_PRIM double HL_NAME(ndarray_read_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_read_f32_bytes)(qd_context *ctx,
                                             qd_ndarray *arr,
                                             int flat_start,
                                             int count,
                                             vbyte *out,
                                             int out_byte_offset);
HL_PRIM void HL_NAME(ndarray_write_f32)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value);
HL_PRIM double HL_NAME(ndarray_read_f16)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_f16)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value);
HL_PRIM void HL_NAME(ndarray_fill_f64)(qd_context *ctx, qd_ndarray *arr, double value);
HL_PRIM double HL_NAME(ndarray_read_f64)(qd_context *ctx, qd_ndarray *arr, int flat_index);
HL_PRIM void HL_NAME(ndarray_write_f64)(qd_context *ctx, qd_ndarray *arr, int flat_index, double value);

HL_PRIM int HL_NAME(ndarray_supports_zero_copy)(qd_context *ctx);
HL_PRIM int HL_NAME(ndarray_supports_external_pointer_import)(qd_context *ctx);
HL_PRIM int64 HL_NAME(ndarray_export_device_pointer)(qd_context *ctx, qd_ndarray *arr);
HL_PRIM int64 HL_NAME(ndarray_export_dlpack)(qd_context *ctx, qd_ndarray *arr);
HL_PRIM void HL_NAME(dlpack_release)(int64 handle);
HL_PRIM int HL_NAME(dlpack_device_type)(int64 handle);
HL_PRIM int HL_NAME(dlpack_device_id)(int64 handle);
HL_PRIM int HL_NAME(dlpack_dtype_code)(int64 handle);
HL_PRIM int HL_NAME(dlpack_dtype_bits)(int64 handle);
HL_PRIM int HL_NAME(dlpack_dtype_lanes)(int64 handle);
HL_PRIM int HL_NAME(dlpack_ndim)(int64 handle);
HL_PRIM int64 HL_NAME(dlpack_shape)(int64 handle, int axis);
HL_PRIM int64 HL_NAME(dlpack_stride)(int64 handle, int axis);
HL_PRIM int64 HL_NAME(dlpack_data_pointer)(int64 handle);

HL_PRIM qd_snode_tree *HL_NAME(snode_tree_create)(qd_context *ctx);
HL_PRIM int HL_NAME(snode_tree_root_id)(qd_snode_tree *tree);
HL_PRIM int HL_NAME(snode_tree_child)(qd_snode_tree *tree,
                                      int parent_snode_id,
                                      int snode_type,
                                      varray *axes,
                                      varray *sizes,
                                      int chunk_size);
HL_PRIM int HL_NAME(snode_tree_place)(qd_snode_tree *tree, int parent_snode_id, int dtype, vbyte *name);
HL_PRIM int HL_NAME(snode_tree_commit)(qd_context *ctx, qd_snode_tree *tree);
HL_PRIM void HL_NAME(snode_tree_close)(qd_snode_tree *tree);
HL_PRIM int HL_NAME(snode_read_i8)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_i8)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM int HL_NAME(snode_read_i16)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_i16)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM int HL_NAME(snode_read_i32)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_i32)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM int64 HL_NAME(snode_read_i64)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_i64)(qd_context *ctx, int snode_id, varray *indices, int64 value);
HL_PRIM int HL_NAME(snode_read_u8)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_u8)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM int HL_NAME(snode_read_u16)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_u16)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM int64 HL_NAME(snode_read_u32)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_u32)(qd_context *ctx, int snode_id, varray *indices, int64 value);
HL_PRIM int64 HL_NAME(snode_read_u64)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_u64)(qd_context *ctx, int snode_id, varray *indices, int64 value);
HL_PRIM int HL_NAME(snode_read_u1)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_u1)(qd_context *ctx, int snode_id, varray *indices, int value);
HL_PRIM double HL_NAME(snode_read_f32)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_f32)(qd_context *ctx, int snode_id, varray *indices, double value);
HL_PRIM double HL_NAME(snode_read_f16)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_f16)(qd_context *ctx, int snode_id, varray *indices, double value);
HL_PRIM double HL_NAME(snode_read_f64)(qd_context *ctx, int snode_id, varray *indices);
HL_PRIM void HL_NAME(snode_write_f64)(qd_context *ctx, int snode_id, varray *indices, double value);
HL_PRIM void HL_NAME(snode_fill_i8)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_i16)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_i32)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_i64)(qd_context *ctx, int snode_id, int64 value);
HL_PRIM void HL_NAME(snode_fill_u8)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_u16)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_u32)(qd_context *ctx, int snode_id, int64 value);
HL_PRIM void HL_NAME(snode_fill_u64)(qd_context *ctx, int snode_id, int64 value);
HL_PRIM void HL_NAME(snode_fill_u1)(qd_context *ctx, int snode_id, int value);
HL_PRIM void HL_NAME(snode_fill_f16)(qd_context *ctx, int snode_id, double value);
HL_PRIM void HL_NAME(snode_fill_f32)(qd_context *ctx, int snode_id, double value);
HL_PRIM void HL_NAME(snode_fill_f64)(qd_context *ctx, int snode_id, double value);
HL_PRIM void HL_NAME(snode_copy_to_ndarray)(qd_context *ctx, int snode_id, int dtype, qd_ndarray *arr);
HL_PRIM void HL_NAME(snode_copy_from_ndarray)(qd_context *ctx, int snode_id, int dtype, qd_ndarray *arr);

HL_PRIM qd_kernel *HL_NAME(kernel_compile)(qd_context *ctx, vbyte *descriptor, int descriptor_length, int autodiff_mode);
HL_PRIM void HL_NAME(kernel_launch)(qd_context *ctx, qd_kernel *kernel, varray *args);
HL_PRIM void HL_NAME(kernel_launch_on)(qd_context *ctx, qd_kernel *kernel, qd_stream *stream, varray *args);
HL_PRIM void HL_NAME(kernel_launch_graph)(qd_context *ctx, qd_kernel *kernel, varray *args);
HL_PRIM void HL_NAME(kernel_launch_graph_do_while)(qd_context *ctx, qd_kernel *kernel, int control_arg_id, varray *args);
HL_PRIM vdynamic *HL_NAME(kernel_launch_ret)(qd_context *ctx, qd_kernel *kernel, varray *args);
HL_PRIM varray *HL_NAME(kernel_launch_rets)(qd_context *ctx, qd_kernel *kernel, varray *args);
HL_PRIM void HL_NAME(kernel_close)(qd_kernel *kernel);
