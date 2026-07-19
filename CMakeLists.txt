cmake_minimum_required(VERSION 3.16)
project(TideIsland VERSION 1.0.25 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

option(TIDE_ISLAND_WITH_NIRI "Build niri compositor integration" ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Network DBus Test Concurrent)
find_library(UDEV_LIB NAMES udev REQUIRED)

add_executable(lyricsmpris
    lyricsmpris/main.cpp
    lyricsmpris/CjkVariantNormalizer.h
    lyricsmpris/CjkVariantNormalizer.cpp
    lyricsmpris/LyricsCore.h
    lyricsmpris/LyricsCore.cpp
    lyricsmpris/ProviderNetworkPolicy.h
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

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/lyricsmpris_core_tests.cpp")
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
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/user_config_backend_tests.cpp")
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
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/compositor_backend_tests.cpp")
    add_executable(compositor_backend_tests
        tests/compositor_backend_tests.cpp
        backend/CompositorBackend.h
        backend/CompositorBackend.cpp
    )

    target_include_directories(compositor_backend_tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/backend
    )

    target_compile_definitions(compositor_backend_tests PRIVATE
        TIDE_ISLAND_WITH_NIRI=$<BOOL:${TIDE_ISLAND_WITH_NIRI}>
    )

    target_link_libraries(compositor_backend_tests PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Network
        Qt6::Test
    )

    add_test(NAME compositor_backend COMMAND compositor_backend_tests)
endif()

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/lyricsmpris_runtime_tests.cpp")
    add_executable(lyricsmpris_runtime_tests
        tests/lyricsmpris_runtime_tests.cpp
    )

    target_link_libraries(lyricsmpris_runtime_tests PRIVATE
        Qt6::Core
        Qt6::DBus
        Qt6::Network
        Qt6::Test
    )

    target_include_directories(lyricsmpris_runtime_tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/lyricsmpris
    )

    add_dependencies(lyricsmpris_runtime_tests lyricsmpris)

    find_program(DBUS_RUN_SESSION_EXECUTABLE NAMES dbus-run-session REQUIRED)
    add_test(
        NAME lyricsmpris_runtime
        COMMAND "${DBUS_RUN_SESSION_EXECUTABLE}" --
            "${CMAKE_COMMAND}" -E env
            TIDE_ISLAND_RUNTIME_TEST_ISOLATED=1
            "LYRICSMPRIS_TEST_EXECUTABLE=$<TARGET_FILE:lyricsmpris>"
            "$<TARGET_FILE:lyricsmpris_runtime_tests>"
    )
    set_tests_properties(lyricsmpris_runtime PROPERTIES TIMEOUT 20)
endif()

add_subdirectory(Tide-island-app)

# Main Backend Module (Combining all C++ components)
qt_add_qml_module(IslandBackend
    URI IslandBackend
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend
    SOURCES
        backend/SysBackend.h
        backend/SysBackend.cpp
        backend/SystemServices.h
        backend/SystemServices.cpp
        backend/CompositorBackend.h
        backend/CompositorBackend.cpp
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

# The QML plugin is installed below lib/qt6/qml/IslandBackend while its backing
# library lives directly in lib. Keep installed packages independent of the
# build tree and make the relationship relocatable.
set_target_properties(IslandBackendplugin PROPERTIES
    INSTALL_RPATH "\$ORIGIN/../../.."
)

target_include_directories(IslandBackend PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/backend
)

target_compile_definitions(IslandBackend PRIVATE
    TIDE_ISLAND_WITH_NIRI=$<BOOL:${TIDE_ISLAND_WITH_NIRI}>
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
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/IslandBackend/IslandBackend.qmltypes
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/IslandBackend
)


# Install launcher
configure_file(tide-island-launcher ${CMAKE_CURRENT_BINARY_DIR}/tide-island @ONLY)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/tide-island DESTINATION ${CMAKE_INSTALL_BINDIR})

# Install helper executables
install(TARGETS lyricsmpris
    RUNTIME DESTINATION ${CMAKE_INSTALL_DATADIR}/tide-island/bin
)

# Install desktop entry
install(FILES tide-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# Install systemd user service
install(FILES tide-island.service DESTINATION lib/systemd/user)
