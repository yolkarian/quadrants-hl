cmake_minimum_required(VERSION 3.17)

if(NOT QD_HASHLINK_ROOT)
  set(QD_HASHLINK_ROOT "${PROJECT_SOURCE_DIR}/../hashlink" CACHE PATH "Path to a HashLink checkout or install")
endif()

set(QD_HASHLINK_ROOT "${QD_HASHLINK_ROOT}" CACHE PATH "Path to a HashLink checkout or install")

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
  quadrants_hl.h
  descriptor.h)

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

if(LINUX)
  target_link_options(quadrants.hdll PRIVATE -Wl,--exclude-libs=ALL)
endif()

install(TARGETS quadrants.hdll
  RUNTIME DESTINATION "${INSTALL_LIB_DIR}/hashlink"
  LIBRARY DESTINATION "${INSTALL_LIB_DIR}/hashlink")
