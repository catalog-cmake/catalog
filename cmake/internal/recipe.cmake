function(_catalog_impl_repo_file REL_PATH RESULT_VAR)
  if(REL_PATH MATCHES "^https?://" OR REL_PATH MATCHES "^/" OR EXISTS "${REL_PATH}")
    set(${RESULT_VAR} "${REL_PATH}" PARENT_SCOPE)
    return()
  endif()

  _catalog_get_var("REPO_BASE" BASE)
  if("${BASE}" STREQUAL "")
    _catalog_log(FATAL_ERROR "cl_repo_file: no repo context available for '${REL_PATH}' - call this from within a recipe stage function")
  endif()

  if(BASE MATCHES "^https?://")
    _catalog_load_repo_file("${BASE}/${REL_PATH}" LOCAL_PATH)
    set(${RESULT_VAR} "${LOCAL_PATH}" PARENT_SCOPE)
  else()
    set(${RESULT_VAR} "${BASE}/${REL_PATH}" PARENT_SCOPE)
  endif()
endfunction()

function(_catalog_find_target_alias PACKAGE_NAME RESULT_VAR)
  _catalog_get_var("REQ_TYPE" REQ_TYPE)
  if(REQ_TYPE STREQUAL "")
    _catalog_get_var("${PACKAGE_NAME}_REQ_TYPE" REQ_TYPE)
  endif()

  if(REQ_TYPE STREQUAL "STATIC" OR REQ_TYPE STREQUAL "PREFER_STATIC")
    set(CANDIDATES
      ${PACKAGE_NAME}::${PACKAGE_NAME}-static
      ${PACKAGE_NAME}::${PACKAGE_NAME}_static
      ${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}
      PkgConfig::${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}-shared
      ${PACKAGE_NAME}::${PACKAGE_NAME}_shared
    )
  elseif(REQ_TYPE STREQUAL "SHARED" OR REQ_TYPE STREQUAL "PREFER_SHARED")
    set(CANDIDATES
      ${PACKAGE_NAME}::${PACKAGE_NAME}-shared
      ${PACKAGE_NAME}::${PACKAGE_NAME}_shared
      ${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}
      PkgConfig::${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}-static
      ${PACKAGE_NAME}::${PACKAGE_NAME}_static
    )
  else()
    set(CANDIDATES
      ${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}
      ${PACKAGE_NAME}::${PACKAGE_NAME}-static
      ${PACKAGE_NAME}::${PACKAGE_NAME}_static
      ${PACKAGE_NAME}::${PACKAGE_NAME}-shared
      ${PACKAGE_NAME}::${PACKAGE_NAME}_shared
      PkgConfig::${PACKAGE_NAME}
    )
  endif()

  foreach(CANDIDATE ${CANDIDATES})
    if(TARGET ${CANDIDATE})
      get_target_property(TARGET_TYPE ${CANDIDATE} TYPE)
      
      if(REQ_TYPE STREQUAL "STATIC")
        if(TARGET_TYPE STREQUAL "SHARED_LIBRARY" OR TARGET_TYPE STREQUAL "MODULE_LIBRARY")
          continue()
        endif()
      elseif(REQ_TYPE STREQUAL "SHARED")
        if(TARGET_TYPE STREQUAL "STATIC_LIBRARY")
          continue()
        endif()
      endif()

      get_target_property(IS_ALIAS ${CANDIDATE} ALIASED_TARGET)
      if(IS_ALIAS)
        set(${RESULT_VAR} "${IS_ALIAS}" PARENT_SCOPE)
      else()
        set(${RESULT_VAR} "${CANDIDATE}" PARENT_SCOPE)
      endif()
      return()
    endif()
  endforeach()

  set(${RESULT_VAR} "" PARENT_SCOPE)
endfunction()

