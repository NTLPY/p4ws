cmake_minimum_required(VERSION 3.1)
project(p4ws VERSION 1.0)

install(DIRECTORY "${CMAKE_SOURCE_DIR}/cmake/" DESTINATION "${CMAKE_INSTALL_PREFIX}/share/cmake/${PROJECT_NAME}"
  FILES_MATCHING
  PATTERN "*.cmake"
)
