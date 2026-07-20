cmake_minimum_required(VERSION 3.25)

project(Tide-island VERSION 1.0 LANGUAGES C CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)

pkg_check_modules(WAYLAND_CLIENT REQUIRED wayland-client)
pkg_check_modules(WAYLAND_EGL REQUIRED wayland-egl)
pkg_check_modules(HARFBUZZ REQUIRED harfbuzz)

find_package(OpenGL REQUIRED)

find_package(Freetype REQUIRED)

set(SRC 
    main.cpp 
    source/island.cpp
    source/wayland.cpp
    source/wlr-layer-shell-unstable-v1-protocol.c 
    source/xdg-shell-client-protocol.c
    source/renderer.cpp
    source/environment.cpp
    source/text_engine.cpp
    source/backend.cpp
    source/provider.cpp
)

add_executable(Tide-island ${SRC})

target_compile_definitions(Tide-island PRIVATE SOKOL_GLES3)

target_include_directories(Tide-island PRIVATE 
    include/
    source/shaders/
    ${WAYLAND_CLIENT_INCLUDE_DIRS}
    ${WAYLAND_EGL_INCLUDE_DIRS}
    ${OPENGL_INCLUDE_DIR}
    ${HARFBUZZ_INCLUDE_DIRS}
    ${FREETYPE_INCLUDE_DIRS}
)

target_link_libraries(Tide-island PRIVATE 
    ${WAYLAND_CLIENT_LIBRARIES}
    ${WAYLAND_EGL_LIBRARIES}
    ${HARFBUZZ_LIBRARIES}
    OpenGL::GLES3
    OpenGL::EGL
    Freetype::Freetype
)

target_compile_options(Tide-island PRIVATE -Wall -Wextra)

target_compile_options(Tide-island PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-deprecated-enum-enum-conversion>
)

target_compile_options(Tide-island PRIVATE
    -Wno-unused-but-set-variable
)