function(_catalog_impl_import_source)
  set(options DOWNLOAD_ONLY NO_EXTRACT)
  set(oneValueArgs NAME VERSION REPO URL REF)
  set(multiValueArgs OPTIONS PATCHES)
  cmake_parse_arguments(IMPORT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT IMPORT_NAME)
    _catalog_log(FATAL_ERROR "catalog_import_source: NAME is required")
  endif()

  if(NOT IMPORT_REPO AND NOT IMPORT_URL)
    _catalog_log(FATAL_ERROR "catalog_import_source: REPO or URL is required")
  endif()

  _catalog_get_cache_dir(CACHE_DIR)

  set(SHOULD_PATCH FALSE)

  _catalog_is_var_defined("REFRESH_${IMPORT_NAME}" SHOULD_REFRESH)

  if(IMPORT_REPO)
    if(NOT IMPORT_REF)
      set(IMPORT_REF "HEAD")
    endif()

    string(SHA256 SOURCE_HASH "${IMPORT_REPO}@${IMPORT_REF}")
    string(SUBSTRING "${SOURCE_HASH}" 0 12 SOURCE_HASH_SHORT)
    set(CHECKOUT_DIR "${CACHE_DIR}/src_${SOURCE_HASH_SHORT}")

    set(SOURCE_DIR "${CHECKOUT_DIR}")
    set(READY_STAMP "${CHECKOUT_DIR}/.catalog-patched")

    set(SKIP_CLONE FALSE)
    if(IMPORT_DOWNLOAD_ONLY AND IMPORT_NO_EXTRACT)
      set(SKIP_CLONE TRUE)
    endif()

    if(SHOULD_REFRESH AND EXISTS ${CHECKOUT_DIR})
      _catalog_log(STATUS "Refreshing cached checkout for ${IMPORT_NAME}...")
      file(REMOVE_RECURSE ${CHECKOUT_DIR})
    elseif(NOT SHOULD_REFRESH AND EXISTS ${CHECKOUT_DIR} AND NOT EXISTS ${READY_STAMP})
      _catalog_log(STATUS "Found incomplete cached checkout for ${IMPORT_NAME}, redoing...")
      file(REMOVE_RECURSE ${CHECKOUT_DIR})
    endif()

    if(NOT SKIP_CLONE)
      if(NOT EXISTS ${CHECKOUT_DIR}/.git)
        _catalog_log(STATUS "Cloning ${IMPORT_REPO}...")
        execute_process(
          COMMAND git clone ${IMPORT_REPO} ${CHECKOUT_DIR}
          RESULT_VARIABLE GIT_RESULT
          ERROR_VARIABLE GIT_ERROR
        )
        if(NOT GIT_RESULT EQUAL 0)
          _catalog_log(FATAL_ERROR "Failed to clone repository: ${GIT_ERROR}")
        endif()
        
        _catalog_log_verbose("Checking out ref ${IMPORT_REF}...")
        execute_process(
          COMMAND git checkout ${IMPORT_REF}
          WORKING_DIRECTORY ${CHECKOUT_DIR}
          RESULT_VARIABLE CHECKOUT_RESULT
          ERROR_VARIABLE CHECKOUT_ERROR
        )
        if(NOT CHECKOUT_RESULT EQUAL 0)
          _catalog_log(FATAL_ERROR "Failed to checkout ref ${IMPORT_REF}: ${CHECKOUT_ERROR}")
        endif()
        set(SHOULD_PATCH TRUE)
      endif()
    endif()
    
    _catalog_set_var("SOURCE_DIR" "${CHECKOUT_DIR}")
    _catalog_set_var("SOURCE_ARCHIVE" "")
    
  else()
    string(SHA256 URL_HASH "${IMPORT_URL}")
    string(SUBSTRING "${URL_HASH}" 0 12 URL_HASH_SHORT)
    set(ARCHIVE "${CACHE_DIR}/archive_${URL_HASH_SHORT}")
    set(EXTRACT_DIR "${CACHE_DIR}/src_${URL_HASH_SHORT}")
    set(READY_STAMP "${EXTRACT_DIR}/.catalog-patched")

    if(SHOULD_REFRESH)
      _catalog_log(STATUS "Refreshing cached download for ${IMPORT_NAME}...")
      if(EXISTS ${ARCHIVE})
        file(REMOVE ${ARCHIVE})
      endif()
      if(EXISTS ${EXTRACT_DIR})
        file(REMOVE_RECURSE ${EXTRACT_DIR})
      endif()
    elseif(EXISTS ${EXTRACT_DIR} AND NOT EXISTS ${READY_STAMP})
      _catalog_log(STATUS "Found incomplete cached extraction for ${IMPORT_NAME}, redoing...")
      file(REMOVE_RECURSE ${EXTRACT_DIR})
    endif()

    if(NOT EXISTS ${ARCHIVE})
      _catalog_download_file(${IMPORT_URL} ${ARCHIVE})
    endif()

    set(SOURCE_DIR "${EXTRACT_DIR}")
    
    set(SKIP_EXTRACT FALSE)
    if(IMPORT_DOWNLOAD_ONLY AND IMPORT_NO_EXTRACT)
      set(SKIP_EXTRACT TRUE)
    endif()
    
    if(NOT SKIP_EXTRACT)
      if(NOT EXISTS ${EXTRACT_DIR})
        _catalog_extract_archive(${ARCHIVE} ${EXTRACT_DIR})
        
        file(GLOB SUBDIRS "${EXTRACT_DIR}/*")
        list(LENGTH SUBDIRS SUBDIR_COUNT)
        
        if(SUBDIR_COUNT EQUAL 1)
          list(GET SUBDIRS 0 SUBDIR)
          if(IS_DIRECTORY ${SUBDIR})
            if(NOT "${SUBDIR}" STREQUAL "${EXTRACT_DIR}/src")
              file(RENAME ${SUBDIR} ${EXTRACT_DIR}/src)
            endif()
            set(SOURCE_DIR "${EXTRACT_DIR}/src")
          endif()
        endif()
        set(SHOULD_PATCH TRUE)
      else()
        if(EXISTS "${EXTRACT_DIR}/src" AND IS_DIRECTORY "${EXTRACT_DIR}/src")
          set(SOURCE_DIR "${EXTRACT_DIR}/src")
        endif()
      endif()
    endif()
    
    _catalog_set_var("SOURCE_DIR" "${SOURCE_DIR}")
    _catalog_set_var("SOURCE_ARCHIVE" "${ARCHIVE}")
    set(SOURCE_HASH_SHORT "${URL_HASH_SHORT}")
  endif()

  _catalog_get_var("${IMPORT_NAME}_PATCHES" PATCH_OVERRIDES)
  if(NOT "${PATCH_OVERRIDES}" STREQUAL "")
    set(IMPORT_PATCHES "${PATCH_OVERRIDES}")
  endif()

  if(SHOULD_PATCH AND IMPORT_PATCHES)
    foreach(PATCH_FILE ${IMPORT_PATCHES})
      if(NOT EXISTS "${PATCH_FILE}")
        _catalog_log(FATAL_ERROR "Patch file not found: ${PATCH_FILE}")
      endif()
      _catalog_log(STATUS "Applying patch ${PATCH_FILE}")
      execute_process(
        COMMAND patch -p1
        INPUT_FILE "${PATCH_FILE}"
        WORKING_DIRECTORY "${SOURCE_DIR}"
        RESULT_VARIABLE PATCH_RESULT
        ERROR_VARIABLE PATCH_ERR
      )
      if(NOT PATCH_RESULT EQUAL 0)
        _catalog_log(FATAL_ERROR "Failed to apply patch ${PATCH_FILE}: ${PATCH_ERR}")
      endif()
    endforeach()
  endif()

  if(SHOULD_PATCH)
    file(WRITE "${READY_STAMP}" "")
  endif()

  if(IMPORT_DOWNLOAD_ONLY)
    return()
  endif()

  list(LENGTH IMPORT_OPTIONS OPTIONS_LEN)
  set(INDEX 0)
  while(INDEX LESS OPTIONS_LEN)
    list(GET IMPORT_OPTIONS ${INDEX} ITEM)
    
    if(ITEM MATCHES "^([^ =]+)[ =](.+)$")
      set(OPTION_NAME "${CMAKE_MATCH_1}")
      set(OPTION_VALUE "${CMAKE_MATCH_2}")
      math(EXPR INDEX "${INDEX} + 1")
    else()
      set(OPTION_NAME "${ITEM}")
      math(EXPR VALUE_INDEX "${INDEX} + 1")
      if(VALUE_INDEX LESS OPTIONS_LEN)
        list(GET IMPORT_OPTIONS ${VALUE_INDEX} OPTION_VALUE)
      else()
        set(OPTION_VALUE "")
      endif()
      math(EXPR INDEX "${INDEX} + 2")
    endif()
    
    if(OPTION_NAME)
      set(${OPTION_NAME} "${OPTION_VALUE}")
      set(${OPTION_NAME} "${OPTION_VALUE}" PARENT_SCOPE)
    endif()
  endwhile()

  _catalog_get_var("${IMPORT_NAME}_OPTIONS" OPTION_OVERRIDES)
  list(LENGTH OPTION_OVERRIDES OVERRIDES_LEN)
  set(INDEX 0)
  while(INDEX LESS OVERRIDES_LEN)
    list(GET OPTION_OVERRIDES ${INDEX} ITEM)

    if(ITEM MATCHES "^([^ =]+)[ =](.+)$")
      set(OPTION_NAME "${CMAKE_MATCH_1}")
      set(OPTION_VALUE "${CMAKE_MATCH_2}")
      math(EXPR INDEX "${INDEX} + 1")
    else()
      set(OPTION_NAME "${ITEM}")
      math(EXPR VALUE_INDEX "${INDEX} + 1")
      if(VALUE_INDEX LESS OVERRIDES_LEN)
        list(GET OPTION_OVERRIDES ${VALUE_INDEX} OPTION_VALUE)
      else()
        set(OPTION_VALUE "")
      endif()
      math(EXPR INDEX "${INDEX} + 2")
    endif()

    if(OPTION_NAME)
      set(${OPTION_NAME} "${OPTION_VALUE}")
      set(${OPTION_NAME} "${OPTION_VALUE}" PARENT_SCOPE)
    endif()
  endwhile()

  if(NOT EXISTS "${SOURCE_DIR}/CMakeLists.txt")
    _catalog_log(FATAL_ERROR "No CMakeLists.txt found in source directory: ${SOURCE_DIR}. Did you mean to use DOWNLOAD_ONLY?")
  endif()

  set(BUILD_DIR "${CACHE_DIR}/build_${SOURCE_HASH_SHORT}")

  if(SHOULD_REFRESH AND EXISTS ${BUILD_DIR})
    file(REMOVE_RECURSE ${BUILD_DIR})
  endif()

  _catalog_get_var("REQ_TYPE" REQ_TYPE)
  if(REQ_TYPE STREQUAL "")
    _catalog_get_var("${IMPORT_NAME}_REQ_TYPE" REQ_TYPE)
  endif()

  if(REQ_TYPE STREQUAL "STATIC" OR REQ_TYPE STREQUAL "PREFER_STATIC")
    set(BUILD_SHARED_LIBS OFF)
  elseif(REQ_TYPE STREQUAL "SHARED" OR REQ_TYPE STREQUAL "PREFER_SHARED")
    set(BUILD_SHARED_LIBS ON)
  endif()

  if(NOT DEFINED CMAKE_POSITION_INDEPENDENT_CODE)
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)
  endif()

  _catalog_log_verbose(STATUS "Adding ${IMPORT_NAME} from source via add_subdirectory")
  add_subdirectory(${SOURCE_DIR} ${BUILD_DIR})
  
  _catalog_set_var("SOURCE_BUILD_DIR" "${BUILD_DIR}")
endfunction()
