###############################################################################
# Determine path of Barefoot SDE
###############################################################################

if((NOT DEFINED BFSDE) AND (DEFINED ENV{SDE}) AND (IS_DIRECTORY $ENV{SDE}))
  set(BFSDE "$ENV{SDE}")
endif()

if(DEFINED BFSDE)
  message("-- Check for Barefoot SDE: ${BFSDE}")
endif()

if((NOT DEFINED BFSDE_INSTALL) AND (DEFINED ENV{SDE_INSTALL}) AND (IS_DIRECTORY $ENV{SDE_INSTALL}))
  set(BFSDE_INSTALL "$ENV{SDE_INSTALL}")
endif()

if(DEFINED BFSDE_INSTALL)
  message("-- Check for Barefoot SDE Install: ${BFSDE_INSTALL}")
endif()


###############################################################################
# Find components
###############################################################################

function(find_bf_driver REQUIRED)
  find_library(BF_DRIVER driver PATH ${BFSDE_INSTALL}/lib ${ARGN})
  if(BF_DRIVER)
    message("-- Check for bf-driver: ${BF_DRIVER}")
  else()
    message("-- Check for bf-driver: not found")
    if(REQUIRED)
      message(FATAL_ERROR "bf-driver is required")
    endif()
  endif()
endfunction()

function(find_bf_p4c REQUIRED)
  find_program(BF_P4C bf-p4c PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_P4C)
    message("-- Check for bf-p4c: ${BF_P4C}")
  else()
    message("-- Check for bf-p4c: not found")
    if(REQUIRED)
      message(FATAL_ERROR "bf-p4c is required")
    endif()
  endif()
endfunction()

function(find_bf_pd REQUIRED)
  find_program(BF_PD_GEN generate_tofino_pd PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_PD_GEN)
    message("-- Check for bf-pd-gen: ${BF_PD_GEN}")
  else()
    message("-- Check for bf-pd-gen: not found")
  endif()

  find_program(BF_PD_GEN_CLI gencli PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_PD_GEN_CLI)
    message("-- Check for bf-pd-gen-cli: ${BF_PD_GEN_CLI}")
  else()
    message("-- Check for bf-pd-gen-cli: not found")
  endif()

  find_program(BF_PD_SPLIT split_pd_thrift.py PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_PD_SPLIT)
    message("-- Check for bf-pd-split: ${BF_PD_SPLIT}")
  else()
    message("-- Check for bf-pd-split: not found")
  endif()

  if(BF_PD_GEN AND BF_PD_GEN_CLI AND BF_PD_SPLIT)
    message("-- Check for bf-pd: found")
    set(BF_PD)
  else()
    message("-- Check for bf-pd: not found")
    if(REQUIRED)
      message(FATAL_ERROR "bf-pd is required")
    endif()
  endif()
endfunction()

function(find_bf_p4c_gen_bfrt_conf REQUIRED)
  find_program(BF_P4C_GEN_BFRT_CONF p4c-gen-bfrt-conf PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_P4C_GEN_BFRT_CONF)
    message("-- Check for p4c-gen-bfrt-conf: ${BF_P4C_GEN_BFRT_CONF}")
  else()
    message("-- Check for p4c-gen-bfrt-conf: not found")
  endif()
endfunction()

function(find_bf_p4c_manifest_config REQUIRED)
  find_program(BF_P4C_MANIFEST_CONFIG p4c-manifest-config PATH ${BFSDE_INSTALL}/bin ${ARGN})
  if(BF_P4C_MANIFEST_CONFIG)
    message("-- Check for p4c-manifest-config: ${BF_P4C_MANIFEST_CONFIG}")
  else()
    message("-- Check for p4c-manifest-config: not found")
  endif()
endfunction()

function(find_bf_thrift REQUIRED)
  set(THRIFT_HOME ${BFSDE_INSTALL})
  list(APPEND CMAKE_MODULE_PATH ${BFSDE}/cmake)
  find_package(Thrift ${ARGN})
  if(NOT THRIFT_FOUND AND REQUIRED)
    message(FATAL_ERROR "bf-thrift is required")
  endif()
  set(THRIFT_VERSION_STRING "${THRIFT_VERSION_STRING}" PARENT_SCOPE)
endfunction()
