###############################################################################
# P4 Workshop P4 Build
#
# Compile P4 programs
#
# Usage:
# add_p4_program(<cmake_target> <p4target> <p4src> <p4lang> <p4arch> <apis>)
#
# cmake_target - cmake target name
# p4target     - P4 target
# - bmv2         - BMv2 (see below)
# - tofino       - Intel Tofino
# - tofino2      - Intel Tofino2
# - tofino2m     - Intel Tofino2M
# - tofino2u     - Intel Tofino2U
# - tofino2a0    - Intel Tofino2A0
# - tofino3      - Intel Tofino3
# p4src        - P4 source file
#
# p4lang       - P4 standard
# - p4-14        - P4-14(only for PSA architecture)
# - p4_14
# - p4-16        - P4-16
# - p4_16
#
# p4arch       - P4 architecture
# | P4 Target | Supported architectures |
# | --------- | ----------------------- |
# | bmv2      | v1model                 |
# | bmv2      | psa                     |
# | bmv2      | pna                     |
# | tofino    | default, tna, v1model   |
# | tofino2   | default, t2na           |
# | tofino2m  | t2na                    |
# | tofino2u  | t2na                    |
# | tofino2a0 | t2na                    |
# | tofino3   | default, t2na, t3na     |
#
# apis       - a list for API interfaces
# - for BMv2:
#   - p4rt       - generate P4Runtime API configuration
# - for Tofinos:
#   - bfrt       - generate BFRuntime API configuration
#   - p4rt       - generate P4Runtime API configuration
#   - withpd     - generate PD API
#   - withthrift - generate Thrift support to PD
#
###############################################################################

include(utils)


###############################################################################
# Paths
###############################################################################

function(P4_TARGET_INCLUDE_DIRECTORIES t)
  get_target_property(EXISTING_P4_INCLUDE_DIRECTORIES "${t}" P4_INCLUDE_DIRECTORIES)

  set(ABSOLUTE_INCLUDE_DIRECTORIES)
  # Convert to absolute path
  foreach(dir ${ARGN})
    if(NOT IS_ABSOLUTE "${dir}")
      get_filename_component(dir "${dir}" ABSOLUTE "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    list(APPEND ABSOLUTE_INCLUDE_DIRECTORIES "${dir}")
  endforeach()

  if(EXISTING_P4_INCLUDE_DIRECTORIES)
    list(APPEND P4_INCLUDE_DIRECTORIES ${EXISTING_P4_INCLUDE_DIRECTORIES} ${ABSOLUTE_INCLUDE_DIRECTORIES})
  else()
    set(P4_INCLUDE_DIRECTORIES ${ABSOLUTE_INCLUDE_DIRECTORIES})
  endif()

  set_target_properties("${t}" PROPERTIES P4_INCLUDE_DIRECTORIES "${P4_INCLUDE_DIRECTORIES}")
endfunction()


###############################################################################
# Check Common Parameters
###############################################################################

function(P4_CHECK_P4SRC p4src)
  if((p4src STREQUAL "") OR
     (NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"))
    message(FATAL_ERROR "P4 program '${COLOR_ERR}${p4src}${COLOR_RST}' not found\nHint: source dir is '${COLOR_HINT}${CMAKE_CURRENT_SOURCE_DIR}${COLOR_RST}'")
  else()
    message("P4 Program: ${COLOR_INFO}${p4src}${COLOR_RST}(${CMAKE_CURRENT_SOURCE_DIR}/${p4src})")
  endif()
endfunction()

function(P4_CHECK_P4LANG p4lang)
  if(NOT(p4lang STREQUAL "p4-14" OR
         p4lang STREQUAL "p4_14" OR
         p4lang STREQUAL "p4-16" OR
         p4lang STREQUAL "p4_16"))
    message(FATAL_ERROR "Not a valid P4 standard: ${COLOR_ERR}${p4lang}${COLOR_RST}")
  else()
    message("P4 Standard: ${COLOR_INFO}${p4lang}${COLOR_RST}")
  endif()
endfunction()

function(P4_CHECK_P4FLAGS)
  separate_arguments(COMPUTED_P4PPFLAGS UNIX_COMMAND ${P4PPFLAGS})
  separate_arguments(COMPUTED_P4FLAGS UNIX_COMMAND ${P4FLAGS})

  # Include files from p4ws
  list(APPEND COMPUTED_P4PPFLAGS "-I/usr/share/p4include" "-I/usr/local/share/p4include")

  message("P4 Preprocessor Flags: ${COLOR_INFO}${COMPUTED_P4PPFLAGS}${COLOR_RST}")
  message("P4 Flags: ${COLOR_INFO}${COMPUTED_P4FLAGS}${COLOR_RST}")

  set(COMPUTED_P4PPFLAGS "${COMPUTED_P4PPFLAGS}" PARENT_SCOPE)
  set(COMPUTED_P4FLAGS "${COMPUTED_P4FLAGS}" PARENT_SCOPE)
endfunction()

function(ADD_P4_PROGRAM t p4target p4src p4lang p4arch apis)
  if(p4target STREQUAL "bmv2")
    set(p4rt False)
    foreach(api IN LISTS apis)
      if(api STREQUAL "p4rt")
        set(p4rt True)
      else()
        message(FATAL_ERROR "${COLOR_ERR}Unknown API: ${api}${COLOR_RST}")
      endif()
    endforeach()

    include(bmv2-build)
    bmv2_add_p4_program("${t}" "${p4target}" "${p4src}" "${p4lang}" "${p4arch}" "${p4rt}")
  elseif((p4target STREQUAL "tofino") OR
         (p4target STREQUAL "tofino2") OR
         (p4target STREQUAL "tofino2m") OR
         (p4target STREQUAL "tofino2u") OR
         (p4target STREQUAL "tofino2a0") OR
         (p4target STREQUAL "tofino3"))

    set(bfrt False)
    set(p4rt False)
    set(withpd False)
    set(withthrift False)
    foreach(api IN LISTS apis)
      if(api STREQUAL "bfrt")
        set(bfrt True)
      elseif(api STREQUAL "p4rt")
        set(p4rt True)
      elseif(api STREQUAL "withpd")
        set(withpd True)
      elseif(api STREQUAL "withthrift")
        set(withthrift True)
      else()
        message(FATAL_ERROR "${COLOR_ERR}Unknown API: ${api}${COLOR_RST}")
      endif()
    endforeach()

    include(bfsde-build)
    bfsde_add_p4_program("${t}" "${p4target}" "${p4src}" "${p4lang}" "${p4arch}" "${bfrt}" "${p4rt}" "${withpd}" "${withthrift}")
  else()
    message(FATAL_ERROR "${COLOR_ERR}Unknown P4 target: ${p4target}${COLOR_RST}")
  endif()
endfunction()
