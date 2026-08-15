function(_catalog_find_target_alias PACKAGE_NAME RESULT_VAR)
  set(CANDIDATES
    ${PACKAGE_NAME}
    ${PACKAGE_NAME}::${PACKAGE_NAME}
    ${PACKAGE_NAME}::${PACKAGE_NAME}-static
    ${PACKAGE_NAME}::${PACKAGE_NAME}-shared
    PkgConfig::${PACKAGE_NAME}
  )

  foreach(CANDIDATE ${CANDIDATES})
    if(TARGET ${CANDIDATE})
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

function(catalog_import_source)
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
  
  if(IMPORT_REPO)
    if(NOT IMPORT_REF)
      set(IMPORT_REF "HEAD")
    endif()
    
    string(SHA256 SOURCE_HASH "${IMPORT_REPO}@${IMPORT_REF}")
    string(SUBSTRING "${SOURCE_HASH}" 0 12 SOURCE_HASH_SHORT)
    set(CHECKOUT_DIR "${CACHE_DIR}/src_${SOURCE_HASH_SHORT}")
    
    set(SOURCE_DIR "${CHECKOUT_DIR}")
    
    set(SKIP_CLONE FALSE)
    if(IMPORT_DOWNLOAD_ONLY AND IMPORT_NO_EXTRACT)
      set(SKIP_CLONE TRUE)
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
    
    set(CATALOG_SOURCE_DIR "${CHECKOUT_DIR}" PARENT_SCOPE)
    set(CATALOG_SOURCE_ARCHIVE "" PARENT_SCOPE)
    
  else()
    string(SHA256 URL_HASH "${IMPORT_URL}")
    string(SUBSTRING "${URL_HASH}" 0 12 URL_HASH_SHORT)
    set(ARCHIVE "${CACHE_DIR}/archive_${URL_HASH_SHORT}")
    
    if(NOT EXISTS ${ARCHIVE})
      _catalog_download_file(${IMPORT_URL} ${ARCHIVE})
    endif()
    
    set(EXTRACT_DIR "${CACHE_DIR}/src_${URL_HASH_SHORT}")
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
    
    set(CATALOG_SOURCE_DIR "${SOURCE_DIR}" PARENT_SCOPE)
    set(CATALOG_SOURCE_ARCHIVE "${ARCHIVE}" PARENT_SCOPE)
    set(SOURCE_HASH_SHORT "${URL_HASH_SHORT}")
  endif()

  if(IMPORT_DOWNLOAD_ONLY)
    return()
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

  # Parse OPTIONS
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

  if(NOT EXISTS "${SOURCE_DIR}/CMakeLists.txt")
    _catalog_log(FATAL_ERROR "No CMakeLists.txt found in source directory: ${SOURCE_DIR}. Did you mean to use DOWNLOAD_ONLY?")
  endif()

  set(BUILD_DIR "${CACHE_DIR}/build_${SOURCE_HASH_SHORT}")
  
  _catalog_log_verbose(STATUS "Adding ${IMPORT_NAME} from source via add_subdirectory")
  add_subdirectory(${SOURCE_DIR} ${BUILD_DIR})
  
  set(CATALOG_SOURCE_BUILD_DIR "${BUILD_DIR}" PARENT_SCOPE)
endfunction()
