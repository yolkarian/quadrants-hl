cmake_minimum_required(VERSION 3.17)

if(NOT QD_HASHLINK_ROOT)
  set(QD_HASHLINK_ROOT "${PROJECT_SOURCE_DIR}/../hashlink" CACHE PATH "Path to a HashLink checkout or install")
endif()

set(QD_HASHLINK_ROOT "${QD_HASHLINK_ROOT}" CACHE PATH "Path to a HashLink checkout or install")
set(QD_HASHLINK_INSTALL_DIR "share/quadrants/hashlink" CACHE PATH "HashLink bridge install directory")
set(QD_HASHLINK_RUNTIME_INSTALL_DIR "${QD_HASHLINK_INSTALL_DIR}/runtime" CACHE PATH "HashLink runtime bitcode install directory")
set(QD_HASHLINK_ROCM_RUNTIME_INSTALL_DIR "${QD_HASHLINK_INSTALL_DIR}/runtime_rocm70" CACHE PATH "HashLink ROCm runtime bitcode install directory")
option(QD_BUILD_HASHLINK_TESTS "Register Haxe/HashLink tests with CTest" OFF)
option(QD_BUILD_HASHLINK_LEGACY_TESTS "Register pre-v3 Haxe/HashLink runtime tests" OFF)

if(NOT EXISTS "${QD_HASHLINK_ROOT}/src/hl.h")
  if(EXISTS "${QD_HASHLINK_ROOT}/include/hl.h")
    set(QD_HASHLINK_INCLUDE_DIR "${QD_HASHLINK_ROOT}/include")
  else()
    message(FATAL_ERROR "QD_HASHLINK_ROOT must point to a HashLink checkout or install containing src/hl.h or include/hl.h: ${QD_HASHLINK_ROOT}")
  endif()
else()
  set(QD_HASHLINK_INCLUDE_DIR "${QD_HASHLINK_ROOT}/src")
endif()

find_library(QD_HASHLINK_LIBRARY
  NAMES hl libhl
  PATHS
    "${QD_HASHLINK_ROOT}"
    "${QD_HASHLINK_ROOT}/build"
    "${QD_HASHLINK_ROOT}/bin"
    "${QD_HASHLINK_ROOT}/lib"
  NO_DEFAULT_PATH)

if(NOT QD_HASHLINK_LIBRARY)
  find_library(QD_HASHLINK_LIBRARY NAMES hl libhl)
endif()

if(NOT QD_HASHLINK_LIBRARY)
  message(FATAL_ERROR "Could not find HashLink libhl. Build HashLink or set QD_HASHLINK_ROOT to an install prefix.")
endif()

add_library(quadrants.hdll SHARED
  quadrants_hl.cpp
  descriptor.cpp
  descriptor_decode.cpp
  descriptor_validate.cpp
  descriptor_lower_type.cpp
  descriptor_lower_expr.cpp
  descriptor_lower_stmt.cpp
  capabilities.cpp
  quadrants_hl.h
  descriptor.h
  descriptor_internal.h)

set_target_properties(quadrants.hdll PROPERTIES
  PREFIX ""
  OUTPUT_NAME "quadrants"
  SUFFIX ".hdll"
  LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}")

target_include_directories(quadrants.hdll
  PRIVATE
    "${QD_HASHLINK_INCLUDE_DIR}"
    "${PROJECT_SOURCE_DIR}"
    "${PROJECT_SOURCE_DIR}/external/spdlog/include"
    "${PROJECT_SOURCE_DIR}/external/include"
    "${PROJECT_SOURCE_DIR}/external/eigen"
    "${PROJECT_SOURCE_DIR}/external/volk"
    "${PROJECT_SOURCE_DIR}/external/dlpack/include"
    "${PROJECT_SOURCE_DIR}/external/SPIRV-Tools/include"
    "${PROJECT_SOURCE_DIR}/external/Vulkan-Headers/include"
    "${PROJECT_SOURCE_DIR}/external/FP16/include")

