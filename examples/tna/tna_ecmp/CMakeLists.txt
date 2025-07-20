cmake_minimum_required(VERSION 3.10)
project(tna_ecmp VERSION 1.0 LANGUAGES C CXX)

set(CMAKE_BUILD_TYPE "RelWithDebInfo")
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(p4ws REQUIRED)
include(p4ws-build)

set(P4_NAME    "tna_ecmp"    CACHE STRING "cmake target name" FORCE)
set(P4_SOURCE  "tna_ecmp.p4" CACHE STRING "P4 source file" FORCE)

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
