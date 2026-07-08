cmake_minimum_required(VERSION 3.16)
project(TideIsland VERSION 1.0.19 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network DBus Test Concurrent)
find_library(UDEV_LIB NAMES udev REQUIRED)

add_executable(lyricsmpris
    lyricsmpris/main.cpp
    lyricsmpris/CjkVariantNormalizer.h
    lyricsmpris/CjkVariantNormalizer.cpp
    lyricsmpris/LyricsCore.h
    lyricsmpris/LyricsCore.cpp
    lyricsmpris/LyricsMprisApp.h
    lyricsmpris/LyricsMprisApp.cpp
)

target_include_directories(lyricsmpris PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/lyricsmpris
)

target_link_libraries(lyricsmpris PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::DBus
)

enable_testing()

add_executable(lyricsmpris_tests
    tests/lyricsmpris_core_tests.cpp
    lyricsmpris/CjkVariantNormalizer.h
    lyricsmpris/CjkVariantNormalizer.cpp
    lyricsmpris/LyricsCore.h
    lyricsmpris/LyricsCore.cpp
)

target_include_directories(lyricsmpris_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/lyricsmpris
)

target_link_libraries(lyricsmpris_tests PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME lyricsmpris_core COMMAND lyricsmpris_tests)

add_executable(user_config_backend_tests
    tests/user_config_backend_tests.cpp
    backend/UserConfigBackend.h
    backend/UserConfigBackend.cpp
)

target_include_directories(user_config_backend_tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)

target_link_libraries(user_config_backend_tests PRIVATE
    Qt6::Core
    Qt6::Qml
    Qt6::Test
)

add_test(NAME user_config_backend COMMAND user_config_backend_tests)

add_subdirectory(Tide-island-app)

# Main Backend Module (Combining all C++ components)
qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    SOURCES
        backend/SysBackend.h
        backend/SysBackend.cpp
        backend/SystemServices.h
        backend/SystemServices.cpp
        backend/StyleTokensBackend.h
        backend/StyleTokensBackend.cpp
        backend/UserConfigBackend.h
        backend/UserConfigBackend.cpp
        backend/BluetoothPairingAgent.h
        backend/BluetoothPairingAgent.cpp
        backend/WifiController.h
        backend/WifiController.cpp
        backend/WifiNetworkModel.h
        backend/WifiNetworkModel.cpp
)

target_include_directories(IslandBackend PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)

target_link_libraries(IslandBackend PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Network
    Qt6::DBus
    Qt6::Concurrent
    ${UDEV_LIB}
)

# Installation Rules
include(GNUInstallDirs)

# Install Quickshell entry points and QML component folders to /usr/share/tide-island
install(FILES
    shell.qml
    DynamicIslandWindow.qml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island
)
install(DIRECTORY qml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island
    FILES_MATCHING PATTERN "*.qml"
)

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

# Install helper executables
install(TARGETS lyricsmpris
    RUNTIME DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island/bin
)

# Install desktop entry
install(FILES tide-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# Install systemd user service
install(FILES tide-island.service DESTINATION /usr/lib/systemd/user)
