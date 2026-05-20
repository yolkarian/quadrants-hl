option(USE_STDCPP "Use -stdlib=libc++" OFF)
option(QD_WITH_LLVM "Build with LLVM backends" ON)
option(QD_WITH_METAL "Build with the Metal backend" ON)
option(QD_WITH_CUDA "Build with the CUDA backend" ON)
option(QD_WITH_CUDA_TOOLKIT "Build with the CUDA toolkit" OFF)
option(QD_WITH_AMDGPU "Build with the AMDGPU backend" OFF)
option(QD_WITH_VULKAN "Build with the Vulkan backend" OFF)

# Force symbols to be 'hidden' by default so nothing is exported from the Quadrants
# library including the third-party dependencies.
# As Quadrants can be used by external projects, some of the internal dependencies
# such as Vulkan, etc. could be in conflict with the dependencies of those
# projects.
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
# Suppress warnings from submodules introduced by the above symbol visibility change
set(CMAKE_POLICY_DEFAULT_CMP0063 NEW)
set(CMAKE_POLICY_DEFAULT_CMP0077 NEW)
set(QD_RUNTIME_BUILD_DIR "${CMAKE_BINARY_DIR}/runtime" CACHE PATH "Build-tree directory for Quadrants runtime bitcode")
set(QD_RUNTIME_INSTALL_DIR "share/quadrants/runtime" CACHE PATH "Quadrants runtime bitcode install directory")
set(QD_ROCM_RUNTIME_INSTALL_DIR "share/quadrants/runtime_rocm70" CACHE PATH "Quadrants ROCm runtime bitcode install directory")

if (QD_WITH_AMDGPU AND QD_WITH_CUDA)
    message(WARNING "Compiling CUDA and AMDGPU backends simultaneously")
endif()

if(UNIX AND NOT APPLE)
    # Handy helper for Linux
    # https://stackoverflow.com/a/32259072/12003165
    set(LINUX TRUE)
endif()

if (APPLE)
    if (QD_WITH_CUDA)
        set(QD_WITH_CUDA OFF)
        message(WARNING "CUDA backend not supported on OS X. Setting QD_WITH_CUDA to OFF.")
    endif()
    if (QD_WITH_AMDGPU)
        set(QD_WITH_AMDGPU OFF)
        message(WARNING "AMDGPU backend not supported on OS X. Setting QD_WITH_AMDGPU to OFF.")
    endif()
else()
    if (QD_WITH_METAL)
        set(QD_WITH_METAL OFF)
        message(WARNING "Metal backend only supported on OS X. Setting QD_WITH_METAL to OFF.")
    endif()
endif()

if (WIN32)
    if (QD_WITH_AMDGPU)
        set(QD_WITH_AMDGPU OFF)
        message(WARNING "AMDGPU backend not supported on Windows. Setting QD_WITH_AMDGPU to OFF.")
    endif()
endif()

if(QD_WITH_VULKAN)
    set(QD_WITH_GGUI ON)
endif()

if(NOT QD_WITH_LLVM)
    set(QD_WITH_CUDA OFF)
    set(QD_WITH_CUDA_TOOLKIT OFF)
endif()

file(GLOB QUADRANTS_CORE_SOURCE
    "quadrants/analysis/*.cpp" "quadrants/analysis/*.h"
    "quadrants/ir/*"
    "quadrants/jit/*"
    "quadrants/math/*"
    "quadrants/program/*"
    "quadrants/program/adstack/*"
    "quadrants/struct/*"
    "quadrants/system/*"
    "quadrants/transforms/*"
    "quadrants/transforms/auto_diff/*"
    "quadrants/platform/cuda/*" "quadrants/platform/amdgpu/*"
    "quadrants/platform/mac/*" "quadrants/platform/windows/*"
    "quadrants/codegen/*.cpp" "quadrants/codegen/*.h"
    "quadrants/runtime/*.h" "quadrants/runtime/*.cpp"
)

if(QD_WITH_LLVM)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_LLVM")
endif()

if (QD_WITH_CUDA)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_CUDA")
  file(GLOB QUADRANTS_CUDA_RUNTIME_SOURCE "quadrants/runtime/cuda/runtime.cpp")
  list(APPEND QUADRANTS_CORE_SOURCE ${QUADRANTS_CUDA_RUNTIME_SOURCE})
endif()

if (QD_WITH_AMDGPU)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_AMDGPU")
  file(GLOB QUADRANTS_AMDGPU_RUNTIME_SOURCE "quadrants/runtime/amdgpu/runtime.cpp")
  list(APPEND TAIHI_CORE_SOURCE ${QUADRANTS_AMDGPU_RUNTIME_SOURCE})
