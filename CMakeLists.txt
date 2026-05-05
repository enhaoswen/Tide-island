cmake_minimum_required(VERSION 3.16)
project(TideIsland VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml Network DBus)
find_library(UDEV_LIB NAMES udev REQUIRED)

# IslandBackend Module
qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    SOURCES
        SysBackend.h
        SysBackend.cpp
)

target_link_libraries(IslandBackend PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Network
    Qt6::DBus
    ${UDEV_LIB}
)

# ConnectivityBackend
add_subdirectory(ConnectivityBackend)

# Installation Rules
include(GNUInstallDirs)

# Install QML files to /usr/share/tide-island
file(GLOB QML_FILES "*.qml")
install(FILES ${QML_FILES} DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island)

# Install IslandBackend backing library to /usr/lib
install(TARGETS IslandBackend
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install IslandBackend plugin to Qt6 QML directory
install(TARGETS IslandBackendplugin
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Install qmldir and other generated files for IslandBackend
install(FILES 
    ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend.qmltypes
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
)


# Install launcher
install(PROGRAMS tide-island-launcher DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME tide-island)

# Install bin/lyricsmpris
install(DIRECTORY bin/ DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island/bin)

# Install desktop entry
install(FILES tide-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# Install systemd user service
install(FILES tide-island.service DESTINATION /usr/lib/systemd/user)
