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

function(_catalog_parse_option_list OPTION_LIST RESULT_VAR)
  set(PAIRS "")
  list(LENGTH OPTION_LIST LEN)
  set(INDEX 0)
  while(INDEX LESS LEN)
    list(GET OPTION_LIST ${INDEX} ITEM)

    if(ITEM MATCHES "^([^ =]+)[ =](.+)$")
      set(OPTION_NAME "${CMAKE_MATCH_1}")
      set(OPTION_VALUE "${CMAKE_MATCH_2}")
      math(EXPR INDEX "${INDEX} + 1")
    else()
      set(OPTION_NAME "${ITEM}")
      math(EXPR VALUE_INDEX "${INDEX} + 1")
      if(VALUE_INDEX LESS LEN)
        list(GET OPTION_LIST ${VALUE_INDEX} OPTION_VALUE)
      else()
        set(OPTION_VALUE "")
      endif()
      math(EXPR INDEX "${INDEX} + 2")
    endif()

    if(OPTION_NAME)
      string(REPLACE ";" "__CATALOG_SEMI__" OPTION_VALUE "${OPTION_VALUE}")
      list(APPEND PAIRS "${OPTION_NAME}=${OPTION_VALUE}")
    endif()
  endwhile()
  set(${RESULT_VAR} "${PAIRS}" PARENT_SCOPE)
endfunction()

function(_catalog_split_option_pair PAIR NAME_VAR VALUE_VAR)
  string(FIND "${PAIR}" "=" EQ)
  string(SUBSTRING "${PAIR}" 0 ${EQ} NAME)
  math(EXPR EQ "${EQ} + 1")
  string(SUBSTRING "${PAIR}" ${EQ} -1 VALUE)
  string(REPLACE "__CATALOG_SEMI__" ";" VALUE "${VALUE}")
  set(${NAME_VAR} "${NAME}" PARENT_SCOPE)
  set(${VALUE_VAR} "${VALUE}" PARENT_SCOPE)
endfunction()

function(_catalog_has_install_hook NAME RESULT_VAR)
  if(COMMAND "_recipe_${NAME}_install")
    set(${RESULT_VAR} TRUE PARENT_SCOPE)
  else()
    set(${RESULT_VAR} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_catalog_append_install_log FILES)
  _catalog_get_var("INSTALL_LOG" INSTALL_LOG_VAL)
  if(NOT "${INSTALL_LOG_VAL}" STREQUAL "" AND NOT "${FILES}" STREQUAL "")
    string(REPLACE ";" "\n" TEXT "${FILES}")
    file(APPEND "${INSTALL_LOG_VAL}" "${TEXT}\n")
  endif()
endfunction()

function(_catalog_run_install_hook NAME SOURCE_DIR BUILD_DIR PREFIX BUILD_TYPE)
  _catalog_get_var("INSTALL_DESTDIR" DESTDIR_VAL)
  set(ROOT "${DESTDIR_VAL}${PREFIX}")

  _catalog_get_var_prefixes(_HOOK_PREFIXES)
  foreach(_P ${_HOOK_PREFIXES})
    set("${_P}SOURCE_DIR" "${SOURCE_DIR}")
    set("${_P}SOURCE_BUILD_DIR" "${BUILD_DIR}")
    set("${_P}INSTALL_PREFIX" "${PREFIX}")
    set("${_P}BUILD_TYPE" "${BUILD_TYPE}")
  endforeach()

  _catalog_log(STATUS "Installing ${NAME} into ${PREFIX} with the recipe's install function")
  set_property(GLOBAL PROPERTY _CATALOG_INSTALL_ROOT "${ROOT}")
  set_property(GLOBAL PROPERTY _CATALOG_INSTALLED_FILES "")
  cmake_language(CALL "_recipe_${NAME}_install" "${PREFIX}")
  get_property(INSTALLED_FILES GLOBAL PROPERTY _CATALOG_INSTALLED_FILES)
  set_property(GLOBAL PROPERTY _CATALOG_INSTALL_ROOT "")
  set_property(GLOBAL PROPERTY _CATALOG_INSTALLED_FILES "")

  _catalog_append_install_log("${INSTALLED_FILES}")
endfunction()

