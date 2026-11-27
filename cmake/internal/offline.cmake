# Settings:
#   OFFLINE          ON: never touch the network. Downloads and git clones fail with a message that
#                    names the missing file; the package manager and prebuilt stages are skipped
#                    (unless STAGES is set explicitly); a cache that was filled beforehand (see
#                    VENDOR_DIR / CACHE_DIR) is used as is.
#   VENDOR_DIR       Use this directory as the cache (relative paths are relative to the top level
#                    source directory). Same as CACHE_DIR, which wins when both are set.
#   RECORD_SOURCES   Append every remote input that gets used (recipes, archives, git checkouts) to
#                    this file. tools/catalog-flatpak-sources.cmake turns it into flatpak-builder
#                    sources that recreate the cache without network access.

function(_catalog_is_offline RESULT_VAR)
  _catalog_get_var("OFFLINE" OFFLINE_VAL ENV)
  if(OFFLINE_VAL)
    set(${RESULT_VAR} TRUE PARENT_SCOPE)
  else()
    set(${RESULT_VAR} FALSE PARENT_SCOPE)
  endif()
endfunction()

function(_catalog_offline_fail WHAT EXPECTED_PATH)
  _catalog_get_cache_dir(_OFFLINE_CACHE)
  set(MSG "Offline mode: cannot fetch ${WHAT}.")
  if(NOT "${EXPECTED_PATH}" STREQUAL "")
    string(APPEND MSG "\n  It was expected in the cache at: ${EXPECTED_PATH}")
  endif()
  string(APPEND MSG "\n  Cache directory: ${_OFFLINE_CACHE}")
  string(APPEND MSG "\n  Fill the cache before going offline (configure once with network access and RECORD_SOURCES set, then run tools/catalog-flatpak-sources.cmake), or unset CATALOG_OFFLINE.")
  _catalog_log(FATAL_ERROR "${MSG}")
endfunction()

function(_catalog_record_source KIND NAME URL REF CACHE_NAME HASH)
  _catalog_get_var("RECORD_SOURCES" RECORD_FILE ENV)
  if("${RECORD_FILE}" STREQUAL "")
    return()
  endif()

  set(KEY "${KIND}|${URL}|${REF}|${CACHE_NAME}|${NAME}")
  get_property(SEEN GLOBAL PROPERTY _CATALOG_RECORDED_SOURCES)
  list(FIND SEEN "${KEY}" SEEN_IDX)
  if(NOT SEEN_IDX EQUAL -1)
    return()
  endif()
  set_property(GLOBAL APPEND PROPERTY _CATALOG_RECORDED_SOURCES "${KEY}")

  foreach(FIELD NAME REF HASH)
    if("${${FIELD}}" STREQUAL "")
      set(${FIELD} "-")
    endif()
  endforeach()

  get_filename_component(RECORD_DIR "${RECORD_FILE}" DIRECTORY)
  if(NOT "${RECORD_DIR}" STREQUAL "")
    file(MAKE_DIRECTORY "${RECORD_DIR}")
  endif()
  file(APPEND "${RECORD_FILE}" "${KIND}\t${NAME}\t${URL}\t${REF}\t${CACHE_NAME}\t${HASH}\n")
endfunction()

function(_catalog_record_cached_file KIND NAME URL CACHE_FILE)
  _catalog_get_var("RECORD_SOURCES" RECORD_FILE ENV)
  if("${RECORD_FILE}" STREQUAL "" OR NOT EXISTS "${CACHE_FILE}")
    return()
  endif()
  file(SHA256 "${CACHE_FILE}" FILE_HASH)
  get_filename_component(CACHE_NAME "${CACHE_FILE}" NAME)
  _catalog_record_source("${KIND}" "${NAME}" "${URL}" "" "${CACHE_NAME}" "${FILE_HASH}")
endfunction()

function(_catalog_record_git_checkout KIND NAME URL REF CHECKOUT_DIR)
  _catalog_get_var("RECORD_SOURCES" RECORD_FILE ENV)
  if("${RECORD_FILE}" STREQUAL "")
    return()
  endif()
  set(COMMIT "")
  if(EXISTS "${CHECKOUT_DIR}/.git")
    execute_process(
      COMMAND git rev-parse HEAD
      WORKING_DIRECTORY "${CHECKOUT_DIR}"
      OUTPUT_VARIABLE COMMIT
      RESULT_VARIABLE COMMIT_RES
      ERROR_QUIET
      OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(NOT COMMIT_RES EQUAL 0)
      set(COMMIT "")
    endif()
  endif()
  get_filename_component(CACHE_NAME "${CHECKOUT_DIR}" NAME)
  _catalog_record_source("${KIND}" "${NAME}" "${URL}" "${REF}" "${CACHE_NAME}" "${COMMIT}")
endfunction()

function(_catalog_repo_override GH_USER GH_REPO RESULT_VAR)
  set(${RESULT_VAR} "" PARENT_SCOPE)
  set(SUFFIX "${GH_USER}_${GH_REPO}")
  string(REGEX REPLACE "[^A-Za-z0-9_]" "_" SUFFIX "${SUFFIX}")
  _catalog_get_var("REPO_OVERRIDE_${SUFFIX}" DIR_VAL ENV)
  if("${DIR_VAL}" STREQUAL "")
    return()
  endif()
  get_filename_component(DIR_VAL "${DIR_VAL}" ABSOLUTE BASE_DIR "${CMAKE_SOURCE_DIR}")
  if(NOT IS_DIRECTORY "${DIR_VAL}")
    _catalog_log(FATAL_ERROR "REPO_OVERRIDE_${SUFFIX} points to a directory that does not exist: ${DIR_VAL}")
  endif()
  set(${RESULT_VAR} "${DIR_VAL}" PARENT_SCOPE)
endfunction()
