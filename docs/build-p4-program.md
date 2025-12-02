Build P4 Program
========================================

This document describes how to build a P4 program using p4ws.

**Contents**
- [Prepare CMakefile](#prepare-cmakefile)
  - [Prequisites](#prequisites)
  - [Add a P4 Program](#add-a-p4-program)
  - [Add include directories](#add-include-directories)
  - [A Full Example](#a-full-example)
- [Build P4 Program](#build-p4-program-1)


Prepare CMakefile
----------------------------------------

To build a P4 program, you need to prepare a `CMakefile` that specifies the P4 source files and any additional configurations required for the build process.

### Prequisites

*Something that all CMakefiles should have*

> ℹ️ p4ws-build requires a minimum version of CMake 3.0.

```cmake
cmake_minimum_required(VERSION 3.0)
project(PROJECT_NAME VERSION 1.0)
```

*Ensure p4ws-build is included*

```cmake
find_package(p4ws REQUIRED)
include(p4ws-build)
```


### Add a P4 Program

*Add a P4 program*

```cmake
# Add a custom target for the P4 program
add_custom_target(<cmake_target> ALL)

# Add a P4 program target, having target name: <cmake_target>-<p4target>
add_p4_program(
  <cmake_target>
  <p4target>
  <p4src>
  <p4lang>
  <p4arch>
  <apis>
)

# Attach the P4 program target to the custom target
add_dependencies(<cmake_target> <cmake_target>-<p4target>)
```

*Arguments*
- `<cmake_target>`: The prefix of the CMake target for the P4 program.
- `<p4target>`: The P4 target:
  - bmv2         - Behavioral Model version 2
  - tofino       - Intel Tofino
  - tofino2      - Intel Tofino2
  - tofino2m     - Intel Tofino2M
  - tofino2u     - Intel Tofino2U
  - tofino2a0    - Intel Tofino2A0
  - tofino3      - Intel Tofino3
- `<p4src>`: The only P4 source file to be compiled.
- `<p4lang>`: The P4 language version:
  - p4-14       - P4-14(only for PSA architecture)
  - p4_14       - As above
  - p4-16       - P4-16
  - p4_16       - As above
- `<p4arch>`: The P4 architecture:
  See below for the list of supported architectures.
- `<apis>`: A list of APIs to be used by controller:
  - bfrt       - generate BFRuntime API configuration
  - p4rt       - generate P4Runtime API configuration
  - withpd     - generate PD API
  - withthrift - generate Thrift support to PD


### Add include directories

If your P4 program requires additional include directories, you can specify them using the `p4_target_include_directories` function.

```cmake
p4_target_include_directories(
  <cmake_target>,
  [items1...]
)
```

Notes: <cmake_target> is the same as the one used in `add_p4_program`.


### A Full Example

Below is an full example of a `CMakeLists.txt` file that builds a P4 program named `myprog` for the Tofino target using the P4-16 language and the PSA architecture.

```cmake
cmake_minimum_required(VERSION 3.0)
project(p4ws-build-test VERSION 1.0 LANGUAGES C CXX)

set(CMAKE_BUILD_TYPE "RelWithDebInfo")
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(p4ws REQUIRED)
include(p4ws-build)

set(P4_NAME    "myprog"    CACHE STRING "cmake target name" FORCE)
set(P4_SOURCE  "myprog.p4" CACHE STRING "P4 source file" FORCE)

set(P4_LANG    "p4-16"   CACHE STRING "P4 standard")
set(P4_ARCH    "default" CACHE STRING "P4 architecture")
set(P4_TARGET  "tofino"  CACHE STRING "P4 target")

option(BFRT       "Generate BFRuntime API configuration" ON)
option(P4RT       "Generate P4Runtime API configuration" ON)
option(WITHPD     "Generate PD API"                      OFF)
option(WITHTHRIFT "Generate Thrift support to PD"        OFF)

set(APIS)
if(BFRT)
  list(APPEND APIS "bfrt")
endif()
if(P4RT)
  list(APPEND APIS "p4rt")
endif()
if(WITHPD)
  list(APPEND APIS "withpd")
endif()
if(WITHTHRIFT)
  list(APPEND APIS "withthrift")
endif()

add_custom_target(${P4_NAME} ALL)

add_p4_program(${P4_NAME} ${P4_TARGET} ${P4_SOURCE} ${P4_LANG} ${P4_ARCH} "${APIS}")

add_dependencies(${P4_NAME} ${P4_NAME}-${P4_TARGET})
```


Build P4 Program
----------------------------------------

To build the P4 program, you need to create a build directory, run CMake to configure the project, and then compile it using `make`.
```bash
mkdir -p build && cd build
cmake ..
make
```

The P4 program configuration will be generated at:
```cmake
${CMAKE_CURRENT_BINARY_DIR}/<cmake_target>/<p4target>
```