function(_catalog_impl_set_version VERSION)
  get_property(PACKAGE_NAME GLOBAL PROPERTY _CATALOG_CURRENT_PACKAGE)
  if("${PACKAGE_NAME}" STREQUAL "")
    _catalog_log(FATAL_ERROR "set_version: can only be used inside a recipe stage function")
  endif()
  string(REGEX REPLACE "[\r\n]+" " " VERSION "${VERSION}")
  string(STRIP "${VERSION}" VERSION)
  set_property(GLOBAL PROPERTY "_CATALOG_VERSION_${PACKAGE_NAME}" "${VERSION}")
endfunction()

function(_catalog_impl_install_files)
  get_property(ROOT GLOBAL PROPERTY _CATALOG_INSTALL_ROOT)
  if("${ROOT}" STREQUAL "")
    _catalog_log(FATAL_ERROR "install_files: can only be used inside a _recipe_<name>_install function")
  endif()

  cmake_parse_arguments(INST "" "DESTINATION" "" ${ARGN})
  if("${INST_DESTINATION}" STREQUAL "")
    _catalog_log(FATAL_ERROR "install_files: DESTINATION is required")
  endif()
  if(IS_ABSOLUTE "${INST_DESTINATION}" OR "/${INST_DESTINATION}/" MATCHES "/\\.\\./")
    _catalog_log(FATAL_ERROR "install_files: DESTINATION must be relative to the prefix and stay inside it (got '${INST_DESTINATION}')")
  endif()
  if(NOT INST_UNPARSED_ARGUMENTS)
    _catalog_log(FATAL_ERROR "install_files: nothing to install")
  endif()

  set(PERMISSION_ARGS USE_SOURCE_PERMISSIONS)
  if("PERMISSIONS" IN_LIST INST_UNPARSED_ARGUMENTS OR "USE_SOURCE_PERMISSIONS" IN_LIST INST_UNPARSED_ARGUMENTS)
    set(PERMISSION_ARGS "")
  endif()

  foreach(SOURCE_PATH ${INST_UNPARSED_ARGUMENTS})
    if(SOURCE_PATH MATCHES "^[A-Z_]+$")
      break()
    endif()
    get_filename_component(SOURCE_NAME "${SOURCE_PATH}" NAME)
    if(IS_DIRECTORY "${SOURCE_PATH}")
      set(DIR_PREFIX "${SOURCE_NAME}/")
      if(SOURCE_PATH MATCHES "/$")
        set(DIR_PREFIX "")
      endif()
      file(GLOB_RECURSE DIR_FILES RELATIVE "${SOURCE_PATH}" LIST_DIRECTORIES false "${SOURCE_PATH}/*")
      foreach(DIR_FILE ${DIR_FILES})
        file(REMOVE "${ROOT}/${INST_DESTINATION}/${DIR_PREFIX}${DIR_FILE}")
      endforeach()
    else()
      file(REMOVE "${ROOT}/${INST_DESTINATION}/${SOURCE_NAME}")
    endif()
  endforeach()

  set(CMAKE_INSTALL_MANIFEST_FILES "")
  file(INSTALL ${INST_UNPARSED_ARGUMENTS} ${PERMISSION_ARGS} DESTINATION "${ROOT}/${INST_DESTINATION}")

  get_property(RECORDED GLOBAL PROPERTY _CATALOG_INSTALLED_FILES)
  list(APPEND RECORDED ${CMAKE_INSTALL_MANIFEST_FILES})
  set_property(GLOBAL PROPERTY _CATALOG_INSTALLED_FILES "${RECORDED}")
endfunction()

