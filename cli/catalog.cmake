if(CMAKE_VERSION VERSION_LESS 3.25)
  message(NOTICE "catalog: error: CMake 3.25 or newer is required (found ${CMAKE_VERSION})")
  message(FATAL_ERROR "")
endif()

cmake_policy(VERSION 3.25)

if(POLICY CMP0152)
  cmake_policy(SET CMP0152 NEW)
endif()

get_filename_component(CL_SELF "${CMAKE_CURRENT_LIST_FILE}" ABSOLUTE)

# --- bundle:core ---
set(CL_CORE_FILE "${CMAKE_CURRENT_LIST_DIR}/../cmake/catalog.cmake")
include("${CL_CORE_FILE}")
# --- end bundle:core ---

include(${CMAKE_CURRENT_LIST_DIR}/internal/util.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/manifest.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/probe.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/completion.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/commands.cmake)

if(NOT CL_AS_LIBRARY)
  set(_CL_ARGS "")
  set(_CL_SEEN_P FALSE)
  set(_CL_I 0)
  while(_CL_I LESS CMAKE_ARGC)
    if(_CL_SEEN_P)
      list(APPEND _CL_ARGS "${CMAKE_ARGV${_CL_I}}")
    elseif("${CMAKE_ARGV${_CL_I}}" STREQUAL "-P")
      set(_CL_SEEN_P TRUE)
      math(EXPR _CL_I "${_CL_I} + 1")
    endif()
    math(EXPR _CL_I "${_CL_I} + 1")
  endwhile()
  if(_CL_ARGS MATCHES "^--(;|$)")
    list(POP_FRONT _CL_ARGS)
  endif()

  _cl_main(${_CL_ARGS})
endif()