target_include_directories(quadrants.hdll SYSTEM
  PRIVATE
    "${PROJECT_SOURCE_DIR}/external/VulkanMemoryAllocator/include")

target_link_libraries(quadrants.hdll PRIVATE quadrants_core "${QD_HASHLINK_LIBRARY}")

if(QD_WITH_CUDA)
  find_package(CUDAToolkit QUIET)
  if(CUDAToolkit_FOUND)
    target_compile_definitions(quadrants.hdll PRIVATE QD_HASHLINK_CUDA_GL_INTEROP)
    target_include_directories(quadrants.hdll PRIVATE ${CUDAToolkit_INCLUDE_DIRS})
    target_link_libraries(quadrants.hdll PRIVATE CUDA::cudart CUDA::cuda_driver)
  endif()
endif()

if(QD_WITH_LLVM)
  add_dependencies(quadrants.hdll "generate_llvm_runtime_${HOST_ARCH}")
  if(QD_WITH_CUDA)
    add_dependencies(quadrants.hdll generate_llvm_runtime_cuda)
  endif()
  if(QD_WITH_AMDGPU)
    add_dependencies(quadrants.hdll generate_llvm_runtime_amdgpu)
  endif()
endif()

if(LINUX)
  target_link_options(quadrants.hdll PRIVATE -Wl,--exclude-libs=ALL)
endif()

install(TARGETS quadrants.hdll
  RUNTIME DESTINATION "${QD_HASHLINK_INSTALL_DIR}"
  LIBRARY DESTINATION "${QD_HASHLINK_INSTALL_DIR}"
  COMPONENT hashlink)

install(FILES
    "${PROJECT_SOURCE_DIR}/bindings/hashlink/haxelib.json"
    "${PROJECT_SOURCE_DIR}/bindings/hashlink/README.md"
  DESTINATION "${QD_HASHLINK_INSTALL_DIR}"
  COMPONENT hashlink)

install(DIRECTORY "${PROJECT_SOURCE_DIR}/bindings/hashlink/haxe/"
  DESTINATION "${QD_HASHLINK_INSTALL_DIR}/haxe"
  COMPONENT hashlink
  FILES_MATCHING
    PATTERN "*.hx"
    PATTERN "*.hxml"
    PATTERN "*.md")

if(QD_WITH_LLVM)
  set(QD_HASHLINK_RUNTIME_FILES
    "${QD_RUNTIME_BUILD_DIR}/runtime_${HOST_ARCH}.bc")
  if(QD_WITH_CUDA)
    list(APPEND QD_HASHLINK_RUNTIME_FILES
      "${QD_RUNTIME_BUILD_DIR}/runtime_cuda.bc")
  endif()
  if(QD_WITH_AMDGPU)
    list(APPEND QD_HASHLINK_RUNTIME_FILES
      "${QD_RUNTIME_BUILD_DIR}/runtime_amdgpu.bc")
  endif()
  install(FILES ${QD_HASHLINK_RUNTIME_FILES}
    DESTINATION "${QD_HASHLINK_RUNTIME_INSTALL_DIR}"
    COMPONENT hashlink)
endif()

if(NOT APPLE)
  install(FILES "${PROJECT_SOURCE_DIR}/external/cuda_libdevice/slim_libdevice.10.bc"
    DESTINATION "${QD_HASHLINK_RUNTIME_INSTALL_DIR}"
    COMPONENT hashlink)
endif()

if(QD_WITH_AMDGPU)
  file(GLOB QD_HASHLINK_AMDGPU_BC_FILES_ROCM70 "${PROJECT_SOURCE_DIR}/external/amdgpu_libdevice_rocm70/*.bc")
  install(FILES ${QD_HASHLINK_AMDGPU_BC_FILES_ROCM70}
    DESTINATION "${QD_HASHLINK_ROCM_RUNTIME_INSTALL_DIR}"
    COMPONENT hashlink)
endif()

