# ./quadrants/runtime/llvm/runtime_module/CMakeLists.txt

set(QD_RUNTIME_BUILD_DIR "${CMAKE_BINARY_DIR}/runtime" CACHE PATH "Build-tree directory for Quadrants runtime bitcode")

function(COMPILE_LLVM_RUNTIME rtm_arch)
    message(STATUS "Compiling LLVM byte code file for arch ${rtm_arch}")
    # The runtime source is split across runtime.cpp + adstack_runtime.cpp + the shared header pair, but compiled as
    # a single translation unit: runtime.cpp `#include`s adstack_runtime.cpp once near its tail. A real two-TU build
    # via `llvm-link` would collapse structurally identical named struct types (`RootMeta` / `DenseMeta` /
    # `DynamicMeta`, `BitmaskedMeta` / `PointerMeta`) under a single name, which then breaks the host-side
    # `QuadrantsLLVMContext::get_runtime_type` lookup by name. The single-TU compile sidesteps the LLVM `IRMover`
    # type-uniquing path entirely and matches the existing `node_*.h` / `internal_functions.h` / `locked_task.h`
    # pattern in this directory.
    #
    # -mno-outline-atomics: runtime.cpp is compiled to bitcode (.bc) that is later JIT-compiled by the ORC JIT linker
    # at runtime. On AArch64, clang's default -moutline-atomics emits calls to helpers like __aarch64_ldadd4_acq_rel
    # (normally provided by libgcc/compiler-rt), but the ORC JIT environment has no access to those libraries and fails
    # with "Symbols not found". This flag forces clang to emit inline LL/SC atomic sequences directly in the bitcode
    # instead. It is a no-op on x86 and irrelevant for CUDA/GPU paths. The alternative (registering those symbols with
    # the JIT linker) would be far more complex and fragile.
    set(_runtime_output "${QD_RUNTIME_BUILD_DIR}/runtime_${rtm_arch}.bc")
    add_custom_target(
        "generate_llvm_runtime_${rtm_arch}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${QD_RUNTIME_BUILD_DIR}"
        COMMAND ${CLANG_EXECUTABLE} ${CLANG_OSX_FLAGS} -c runtime.cpp -o "${_runtime_output}" -fno-exceptions -emit-llvm -std=c++17 -mno-outline-atomics -D "ARCH_${rtm_arch}" -I ${PROJECT_SOURCE_DIR}
        BYPRODUCTS "${_runtime_output}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    add_dependencies(${CORE_LIBRARY_NAME} "generate_llvm_runtime_${rtm_arch}")
    install(FILES "${_runtime_output}"
            DESTINATION ${QD_RUNTIME_INSTALL_DIR}
            COMPONENT runtime)

endfunction()

function(COMPILE_CUSTOM_CUDA_LIBRARY cuda_path)
    set(_cuda_runtime_output "${QD_RUNTIME_BUILD_DIR}/cuda_runtime-cuda-nvptx64-nvidia-cuda-sm_60.bc")
    add_custom_target(
        "generate_cuda_library"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${QD_RUNTIME_BUILD_DIR}"
        COMMAND ${CLANG_EXECUTABLE} -c cuda_runtime.cu -o "${_cuda_runtime_output}" --cuda-gpu-arch=sm_60 -emit-llvm -std=c++17 --no-cuda-version-check -nocudalib --cuda-path=${cuda_path}
        BYPRODUCTS "${_cuda_runtime_output}"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    )
    add_dependencies(${CORE_LIBRARY_NAME} "generate_cuda_library")
    install(FILES "${_cuda_runtime_output}"
            DESTINATION ${QD_RUNTIME_INSTALL_DIR}
            COMPONENT runtime)

endfunction()

# Build llvm-runtime for host arch and cuda (if available)
foreach(arch IN LISTS HOST_ARCH CUDA_ARCH AMDGPU_ARCH)
  compile_llvm_runtime(${arch})
endforeach()

# You can implement hand-written CUDA Kernels in cuda_runtime.cu and then
# uncomment the following code to compile it into .bc files

#if(CUDA_ARCH)
#    find_package(CUDAToolkit)
#    if(${CUDAToolkit_FOUND})
#      if(${CUDAToolkit_VERSION_MAJOR} GREATER_EQUAL 8)
#          compile_custom_cuda_library(${CUDAToolkit_TARGET_DIR})
#      endif()
#    endif()
#endif()
