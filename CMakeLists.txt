cmake_minimum_required(VERSION 3.21)

project(dynamic_island_tools LANGUAGES CXX)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/configurator/CMakeLists.txt")
    enable_testing()
    add_subdirectory(configurator)
else()
    message(STATUS "configurator/CMakeLists.txt not found; skipping configurator targets")
endif()
