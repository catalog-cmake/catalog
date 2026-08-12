cmake_minimum_required(VERSION 3.18)
project(catalog-example C)

include(${CMAKE_CURRENT_SOURCE_DIR}/../cmake/catalog.cmake)

catalog_repo(${CMAKE_CURRENT_SOURCE_DIR}/recipes)

add_executable(example main.c)

catalog_add_dependency(example SDL2)
