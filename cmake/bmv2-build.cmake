###############################################################################
# BMv2 P4 Build
#
# Compile P4 programs
#
# Usage:
# bmv2_add_p4_program(<cmake_target> <p4target> <p4src> <p4lang> <p4arch> <p4rt>)
#
# cmake_target - cmake target name
# p4target     - P4 target
# - bmv2         - BMv2 (see below)
# p4src        - P4 source file
#
# p4lang       - P4 standard
# - p4-14        - P4-14
# - p4_14
# - p4-16        - P4-16
# - p4_16
#
# p4arch       - P4 architecture
# | P4 Target | Supported architectures | Description   |
# | --------- | ----------------------- | ------------- |
# | bmv2      | v1model                 | Simple Switch |
# | bmv2      | psa                     | PSA Switch    |
# | bmv2      | pna                     | PNA NIC       |
#
# p4rt       - generate P4Runtime API configuration
#
###############################################################################


###############################################################################
# Find BMv2
###############################################################################

include(bmv2-config)


###############################################################################
# Check Parameters
###############################################################################

function(BMV2_P4_CHECK_P4ARCHTARGET p4lang p4arch p4target)
  if(p4target STREQUAL "bmv2")
    if(NOT(p4arch STREQUAL "v1model" OR
           p4arch STREQUAL "psa" OR
           p4arch STREQUAL "pna"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in BMv2${COLOR_RST}")
    endif()
  endif()

  message("P4 Architecture: ${COLOR_INFO}${p4arch}${COLOR_RST}")
  message("P4 Target: ${COLOR_INFO}${p4target}${COLOR_RST}")
endfunction()

function(BMV2_P4_CHECK_RT p4rt)
  if(p4rt)
    message("Runtime API: ${COLOR_INFO}P4Runtime${COLOR_RST}")
  endif()
endfunction()

function(BMV2_P4_CHECK_PDFLAGS)
  separate_arguments(COMPUTED_PDFLAGS UNIX_COMMAND ${PDFLAGS})
  if(PDFLAGS)
    message("PD Flags: ${COLOR_INFO}${PDFLAGS}${COLOR_RST}")
  endif()
endfunction()

function(BMV2_ADD_P4_PROGRAM t p4target p4src p4lang p4arch p4rt)
  add_custom_target("${t}-${p4target}" ALL)

  set(target_path "${t}/${p4target}")
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}")

  message("CMake Target: ${COLOR_INFO}${t}-${p4target}${COLOR_RST}")
  p4_check_p4src("${p4src}")
  p4_check_p4lang("${p4lang}")
  bmv2_p4_check_p4archtarget("${p4lang}" "${p4arch}" "${p4target}")
  bmv2_p4_check_rt("${p4rt}")
  p4_check_p4flags()
  set(COMPUTED_P4PPFLAGS_ARGS "")
  foreach(p4ppflag ${COMPUTED_P4PPFLAGS})
    list(APPEND COMPUTED_P4PPFLAGS_ARGS "${p4ppflag}")
  endforeach()
  set(COMPUTED_P4FLAGS_ARGS "")
  foreach(p4flag ${COMPUTED_P4FLAGS})
    list(APPEND COMPUTED_P4FLAGS_ARGS "${p4flag}")
  endforeach()
  bmv2_p4_check_pdflags()

  set(output_files "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/main.json")
  set(rt_commands "")
  set(depends_target "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/main.json")

  if(p4rt)
    set(output_files "${output_files}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/p4info.json" )
    set(rt_commands "${rt_commands}" "--p4runtime-files" "${target_path}/p4info.json")
    set(depends_target "${depends_target}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/p4info.json")
  endif()

  # compile the p4 program
  if(p4arch STREQUAL "v1model")
    find_p4c_bm2_ss(REQUIRED)

    set(P4C "${P4C_BM2_SS}")
    list(APPEND P4FLAGS_INTERNAL "-D__P4_ARCH_V1MODEL__")
  elseif(p4arch STREQUAL "psa")
    find_p4c_bm2_psa(REQUIRED)

    set(P4C "${P4C_BM2_PSA}")
    list(APPEND P4FLAGS_INTERNAL "-D__P4_ARCH_PSA__")
  elseif(p4arch STREQUAL "pna")
    find_p4c_bm2_pna(REQUIRED)

    set(P4C "${P4C_BM2_PNA}")
    list(APPEND P4FLAGS_INTERNAL "-D__P4_ARCH_PNA__")
  endif()

  get_target_property(EXISTING_P4_INCLUDE_DIRECTORIES "${t}" P4_INCLUDE_DIRECTORIES)
  if(EXISTING_P4_INCLUDE_DIRECTORIES)
    set(P4_INCLUDE_DIRECTORIES "${EXISTING_P4_INCLUDE_DIRECTORIES}")
  else()
    set(P4_INCLUDE_DIRECTORIES "")
  endif()
  set(COMPUTED_P4_INCLUDE_FLAGS_ARGS "")
  foreach(dir ${P4_INCLUDE_DIRECTORIES})
    list(APPEND COMPUTED_P4_INCLUDE_FLAGS_ARGS "-I${dir}")
  endforeach()

  add_custom_command(OUTPUT ${output_files}
    COMMAND "${P4C}"
      --std "${p4lang}"
      --target "${p4target}"
      --arch "${p4arch}"
      ${rt_commands}
      -o "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/main.json"
      ${COMPUTED_P4_INCLUDE_FLAGS_ARGS}
      ${COMPUTED_P4PPFLAGS_ARGS}
      ${COMPUTED_P4FLAGS_ARGS}
      ${P4FLAGS_INTERNAL}
      "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
  )
  add_custom_target("${t}-${p4target}-conf" ALL DEPENDS ${output_files})
  add_dependencies("${t}-${p4target}" "${t}-${p4target}-conf")

  set(installed_dir)
  # install generated program file
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/" DESTINATION "share/p4/targets/${p4target}"
    FILES_MATCHING
    PATTERN "main.json"
  )
  list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/share/p4/targets/${p4target}")
  # install p4info.json
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/" DESTINATION "share/${p4target}pd/${t}"
    FILES_MATCHING
    PATTERN "p4info.json"
  )
  list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/share/${p4target}pd/${t}")

  # remove dirs
  add_custom_target(${t}-${p4target}-rmdir
    COMMAND mkdir -p ${installed_dir}
    COMMAND find ${installed_dir} -type d -empty -delete
    DEPENDS rm
    COMMENT "Removing directories of ${t}-${p4target}..."
  )
  add_dependencies(rmdir ${t}-${p4target}-rmdir)
endfunction()


# uninstall
add_custom_target(rm
  COMMAND if [ -f "${CMAKE_CURRENT_BINARY_DIR}/install_manifest.txt" ]; then xargs rm -f < "${CMAKE_CURRENT_BINARY_DIR}/install_manifest.txt" ";" fi
  COMMENT "Removing installed files..."
)
add_custom_target(rmdir
  DEPENDS rm
  COMMENT "Removing directories..."
)
add_custom_target(uninstall
  DEPENDS rm rmdir
  COMMENT "Uninstalling..."
)