if(APPLE AND QD_WITH_VULKAN AND QD_MOLTENVK_DYLIB)
  install(FILES "${QD_MOLTENVK_DYLIB}"
    DESTINATION "${QD_HASHLINK_RUNTIME_INSTALL_DIR}"
    COMPONENT hashlink)
endif()

if(QD_BUILD_HASHLINK_TESTS)
  if(NOT QD_WITH_LLVM)
    message(FATAL_ERROR "QD_BUILD_HASHLINK_TESTS=ON requires QD_WITH_LLVM=ON for the CPU smoke test")
  endif()
  find_program(QD_HAXE_EXECUTABLE haxe)
  find_program(QD_HL_EXECUTABLE hl)
  find_program(QD_BASH_EXECUTABLE bash)
  if(NOT QD_HAXE_EXECUTABLE)
    message(FATAL_ERROR "QD_BUILD_HASHLINK_TESTS=ON requires haxe on PATH")
  endif()
  if(NOT QD_HL_EXECUTABLE)
    message(FATAL_ERROR "QD_BUILD_HASHLINK_TESTS=ON requires hl on PATH")
  endif()

  add_test(NAME hashlink_haxe_compile
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/v3/hashlink_v3_smoke.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-v3-compile.hl
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)

  add_test(NAME haxe_v3_smoke
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/v3/hashlink_v3_smoke.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-v3-smoke.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)

  add_test(NAME hashlink_descriptor_golden
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/descriptor/hashlink_descriptor_golden.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-descriptor-golden.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)
  if(QD_BUILD_HASHLINK_LEGACY_TESTS)
  # Legacy pre-v3 runtime suites are opt-in on the breaking branch.
  add_test(NAME hashlink_hl_runtime_alpha
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/hashlink_runtime_alpha.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-runtime-alpha.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)

  add_test(NAME hashlink_hl_runtime_beta
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/hashlink_runtime_beta.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-runtime-beta.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)

  add_test(NAME hashlink_hl_runtime_gamma
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/hashlink_runtime_gamma.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-runtime-gamma.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)


  add_test(NAME hashlink_hl_smoke
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/hashlink_smoke.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-smoke.hl
      -DRUN_HL=ON
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)
  add_test(NAME hashlink_hl_print
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DHL_EXECUTABLE=${QD_HL_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DHXML_FILE=${PROJECT_SOURCE_DIR}/tests/hashlink/hashlink_print.hxml
      -DOUTPUT_HL=${CMAKE_BINARY_DIR}/hashlink-print.hl
      -DRUN_HL=ON
      -DEXPECT_STDOUT_SUBSTRING=hashlink-print-token
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHashLinkTest.cmake)

  endif()

  add_test(NAME hashlink_macro_compile_fail
    COMMAND ${CMAKE_COMMAND}
      -DREPO_ROOT=${PROJECT_SOURCE_DIR}
      -DHAXE_EXECUTABLE=${QD_HAXE_EXECUTABLE}
      -DQUADRANTS_HDLL=$<TARGET_FILE:quadrants.hdll>
      -DQUADRANTS_RUNTIME_DIR=${QD_RUNTIME_BUILD_DIR}
      -DOUTPUT_DIR=${CMAKE_BINARY_DIR}/hashlink-compile-fail
      -P ${PROJECT_SOURCE_DIR}/cmake/RunHaxeCompileFailTests.cmake)

  if(QD_BASH_EXECUTABLE)
    add_test(NAME hashlink_public_dynamic_scan
      COMMAND ${QD_BASH_EXECUTABLE}
        ${PROJECT_SOURCE_DIR}/tools/check_public_dynamic.sh
        ${PROJECT_SOURCE_DIR}/bindings/hashlink/haxe/quadrants
        ${PROJECT_SOURCE_DIR}/tools/public_dynamic_allowlist.txt)
  else()
    message(WARNING "bash was not found; hashlink_public_dynamic_scan test is disabled")
  endif()
endif()