function(_catalog_install_source NAME SOURCE_DIR BUILD_DIR INSTALL_PREFIX REQ_TYPE CONFIGURE_ARGS)
  _catalog_get_var("BUILD_TYPE" BUILD_TYPE_VAL)
  if("${BUILD_TYPE_VAL}" STREQUAL "")
    set(BUILD_TYPE_VAL "Release")
  endif()

  set(CFG "-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}" "-DCMAKE_BUILD_TYPE=${BUILD_TYPE_VAL}")

  if(REQ_TYPE STREQUAL "STATIC" OR REQ_TYPE STREQUAL "PREFER_STATIC")
    list(APPEND CFG "-DBUILD_SHARED_LIBS=OFF")
  elseif(REQ_TYPE STREQUAL "SHARED" OR REQ_TYPE STREQUAL "PREFER_SHARED")
    list(APPEND CFG "-DBUILD_SHARED_LIBS=ON")
  endif()

  _catalog_get_var("INSTALL_CMAKE_ARGS" EXTRA_CMAKE_ARGS)
  list(APPEND CFG ${EXTRA_CMAKE_ARGS})

  set(GEN_ARGS -G "${CMAKE_GENERATOR}")
  if(CMAKE_GENERATOR_PLATFORM)
    list(APPEND GEN_ARGS -A "${CMAKE_GENERATOR_PLATFORM}")
  endif()
  if(CMAKE_GENERATOR_TOOLSET)
    list(APPEND GEN_ARGS -T "${CMAKE_GENERATOR_TOOLSET}")
  endif()

  set(CONFIG_STAMP "${BUILD_DIR}.config")
  string(JOIN " " CONFIG_TEXT "${SOURCE_DIR}" ${GEN_ARGS} ${CFG} ${CONFIGURE_ARGS})
  set(OLD_CONFIG_TEXT "")
  if(EXISTS "${CONFIG_STAMP}")
    file(READ "${CONFIG_STAMP}" OLD_CONFIG_TEXT)
  endif()
  if(NOT "${OLD_CONFIG_TEXT}" STREQUAL "${CONFIG_TEXT}")
    if(EXISTS "${BUILD_DIR}")
      _catalog_log_verbose("Configuration of ${NAME} changed, rebuilding from scratch")
      file(REMOVE_RECURSE "${BUILD_DIR}")
    endif()
    file(WRITE "${CONFIG_STAMP}" "${CONFIG_TEXT}")
  endif()

  _catalog_log(STATUS "Configuring ${NAME} (install mode, prefix ${INSTALL_PREFIX})")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -S "${SOURCE_DIR}" -B "${BUILD_DIR}" ${GEN_ARGS} ${CFG} ${CONFIGURE_ARGS}
    RESULT_VARIABLE RES
  )
  if(NOT RES EQUAL 0)
    _catalog_log(FATAL_ERROR "Failed to configure ${NAME} for installation")
  endif()

  _catalog_log(STATUS "Building ${NAME}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${BUILD_DIR}" --config "${BUILD_TYPE_VAL}" --parallel
    RESULT_VARIABLE RES
  )
  if(NOT RES EQUAL 0)
    _catalog_log(FATAL_ERROR "Failed to build ${NAME}")
  endif()

  _catalog_has_install_hook("${NAME}" HAS_INSTALL_HOOK)
  if(HAS_INSTALL_HOOK)
    _catalog_run_install_hook("${NAME}" "${SOURCE_DIR}" "${BUILD_DIR}" "${INSTALL_PREFIX}" "${BUILD_TYPE_VAL}")
    if(NOT TARGET ${NAME})
      add_library(${NAME} INTERFACE IMPORTED GLOBAL)
    endif()
    return()
  endif()

  _catalog_log(STATUS "Installing ${NAME} into ${INSTALL_PREFIX}")
  _catalog_get_var("INSTALL_DESTDIR" DESTDIR_VAL)
  set(ENV_WRAPPER "")
  if(NOT "${DESTDIR_VAL}" STREQUAL "")
    set(ENV_WRAPPER "${CMAKE_COMMAND}" -E env "DESTDIR=${DESTDIR_VAL}")
  endif()
  execute_process(
    COMMAND ${ENV_WRAPPER} "${CMAKE_COMMAND}" --install "${BUILD_DIR}" --config "${BUILD_TYPE_VAL}"
    RESULT_VARIABLE RES
  )
  if(NOT RES EQUAL 0)
    _catalog_log(FATAL_ERROR "Failed to install ${NAME}")
  endif()

  _catalog_get_var("INSTALL_LOG" INSTALL_LOG_VAL)
  if(NOT "${INSTALL_LOG_VAL}" STREQUAL "" AND EXISTS "${BUILD_DIR}/install_manifest.txt")
    file(READ "${BUILD_DIR}/install_manifest.txt" INSTALLED_FILES)
    file(APPEND "${INSTALL_LOG_VAL}" "${INSTALLED_FILES}\n")
  endif()

  if(NOT TARGET ${NAME})
    add_library(${NAME} INTERFACE IMPORTED GLOBAL)
  endif()
endfunction()

