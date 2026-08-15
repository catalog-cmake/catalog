function(_recipe_SDL2_toolchain)
  if(EMSCRIPTEN)
    add_library(SDL2 INTERFACE)
    target_compile_options(SDL2 INTERFACE "-sUSE_SDL=2")
    target_link_options(SDL2 INTERFACE "-sUSE_SDL=2")
  endif()
endfunction()

function(_recipe_SDL2_system)
  if(NOT CMAKE_CROSSCOMPILING)
    find_package(SDL2 QUIET)
  endif()

  if(NOT SDL2_FOUND)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
      pkg_check_modules(SDL2 IMPORTED_TARGET GLOBAL "sdl2>=2.0.0")
    endif()
  endif()
endfunction()

function(_recipe_SDL2_package)
  if(CATALOG_PACKAGE_MANAGER STREQUAL "apt")
    set(CATALOG_PACKAGE_NAME "libsdl2-dev" PARENT_SCOPE)
  elseif(CATALOG_PACKAGE_MANAGER STREQUAL "pacman")
    set(CATALOG_PACKAGE_NAME "sdl2" PARENT_SCOPE)
  elseif(CATALOG_PACKAGE_MANAGER STREQUAL "brew")
    set(CATALOG_PACKAGE_NAME "sdl2" PARENT_SCOPE)
  elseif(CATALOG_PACKAGE_MANAGER STREQUAL "yum")
    set(CATALOG_PACKAGE_NAME "SDL2-devel" PARENT_SCOPE)
  elseif(CATALOG_PACKAGE_MANAGER STREQUAL "apk")
    set(CATALOG_PACKAGE_NAME "sdl2-dev" PARENT_SCOPE)
  elseif(CATALOG_PACKAGE_MANAGER STREQUAL "zypper")
    set(CATALOG_PACKAGE_NAME "libSDL2-devel" PARENT_SCOPE)
  endif()
endfunction()

function(_recipe_SDL2_source)
  catalog_import_source(
    NAME SDL2
    URL https://github.com/libsdl-org/SDL/archive/refs/tags/release-2.30.2.tar.gz
    OPTIONS "SDL_SHARED" "OFF" "SDL_STATIC" "ON" "SDL_TEST"   "OFF"
  )
endfunction()
