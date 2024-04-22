###############################################################################
# Display Color
###############################################################################

if(NOT WIN32)
  string(ASCII 27 Esc)
  set(COLOR_RST  "${Esc}[m")
  set(COLOR_HINT "${Esc}[32m")
  set(COLOR_ERR  "${Esc}[1;31m")
  set(COLOR_WARN "${Esc}[1;33m")
  set(COLOR_INFO "${Esc}[1;36m")
endif()
