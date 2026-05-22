if(NOT DEFINED REPO_ROOT)
  message(FATAL_ERROR "REPO_ROOT is required")
endif()
if(NOT DEFINED HAXE_EXECUTABLE)
  message(FATAL_ERROR "HAXE_EXECUTABLE is required")
endif()
if(NOT DEFINED QUADRANTS_HDLL)
  message(FATAL_ERROR "QUADRANTS_HDLL is required")
endif()
if(NOT DEFINED QUADRANTS_RUNTIME_DIR)
  message(FATAL_ERROR "QUADRANTS_RUNTIME_DIR is required")
endif()
if(NOT DEFINED HXML_FILE)
  message(FATAL_ERROR "HXML_FILE is required")
endif()
if(NOT DEFINED OUTPUT_HL)
  message(FATAL_ERROR "OUTPUT_HL is required")
endif()

get_filename_component(OUTPUT_DIR "${OUTPUT_HL}" DIRECTORY)
file(MAKE_DIRECTORY "${OUTPUT_DIR}")
if(EXISTS "${QUADRANTS_RUNTIME_DIR}/runtime_cuda.bc"
   AND NOT EXISTS "${QUADRANTS_RUNTIME_DIR}/slim_libdevice.10.bc"
   AND EXISTS "${REPO_ROOT}/external/cuda_libdevice/slim_libdevice.10.bc")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${REPO_ROOT}/external/cuda_libdevice/slim_libdevice.10.bc"
            "${QUADRANTS_RUNTIME_DIR}/slim_libdevice.10.bc"
    RESULT_VARIABLE LIBDEVICE_COPY_RESULT)
  if(NOT LIBDEVICE_COPY_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to stage slim_libdevice.10.bc into ${QUADRANTS_RUNTIME_DIR}")
  endif()
endif()


execute_process(
  COMMAND "${CMAKE_COMMAND}" -E env
          "QUADRANTS_HDLL=${QUADRANTS_HDLL}"
          "QUADRANTS_RUNTIME_DIR=${QUADRANTS_RUNTIME_DIR}"
          "QD_LIB_DIR=${QUADRANTS_RUNTIME_DIR}"
          "${HAXE_EXECUTABLE}" "${HXML_FILE}" -hl "${OUTPUT_HL}"
  WORKING_DIRECTORY "${REPO_ROOT}"
  RESULT_VARIABLE HAXE_RESULT
  OUTPUT_VARIABLE HAXE_OUTPUT
  ERROR_VARIABLE HAXE_ERROR)

if(NOT HAXE_RESULT EQUAL 0)
  message(STATUS "${HAXE_OUTPUT}")
  message(STATUS "${HAXE_ERROR}")
  message(FATAL_ERROR "Haxe compilation failed for ${HXML_FILE}")
endif()

if(RUN_HL)
  if(NOT DEFINED HL_EXECUTABLE)
    message(FATAL_ERROR "HL_EXECUTABLE is required when RUN_HL is enabled")
  endif()
  get_filename_component(QUADRANTS_HDLL_DIR "${QUADRANTS_HDLL}" DIRECTORY)

  set(_ld_path "${QUADRANTS_HDLL_DIR}")
  if(DEFINED ENV{LD_LIBRARY_PATH} AND NOT "$ENV{LD_LIBRARY_PATH}" STREQUAL "")
    string(APPEND _ld_path ":$ENV{LD_LIBRARY_PATH}")
  endif()

  set(_dyld_path "${QUADRANTS_HDLL_DIR}")
  if(DEFINED ENV{DYLD_LIBRARY_PATH} AND NOT "$ENV{DYLD_LIBRARY_PATH}" STREQUAL "")
    string(APPEND _dyld_path ":$ENV{DYLD_LIBRARY_PATH}")
  endif()

  set(_path "$ENV{PATH}")

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            "QD_LIB_DIR=${QUADRANTS_RUNTIME_DIR}"
            "QUADRANTS_RUNTIME_DIR=${QUADRANTS_RUNTIME_DIR}"
            "LD_LIBRARY_PATH=${_ld_path}"
            "DYLD_LIBRARY_PATH=${_dyld_path}"
            "PATH=${_path}"
            "${HL_EXECUTABLE}" "${OUTPUT_HL}"
    WORKING_DIRECTORY "${REPO_ROOT}"
    RESULT_VARIABLE HL_RESULT
    OUTPUT_VARIABLE HL_OUTPUT
    ERROR_VARIABLE HL_ERROR)

  message(STATUS "${HL_OUTPUT}")
  if(DEFINED EXPECT_STDOUT_SUBSTRING)
    string(FIND "${HL_OUTPUT}" "${EXPECT_STDOUT_SUBSTRING}" _stdout_match)
    if(_stdout_match EQUAL -1)
      message(STATUS "${HL_ERROR}")
      message(FATAL_ERROR "Expected stdout substring '${EXPECT_STDOUT_SUBSTRING}' was not found for ${OUTPUT_HL}")
    endif()
  endif()
  if(NOT HL_RESULT EQUAL 0)
    message(STATUS "${HL_ERROR}")
    message(FATAL_ERROR "HashLink test failed for ${OUTPUT_HL}")
  endif()
endif()
