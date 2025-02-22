cmake_minimum_required(VERSION 3.12)
project(p4ws VERSION 1.0)

###############################################################################
# p4ws Python Packages
###############################################################################

find_package(Python3 COMPONENTS Interpreter REQUIRED)

# Found package name
message(STATUS "Package name: ${PROJECT_NAME}")

# Found package version
execute_process(
  COMMAND ${Python3_EXECUTABLE} -m setuptools_scm
  OUTPUT_VARIABLE PACKAGE_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  RESULT_VARIABLE RET
)
if (NOT ${RET} EQUAL 0)
  message(FATAL_ERROR "Failed to retrieve package version using setuptools_scm")
else()
  message(STATUS "Package version: ${PACKAGE_VERSION}")
endif()

# Build distribution
file(GLOB_RECURSE SOURCE_FILES "${CMAKE_SOURCE_DIR}/src/p4ws/*")
set(DIST_DIR "${CMAKE_BINARY_DIR}/dist")
set(SDIST_FILE "${DIST_DIR}/${PROJECT_NAME}-${PACKAGE_VERSION}.tar.gz")
set(WHEEL_FILE "${DIST_DIR}/${PROJECT_NAME}-${PACKAGE_VERSION}-py3-none-any.whl")

add_custom_command(
  OUTPUT ${WHEEL_FILE}
  COMMAND ${Python3_EXECUTABLE} -m build --outdir ${CMAKE_BINARY_DIR}/dist
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
  COMMENT "Building p4ws Python package"
  DEPENDS ${SOURCE_FILES}
  BYPRODUCTS ${WHEEL_FILE}
  VERBATIM
)
add_custom_target(build ALL DEPENDS ${WHEEL_FILE})

###############################################################################
# p4ws CMake tools
###############################################################################

install(DIRECTORY "${CMAKE_SOURCE_DIR}/cmake/" DESTINATION "${CMAKE_INSTALL_PREFIX}/share/cmake/${PROJECT_NAME}"
  FILES_MATCHING
  PATTERN "*.cmake"
)