endif()

if (QD_WITH_METAL)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_METAL")
endif()

if (QD_WITH_VULKAN)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_VULKAN")
endif ()

add_subdirectory(quadrants/rhi)

set(CORE_LIBRARY_NAME quadrants_core)
add_library(${CORE_LIBRARY_NAME} OBJECT ${QUADRANTS_CORE_SOURCE})

target_include_directories(${CORE_LIBRARY_NAME} PRIVATE ${CMAKE_SOURCE_DIR})
target_include_directories(${CORE_LIBRARY_NAME} PRIVATE external/include)
target_include_directories(${CORE_LIBRARY_NAME} PRIVATE external/SPIRV-Tools/include)
target_include_directories(${CORE_LIBRARY_NAME} PRIVATE external/PicoSHA2)
target_include_directories(${CORE_LIBRARY_NAME} PRIVATE external/eigen)
target_include_directories(${CORE_LIBRARY_NAME} PRIVATE external/FP16/include)

target_link_libraries(${CORE_LIBRARY_NAME} PUBLIC ti_device_api)

if(QD_WITH_LLVM)
    if(DEFINED ENV{LLVM_DIR})
        set(LLVM_DIR $ENV{LLVM_DIR})
        message("Getting LLVM_DIR=${LLVM_DIR} from the environment variable")
    endif()

    # http://llvm.org/docs/CMake.html#embedding-llvm-in-your-project
    set(QD_MIN_LLVM_VERSION "22.0")
    find_package(LLVM REQUIRED CONFIG)
    message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
    if("${LLVM_PACKAGE_VERSION}" VERSION_LESS "${QD_MIN_LLVM_VERSION}")
        message(FATAL_ERROR "LLVM version < ${QD_MIN_LLVM_VERSION} is not supported")
    endif()
    message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
    target_include_directories(${CORE_LIBRARY_NAME} PUBLIC ${LLVM_INCLUDE_DIRS})

    message("LLVM include dirs ${LLVM_INCLUDE_DIRS}")
    message("LLVM library dirs ${LLVM_LIBRARY_DIRS}")
    add_definitions(${LLVM_DEFINITIONS})

    llvm_map_components_to_libnames(llvm_libs
            Core
            ExecutionEngine
            InstCombine
            OrcJIT
            RuntimeDyld
            TransformUtils
            BitReader
            BitWriter
            Object
            ScalarOpts
            Support
            native
            Linker
            Target
            MC
            Passes
            ipo
            Analysis
            )

    if (APPLE AND "${CMAKE_SYSTEM_PROCESSOR}" STREQUAL "arm64")
        llvm_map_components_to_libnames(llvm_aarch64_libs AArch64)
    endif()

    add_subdirectory(quadrants/codegen/cpu)
    add_subdirectory(quadrants/runtime/cpu)

    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE cpu_codegen)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE cpu_runtime)

    if (QD_WITH_CUDA)
        llvm_map_components_to_libnames(llvm_ptx_libs NVPTX)
        add_subdirectory(quadrants/codegen/cuda)
        add_subdirectory(quadrants/runtime/cuda)

        target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE cuda_codegen)
        target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE cuda_runtime)
    endif()

    if (QD_WITH_AMDGPU)
        llvm_map_components_to_libnames(llvm_amdgpu_libs AMDGPU)
        add_subdirectory(quadrants/codegen/amdgpu)
        add_subdirectory(quadrants/runtime/amdgpu)

        target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE amdgpu_codegen)
        target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE amdgpu_runtime)
    endif()

    add_subdirectory(quadrants/codegen/llvm)
    add_subdirectory(quadrants/runtime/llvm)
    add_subdirectory(quadrants/runtime/program_impls/llvm)

    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE llvm_program_impl)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE llvm_codegen)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE llvm_runtime)

    if (LINUX)
        # Remove symbols from llvm static libs
        foreach(LETTER ${llvm_libs})
            target_link_options(${CORE_LIBRARY_NAME} PUBLIC -Wl,--exclude-libs=lib${LETTER}.a)
        endforeach()
    endif()
endif()

if (QD_WITH_METAL OR QD_WITH_VULKAN)
    add_subdirectory(quadrants/runtime/program_impls/gfx)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE gfx_program_impl)
endif()

if (QD_WITH_METAL)
    add_subdirectory(quadrants/runtime/program_impls/metal)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE metal_program_impl)
endif()

