###############################################################################
# Barefoot P4 Build
#
# Compile P4 programs
#
# Usage:
# bfsde_add_p4_program(<cmake_target> <p4target> <p4src> <p4lang> <p4arch> <bfrt> <p4rt> <withpd> <withthrift>)
#
# cmake_target - cmake target name
# p4target     - P4 target
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
# | tofino    | default, tna, v1model   |
# | tofino2   | default, t2na           |
# | tofino2m  | t2na                    |
# | tofino2u  | t2na                    |
# | tofino2a0 | t2na                    |
# | tofino3   | default, t2na, t3na     |
#
# bfrt       - generate BFRuntime API configuration
# p4rt       - generate P4Runtime API configuration
# withpd     - generate PD API
# withthrift - generate Thrift support to PD
#
###############################################################################


###############################################################################
# Check Python
###############################################################################

find_program(PYTHON3_EXECUTABLE python3)
if(PYTHON3_EXECUTABLE)
  add_custom_target(python3)
  message("-- Check for python3: ${PYTHON3_EXECUTABLE}")

  execute_process(
    COMMAND ${PYTHON3_EXECUTABLE} -c "if True:
      from distutils import sysconfig as sc
      print(sc.get_python_lib(prefix='', standard_lib=True, plat_specific=True))"
    OUTPUT_VARIABLE PYTHON3_SITE
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(PYTHON3_SITE "${PYTHON3_SITE}/site-packages")
  message("-- python3 site-packages: ${PYTHON3_SITE}")
else()
  message("-- Check for python3: not found")
endif()


###############################################################################
# Find Barefoot SDE
###############################################################################

include(bfsde-config)


###############################################################################
# Check Parameters
###############################################################################

function(BFSDE_P4_CHECK_P4ARCHTARGET p4lang p4arch p4target)
  if((p4lang STREQUAL "p4-14" OR
      p4lang STREQUAL "p4_14") AND
     (NOT(p4lang STREQUAL "psa")))
    message("${COLOR_WARN}p4-14 may only support PSA architecture${COLOR_RST}")
  endif()

  if(p4target STREQUAL "tofino")
    if(NOT(p4arch STREQUAL "default" OR
           p4arch STREQUAL "tna" OR
           p4arch STREQUAL "v1model"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino${COLOR_RST}")
    endif()
  endif()
  if(p4target STREQUAL "tofino2")
    if(NOT(p4arch STREQUAL "default" OR
           p4arch STREQUAL "t2na"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino2${COLOR_RST}")
    endif()
  endif()
  if(p4target STREQUAL "tofino2m")
    if(NOT(p4arch STREQUAL "t2na"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino2M${COLOR_RST}")
    endif()
  endif()
  if(p4target STREQUAL "tofino2u")
    if(NOT(p4arch STREQUAL "t2na"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino2U${COLOR_RST}")
    endif()
  endif()
  if(p4target STREQUAL "tofino2a0")
    if(NOT(p4arch STREQUAL "t2na"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino2A0${COLOR_RST}")
    endif()
  endif()
  if(p4target STREQUAL "tofino3")
    if(NOT(p4arch STREQUAL "t2na" OR
           p4arch STREQUAL "t3na" OR
           p4arch STREQUAL "default"))
      message("${COLOR_WARN}Architecture ${p4arch} may not be supported in Tofino3${COLOR_RST}")
    endif()
  endif()

  message("P4 Architecture: ${COLOR_INFO}${p4arch}${COLOR_RST}")
  message("P4 Target: ${COLOR_INFO}${p4target}${COLOR_RST}")
endfunction()

function(BFSDE_P4_CHECK_RT bfrt p4rt withpd withthrift)
  if(bfrt)
    message("Runtime API: ${COLOR_INFO}BFRuntime${COLOR_RST}")
  endif()

  if(p4rt)
    message("Runtime API: ${COLOR_INFO}P4Runtime${COLOR_RST}")
  endif()

  if(withpd)
    if(withthrift)
      message("Runtime API: ${COLOR_INFO}PD with Thrift${COLOR_RST}")
    else()
      message("Runtime API: ${COLOR_INFO}PD${COLOR_RST}")
    endif()
  endif()
endfunction()

function(BFSDE_P4_CHECK_PDFLAGS)
  separate_arguments(COMPUTED_PDFLAGS UNIX_COMMAND ${PDFLAGS})
  if(PDFLAGS)
    message("PD Flags: ${COLOR_INFO}${PDFLAGS}${COLOR_RST}")
  endif()
endfunction()

function(BFSDE_ADD_P4_PROGRAM t p4target p4src p4lang p4arch bfrt p4rt withpd withthrift)
  add_custom_target("${t}-${p4target}" ALL)

  set(target_path "${t}/${p4target}")

  message("CMake Target: ${COLOR_INFO}${t}-${p4target}${COLOR_RST}")
  p4_check_p4src("${p4src}")
  p4_check_p4lang("${p4lang}")
  bfsde_p4_check_p4archtarget("${p4lang}" "${p4arch}" "${p4target}")
  bfsde_p4_check_rt("${bfrt}" "${p4rt}" "${withpd}" "${withthrift}")
  p4_check_p4flags()
  bfsde_p4_check_pdflags()
  if (("${p4target}" STREQUAL "tofino2m") OR
      ("${p4target}" STREQUAL "tofino2u") OR
      ("${p4target}" STREQUAL "tofino2a0"))
    set(chiptype "tofino2")
  else()
    set(chiptype "${p4target}")
  endif()

  set(output_files "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/manifest.json")
  set(rt_commands "")
  set(depends_target "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/manifest.json")

  if(bfrt)
    set(output_files "${output_files}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/bf-rt.json")
    set(rt_commands "${rt_commands}" "--bf-rt-schema" "${target_path}/bf-rt.json")
    set(depends_target "${depends_target}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/bf-rt.json")
    find_bf_p4c_gen_bfrt_conf(REQUIRED)
    find_bf_p4c_manifest_config(REQUIRED)
  else()
    # disable default behaviour of bf-p4c
    set(P4FLAGS_INTERNAL ${P4FLAGS_INTERNAL} --no-bf-rt-schema)
  endif()
  if(p4rt)
    set(output_files "${output_files}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/p4info.txtpb" )
    set(rt_commands "${rt_commands}" "--p4runtime-files" "${target_path}/p4info.txtpb")
    set(depends_target "${depends_target}" "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/p4info.txtpb")
  endif()

  # compile the p4 program
  find_bf_p4c(REQUIRED)
  find_bf_driver(REQUIRED)
  set(P4_INCLUDE_DIRECTORIES "$<TARGET_PROPERTY:${t},P4_INCLUDE_DIRECTORIES>")
  if (bfrt)
    add_custom_command(OUTPUT ${output_files}
      COMMAND "${BF_P4C}"
        --std "${p4lang}"
        --target "${p4target}"
        --arch "${p4arch}"
        ${rt_commands}
        -o "${CMAKE_CURRENT_BINARY_DIR}/${target_path}"
        "$<$<BOOL:${P4_INCLUDE_DIRECTORIES}>:-I$<JOIN:${P4_INCLUDE_DIRECTORIES},;-I>>"
        ${COMPUTED_P4PPFLAGS}
        ${COMPUTED_P4FLAGS}
        ${P4FLAGS_INTERNAL}
        -g
        --program-name "${t}"
        "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
      COMMAND "${BF_P4C_GEN_BFRT_CONF}" --name "${t}" --device "${chiptype}" --testdir "${CMAKE_CURRENT_BINARY_DIR}/${target_path}"
         --installdir "${CMAKE_CURRENT_BINARY_DIR}/${target_path}" --pipe `${BF_P4C_MANIFEST_CONFIG} --pipe "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/manifest.json" `
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
      COMMAND_EXPAND_LISTS
    )
  else()
    add_custom_command(OUTPUT ${output_files}
      COMMAND "${BF_P4C}" --std "${p4lang}" --target "${p4target}" --arch "${p4arch}" ${rt_commands} -o "${CMAKE_CURRENT_BINARY_DIR}/${target_path}" ${COMPUTED_P4PPFLAGS} ${COMPUTED_P4FLAGS} ${P4FLAGS_INTERNAL} -g --program-name "${t}" "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
      DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/${p4src}"
    )
  endif()
  add_custom_target("${t}-${p4target}-conf" ALL DEPENDS ${output_files})
  add_dependencies("${t}-${p4target}" "${t}-${p4target}-conf")

  # generate PD
  if(withpd)
    # generate pd.c, pd.h and pd thrift files
    set(PDDOTC "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/src/pd.c")
    set(PDCLIDOTC "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/src/pdcli.c")
    set(PDRPCDOTTHRIFT "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/thrift/p4_pd_rpc.thrift")

    find_bf_pd(REQUIRED)
    add_custom_command(OUTPUT ${PDDOTC} ${PDCLIDOTC} ${PDRPCDOTTHRIFT}
      COMMAND ${PYTHON3_EXECUTABLE} ${BF_PD_GEN} --path "${target_path}" --manifest "${target_path}/manifest.json" ${COMPUTED_PDFLAGS} ${PDFLAGS_INTERNAL} -o "${target_path}"
      COMMAND ${PYTHON3_EXECUTABLE} ${BF_PD_GEN_CLI} "${target_path}/cli/pd.json" -po "${target_path}/src" -xo "${target_path}/cli/xml" -xd "${BFSDE_INSTALL}/share/cli/xml" -ll "/lib/${p4target}pd/${t}"
      DEPENDS python3 ${t}-${p4target}-conf "${BFSDE_INSTALL}/share/cli/xml"
    )
    add_custom_target(${t}-${p4target}-gen ALL DEPENDS ${PDDOTC} ${PDCLIDOTC} ${PDRPCDOTTHRIFT})
    add_dependencies(${t}-${p4target} ${t}-${p4target}-gen)

    # compile libpd.so
    add_library(${t}-${p4target}-pd SHARED ${PDDOTC})
    target_compile_options(${t}-${p4target}-pd PRIVATE -w)
    target_include_directories(${t}-${p4target}-pd PRIVATE "${BFSDE_INSTALL}/include")
    target_include_directories(${t}-${p4target}-pd PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target_path}")
    set_target_properties(${t}-${p4target}-pd PROPERTIES
      LIBRARY_OUTPUT_NAME "pd"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib/${p4target}pd/${t}"
    )
    add_dependencies(${t}-${p4target}-pd ${t}-${p4target}-gen)
    add_dependencies(${t}-${p4target} ${t}-${p4target}-pd)

    # compile libpdcli.so
    add_library(${t}-${p4target}-pdcli SHARED ${PDCLIDOTC})
    target_compile_options(${t}-${p4target}-pdcli PRIVATE -w)
    target_include_directories(${t}-${p4target}-pdcli PRIVATE "${BFSDE_INSTALL}/include")
    target_include_directories(${t}-${p4target}-pdcli PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target_path}")
    set_target_properties(${t}-${p4target}-pdcli PROPERTIES
      LIBRARY_OUTPUT_NAME "pdcli"
      LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib/${p4target}pd/${t}"
    )
    add_dependencies(${t}-${p4target}-pdcli ${t}-${p4target}-gen)
    add_dependencies(${t}-${p4target} ${t}-${p4target}-pdcli)

    if(withthrift)
      find_bf_thrift(REQUIRED)
      set(PDTHRIFT
        ${target_path}/gen-cpp/p4_prefix.h
        ${target_path}/gen-cpp/p4_prefix0.cpp
        ${target_path}/gen-cpp/p4_prefix1.cpp
        ${target_path}/gen-cpp/p4_prefix2.cpp
        ${target_path}/gen-cpp/p4_prefix3.cpp
        ${target_path}/gen-cpp/p4_prefix4.cpp
        ${target_path}/gen-cpp/p4_prefix5.cpp
        ${target_path}/gen-cpp/p4_prefix6.cpp
        ${target_path}/gen-cpp/p4_prefix7.cpp
        ${target_path}/gen-cpp/p4_pd_rpc_types.h
        ${target_path}/gen-cpp/res_types.h
        ${target_path}/gen-cpp/p4_pd_rpc_types.cpp
        ${target_path}/gen-cpp/res_types.cpp
        ${target_path}/thrift-src/bfn_pd_rpc_server.cpp
        ${target_path}/thrift-src/bfn_pd_rpc_server.h
        ${target_path}/thrift-src/p4_pd_rpc_server.ipp
      )
      if(THRIFT_VERSION_STRING VERSION_LESS 0.14.0)
        list(APPEND PDTHRIFT
          ${target_path}/gen-cpp/p4_pd_rpc_constants.h
          ${target_path}/gen-cpp/res_constants.h
          ${target_path}/gen-cpp/p4_pd_rpc_constants.cpp
          ${target_path}/gen-cpp/res_constants.cpp
        )
      endif()

      # generate pd thrift cpp and h files
      add_custom_command(OUTPUT ${PDTHRIFT}
        COMMAND ${THRIFT_COMPILER} --gen cpp -o "${target_path}" -r "${target_path}/thrift/p4_pd_rpc.thrift"
        COMMAND ${THRIFT_COMPILER} --gen py  -o "${target_path}" -r "${target_path}/thrift/p4_pd_rpc.thrift"
        COMMAND mv -f "${target_path}/gen-cpp/${t}.h" "${target_path}/gen-cpp/p4_prefix.h"
        COMMAND sed --in-place 's/include \"${t}.h\"/include \"p4_prefix.h\"/' ${target_path}/gen-cpp/${t}.cpp
        COMMAND ${PYTHON3_EXECUTABLE} ${BF_PD_SPLIT} "${target_path}/gen-cpp/${t}.cpp" "${target_path}/gen-cpp" 8
        DEPENDS python3 ${t}-${p4target}-gen
      )
      add_custom_target(${t}-${p4target}-gen-thrift ALL DEPENDS ${PDTHRIFT})
      add_dependencies(${t}-${p4target} ${t}-${p4target}-gen-thrift)

      # compile libpdthrift.so
      add_library(${t}-${p4target}-pdthrift SHARED ${PDTHRIFT})
      target_compile_options(${t}-${p4target}-pdthrift PRIVATE -w)
      target_include_directories(${t}-${p4target}-pdthrift PRIVATE "${BFSDE_INSTALL}/include")
      target_include_directories(${t}-${p4target}-pdthrift PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target_path}")
      target_include_directories(${t}-${p4target}-pdthrift PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/gen-cpp")
      set_target_properties(${t}-${p4target}-pdthrift PROPERTIES
        LIBRARY_OUTPUT_NAME "pdthrift"
        LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/lib/${p4target}pd/${t}"
      )
      add_dependencies(${t}-${p4target}-pdthrift ${t}-${p4target}-gen-thrift)
      add_dependencies(${t}-${p4target} ${t}-${p4target}-pdthrift)
    endif()
  endif()

  set(installed_dir)
  # install generated conf file
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/" DESTINATION "share/p4/targets/${p4target}"
    FILES_MATCHING
    PATTERN "*.conf"
    PATTERN "pipe" EXCLUDE
    PATTERN "logs" EXCLUDE
    PATTERN "graphs" EXCLUDE
  )
  list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/share/p4/targets/${p4target}")
  # install bf-rt.json, context.json and tofino.bin
  install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/" DESTINATION "share/${p4target}pd/${t}"
    FILES_MATCHING
    PATTERN "*.json"
    PATTERN "*.bin"
    PATTERN "*.pb.txt"
    PATTERN "*manifest*" EXCLUDE
    PATTERN "logs" EXCLUDE
    PATTERN "graphs" EXCLUDE
    PATTERN "*dynhash*" EXCLUDE
    PATTERN "*prim*" EXCLUDE
    PATTERN "*src*" EXCLUDE
    PATTERN "*gen*" EXCLUDE
    PATTERN "*pd*" EXCLUDE
    PATTERN "*cli*" EXCLUDE
    PATTERN "*thrift*" EXCLUDE
  )
  list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/share/${p4target}pd/${t}")

  if(withpd)
    # install CLI files
    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/cli/xml/" DESTINATION "share/cli/xml"
      FILES_MATCHING
      PATTERN "*.xml"
    )
    # install python files
    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${target_path}/gen-py/" DESTINATION "${PYTHON3_SITE}/${p4target}pd/${t}"
      FILES_MATCHING
      PATTERN "*.py"
      PATTERN "*remote"
    )
    list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/${PYTHON3_SITE}/${p4target}pd/${t}")
    # install libs
    install(TARGETS ${t}-${p4target}-pd ${t}-${p4target}-pdcli DESTINATION "lib/${p4target}pd/${t}")
    if(withthrift)
      install(TARGETS ${t}-${p4target}-pdthrift DESTINATION "lib/${p4target}pd/${t}")
    endif()
    list(APPEND installed_dir "${CMAKE_INSTALL_PREFIX}/lib/${p4target}pd/${t}")
  endif()

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