function(_catalog_impl_import_source)
  set(options DOWNLOAD_ONLY NO_EXTRACT)
  set(oneValueArgs NAME VERSION REPO URL REF)
  set(multiValueArgs OPTIONS INSTALL_OPTIONS PATCHES)
  cmake_parse_arguments(IMPORT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT IMPORT_NAME)
    _catalog_log(FATAL_ERROR "catalog_import_source: NAME is required")
  endif()

  if(NOT IMPORT_REPO AND NOT IMPORT_URL)
    _catalog_log(FATAL_ERROR "catalog_import_source: REPO or URL is required")
  endif()

  _catalog_get_cache_dir(CACHE_DIR)

  if(IMPORT_VERSION)
    get_property(VERSION_RECORDED GLOBAL PROPERTY "_CATALOG_VERSION_${IMPORT_NAME}")
    if("${VERSION_RECORDED}" STREQUAL "")
      set_property(GLOBAL PROPERTY "_CATALOG_VERSION_${IMPORT_NAME}" "${IMPORT_VERSION}")
    endif()
  endif()

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

  _catalog_get_var("INSTALL_PREFIX" INSTALL_PREFIX_VAL)

  if(IMPORT_DOWNLOAD_ONLY)
    _catalog_has_install_hook("${IMPORT_NAME}" HAS_INSTALL_HOOK)
    if(NOT "${INSTALL_PREFIX_VAL}" STREQUAL "" AND HAS_INSTALL_HOOK)
      _catalog_run_install_hook("${IMPORT_NAME}" "${SOURCE_DIR}" "" "${INSTALL_PREFIX_VAL}" "")
      if(NOT TARGET ${IMPORT_NAME})
        add_library(${IMPORT_NAME} INTERFACE IMPORTED GLOBAL)
      endif()
    endif()
    return()
  endif()

  set(SOURCE_CONFIGURE_ARGS "")
  _catalog_parse_option_list("${IMPORT_OPTIONS}" OPTION_PAIRS)
  foreach(PAIR ${OPTION_PAIRS})
    _catalog_split_option_pair("${PAIR}" OPTION_NAME OPTION_VALUE)
    set(${OPTION_NAME} "${OPTION_VALUE}")
    set(${OPTION_NAME} "${OPTION_VALUE}" PARENT_SCOPE)
    string(REPLACE ";" "\\;" _OPTION_VALUE_ESC "${OPTION_VALUE}")
    list(APPEND SOURCE_CONFIGURE_ARGS "-D${OPTION_NAME}=${_OPTION_VALUE_ESC}")
  endforeach()

  if(NOT "${INSTALL_PREFIX_VAL}" STREQUAL "")
    _catalog_parse_option_list("${IMPORT_INSTALL_OPTIONS}" INSTALL_PAIRS)
    foreach(PAIR ${INSTALL_PAIRS})
      _catalog_split_option_pair("${PAIR}" OPTION_NAME OPTION_VALUE)
      string(REPLACE ";" "\\;" _OPTION_VALUE_ESC "${OPTION_VALUE}")
      list(APPEND SOURCE_CONFIGURE_ARGS "-D${OPTION_NAME}=${_OPTION_VALUE_ESC}")
    endforeach()
  endif()

  _catalog_get_var("${IMPORT_NAME}_OPTIONS" OPTION_OVERRIDES)
  _catalog_parse_option_list("${OPTION_OVERRIDES}" OVERRIDE_PAIRS)
  foreach(PAIR ${OVERRIDE_PAIRS})
    _catalog_split_option_pair("${PAIR}" OPTION_NAME OPTION_VALUE)
    set(${OPTION_NAME} "${OPTION_VALUE}")
    set(${OPTION_NAME} "${OPTION_VALUE}" PARENT_SCOPE)
    string(REPLACE ";" "\\;" _OPTION_VALUE_ESC "${OPTION_VALUE}")
    list(APPEND SOURCE_CONFIGURE_ARGS "-D${OPTION_NAME}=${_OPTION_VALUE_ESC}")
  endforeach()

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

  if(NOT "${INSTALL_PREFIX_VAL}" STREQUAL "")
    _catalog_install_source("${IMPORT_NAME}" "${SOURCE_DIR}" "${BUILD_DIR}-install" "${INSTALL_PREFIX_VAL}" "${REQ_TYPE}" "${SOURCE_CONFIGURE_ARGS}")
    return()
  endif()

  _catalog_log_verbose(STATUS "Adding ${IMPORT_NAME} from source via add_subdirectory")
  add_subdirectory(${SOURCE_DIR} ${BUILD_DIR})
  
  _catalog_set_var("SOURCE_BUILD_DIR" "${BUILD_DIR}")
endfunction()
