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
if(NOT DEFINED OUTPUT_DIR)
  set(OUTPUT_DIR "${REPO_ROOT}/build/hashlink-compile-fail")
endif()

file(MAKE_DIRECTORY "${OUTPUT_DIR}")
file(GLOB CASE_FILES "${REPO_ROOT}/tests/hashlink/compile_fail/*.hx")
list(SORT CASE_FILES)

if(CASE_FILES STREQUAL "")
  message(FATAL_ERROR "No HashLink compile-fail test cases found")
endif()

set(FAILED_CASES "")
set(PASSED_COUNT 0)

foreach(CASE_FILE IN LISTS CASE_FILES)
  get_filename_component(CASE_NAME "${CASE_FILE}" NAME_WE)
  file(READ "${CASE_FILE}" CASE_CONTENT)
  string(REGEX MATCH "EXPECT_ERROR: ([^\n\r]+)" _MATCH "${CASE_CONTENT}")
  if(NOT CMAKE_MATCH_1)
    list(APPEND FAILED_CASES "${CASE_NAME}: missing EXPECT_ERROR marker")
    continue()
  endif()
  set(EXPECTED_ERROR "${CMAKE_MATCH_1}")
  set(OUTPUT_HL "${OUTPUT_DIR}/${CASE_NAME}.hl")

  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E env
            "QUADRANTS_HDLL=${QUADRANTS_HDLL}"
            "QUADRANTS_RUNTIME_DIR=${QUADRANTS_RUNTIME_DIR}"
            "QD_LIB_DIR=${QUADRANTS_RUNTIME_DIR}"
            "${HAXE_EXECUTABLE}"
            -cp "${REPO_ROOT}/bindings/hashlink/haxe"
            -cp "${REPO_ROOT}/tests/hashlink/compile_fail"
            -main "${CASE_NAME}"
            -hl "${OUTPUT_HL}"
    WORKING_DIRECTORY "${REPO_ROOT}"
    RESULT_VARIABLE HAXE_RESULT
    OUTPUT_VARIABLE HAXE_OUTPUT
    ERROR_VARIABLE HAXE_ERROR)

  set(COMBINED_OUTPUT "${HAXE_OUTPUT}\n${HAXE_ERROR}")
  if(HAXE_RESULT EQUAL 0)
    list(APPEND FAILED_CASES "${CASE_NAME}: compilation unexpectedly succeeded")
    continue()
  endif()

  string(FIND "${COMBINED_OUTPUT}" "${EXPECTED_ERROR}" ERROR_OFFSET)
  if(ERROR_OFFSET EQUAL -1)
    list(APPEND FAILED_CASES "${CASE_NAME}: expected '${EXPECTED_ERROR}' but got:\n${COMBINED_OUTPUT}")
    continue()
  endif()

  math(EXPR PASSED_COUNT "${PASSED_COUNT} + 1")
endforeach()

if(FAILED_CASES)
  foreach(FAILED IN LISTS FAILED_CASES)
    message(STATUS "${FAILED}")
  endforeach()
  message(FATAL_ERROR "HashLink compile-fail tests failed")
endif()

message(STATUS "HashLink macro compile-fail tests ok (${PASSED_COUNT} cases)")