if (QD_WITH_VULKAN)
    add_subdirectory(quadrants/runtime/program_impls/vulkan)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE vulkan_program_impl)
endif ()

add_subdirectory(quadrants/util)
add_subdirectory(quadrants/common)
add_subdirectory(quadrants/compilation_manager)

target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE compilation_manager)
target_link_libraries(${CORE_LIBRARY_NAME} PUBLIC quadrants_util)
target_link_libraries(${CORE_LIBRARY_NAME} PUBLIC quadrants_common)

if (QD_WITH_CUDA AND QD_WITH_CUDA_TOOLKIT)
    find_package(CUDAToolkit REQUIRED)
    message(STATUS "Found CUDAToolkit ${CUDAToolkit_VERSION}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQD_WITH_CUDA_TOOLKIT")
    target_include_directories(${CORE_LIBRARY_NAME} PUBLIC ${CUDAToolkit_INCLUDE_DIRS})
    target_link_libraries(${CORE_LIBRARY_NAME} PUBLIC CUDA::cupti)
endif()

if (QD_WITH_VULKAN OR QD_WITH_METAL)
  set(SPIRV_SKIP_EXECUTABLES true)
  set(SPIRV-Headers_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/external/SPIRV-Headers)
  set(ENABLE_SPIRV_TOOLS_INSTALL OFF)
  add_subdirectory(external/SPIRV-Tools)
  add_subdirectory(quadrants/codegen/spirv)
  add_subdirectory(quadrants/runtime/gfx)

  target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE spirv_codegen)
  target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE gfx_runtime)
endif()

if (QD_WITH_METAL)
  set(SPIRV_CROSS_CLI false)
  add_subdirectory(${PROJECT_SOURCE_DIR}/external/SPIRV-Cross ${PROJECT_BINARY_DIR}/external/SPIRV-Cross)
endif()


# Optional dependencies
if (APPLE)
    set(APPLE_FRAMEWORKS "")
    find_library(Foundation NAMES Foundation REQUIRED)
    find_library(Metal NAMES Metal REQUIRED)
    list(APPEND APPLE_FRAMEWORKS ${Foundation} ${Metal})
    if (NOT IOS)
        find_library(ApplicationServices NAMES ApplicationServices REQUIRED)
        find_library(Cocoa NAMES Cocoa REQUIRED)
        list(APPEND APPLE_FRAMEWORKS ${ApplicationServices} ${Cocoa})
    endif()
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE ${APPLE_FRAMEWORKS})
endif ()

if (LINUX)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE pthread)
    if (${CMAKE_HOST_SYSTEM_PROCESSOR} STREQUAL "x86_64")
        # Avoid glibc dependencies
        if (QD_WITH_VULKAN)
            target_link_options(${CORE_LIBRARY_NAME} PRIVATE -Wl,--wrap=log2f)
        else()
            target_link_options(${CORE_LIBRARY_NAME} PRIVATE -Wl,--wrap=log2f -Wl,--wrap=exp2 -Wl,--wrap=log2 -Wl,--wrap=logf -Wl,--wrap=powf -Wl,--wrap=exp -Wl,--wrap=log -Wl,--wrap=pow)
        endif()
    endif()
elseif (WIN32)
    target_link_libraries(${CORE_LIBRARY_NAME} PRIVATE Winmm)
endif()



foreach (source IN LISTS QUADRANTS_CORE_SOURCE)
    file(RELATIVE_PATH source_rel ${CMAKE_CURRENT_LIST_DIR} ${source})
    get_filename_component(source_path "${source_rel}" PATH)
    string(REPLACE "/" "\\" source_path_msvc "${source_path}")
    source_group("${source_path_msvc}" FILES "${source}")
endforeach ()

if (NOT APPLE)
    # For more background on what is slim_libdevice.10.bc, and why version 10, not 12.8
    # See https://github.com/Genesis-Embodied-AI/quadrants/issues/166#issuecomment-3289552564
    install(FILES ${CMAKE_SOURCE_DIR}/external/cuda_libdevice/slim_libdevice.10.bc
            DESTINATION ${QD_RUNTIME_INSTALL_DIR}
            COMPONENT runtime)
endif()

if (QD_WITH_AMDGPU)
    # Install ROCm 7.0 libdevice files
    file(GLOB AMDGPU_BC_FILES_ROCM70 ${CMAKE_SOURCE_DIR}/external/amdgpu_libdevice_rocm70/*.bc)
    install(FILES ${AMDGPU_BC_FILES_ROCM70}
            DESTINATION ${QD_ROCM_RUNTIME_INSTALL_DIR}
            COMPONENT runtime)
endif()
