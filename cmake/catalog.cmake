include(${CMAKE_CURRENT_LIST_DIR}/internal/utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/recipe.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/internal/resolve.cmake)

function(_catalog_impl_repo REPO_SOURCE)
  _catalog_load_repo_meta(${REPO_SOURCE})
endfunction()

function(_catalog_impl_add_recipe PACKAGE_NAME RECIPE_SOURCE)
  _catalog_valid_target_name("${PACKAGE_NAME}" VALID_PKG)
  if(NOT VALID_PKG)
    _catalog_log(FATAL_ERROR "Invalid package name: ${PACKAGE_NAME}")
  endif()
  _catalog_add_recipe(${PACKAGE_NAME} ${RECIPE_SOURCE})
endfunction()

function(_catalog_impl_add_dependency FIRST_ARG)
  set(TARGET_NAME "")
  set(PACKAGE_NAME "${FIRST_ARG}")
  
  if(ARGC GREATER 1)
    set(TARGET_NAME "${FIRST_ARG}")
    set(PACKAGE_NAME "${ARGV1}")
  endif()
  
  _catalog_valid_target_name("${PACKAGE_NAME}" VALID_PKG)
  if(NOT VALID_PKG)
    _catalog_log(FATAL_ERROR "Invalid package name: ${PACKAGE_NAME}")
  endif()
  
  if(NOT TARGET_NAME STREQUAL "")
    _catalog_valid_target_name("${TARGET_NAME}" VALID_TARGET)
    if(NOT VALID_TARGET)
      _catalog_log(FATAL_ERROR "Invalid target name: ${TARGET_NAME}")
    endif()
  endif()
  
  _catalog_resolve_dependency(${PACKAGE_NAME})
  
  if(NOT TARGET_NAME STREQUAL "")
    if(TARGET ${TARGET_NAME})
      get_target_property(TARGET_TYPE ${TARGET_NAME} TYPE)
      if(TARGET_TYPE STREQUAL "INTERFACE_LIBRARY")
        set(LINK_SCOPE "INTERFACE")
      else()
        set(LINK_SCOPE "PRIVATE")
      endif()
      target_link_libraries(${TARGET_NAME} ${LINK_SCOPE} deps::${PACKAGE_NAME})
    else()
      _catalog_log(WARNING "Target does not exist: ${TARGET_NAME}")
    endif()
  endif()
endfunction()

function(_catalog_define_alias ALIAS_NAME TARGET_FUNC)
  if(NOT COMMAND "${ALIAS_NAME}")
    cmake_language(EVAL CODE "
macro(${ALIAS_NAME})
  ${TARGET_FUNC}(\${ARGN})
endmacro()
")
  endif()
endfunction()

function(_catalog_setup_aliases)
  set(FUNCTION_MAPPINGS
    "repo:_catalog_impl_repo"
    "add_recipe:_catalog_impl_add_recipe"
    "add_dependency:_catalog_impl_add_dependency"
    "add_dep:_catalog_impl_add_dependency"
    "import_source:_catalog_impl_import_source"
  )

  set(PREFIXES "catalog_" "cl_")

  if(DEFINED CATALOG_PREFIX AND NOT CATALOG_PREFIX STREQUAL "")
    string(TOLOWER "${CATALOG_PREFIX}" _LOW_PREF)
    if(NOT _LOW_PREF MATCHES "_$")
      string(APPEND _LOW_PREF "_")
    endif()
    list(FIND PREFIXES "${_LOW_PREF}" _P_IDX)
    if(_P_IDX EQUAL -1)
      list(APPEND PREFIXES "${_LOW_PREF}")
    endif()
  endif()

  foreach(MAP ${FUNCTION_MAPPINGS})
    string(REPLACE ":" ";" MAP_PAIR "${MAP}")
    list(GET MAP_PAIR 0 BASE_NAME)
    list(GET MAP_PAIR 1 IMPL_NAME)

    foreach(PREF ${PREFIXES})
      _catalog_define_alias("${PREF}${BASE_NAME}" "${IMPL_NAME}")
    endforeach()
  endforeach()
endfunction()

_catalog_setup_aliases()
