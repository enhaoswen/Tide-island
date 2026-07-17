cmake_minimum_required(VERSION 3.16)
project(tide-island-config-app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS
    Gui
    Qml
    Quick
    QuickControls2
    QuickDialogs2
    Test
)

qt_add_executable(tide-island-config-app
    main.cpp
    backend.hpp
    backend.cpp
    resources.qrc
)

target_link_libraries(tide-island-config-app PRIVATE
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickDialogs2
)

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/tests/shortcut_config_tests.cpp")
    add_executable(tide_island_shortcut_config_tests
        tests/shortcut_config_tests.cpp
        backend.hpp
        backend.cpp
    )

    target_include_directories(tide_island_shortcut_config_tests PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
    )

    target_link_libraries(tide_island_shortcut_config_tests PRIVATE
        Qt6::Gui
        Qt6::Test
    )

    add_test(NAME tide_island_shortcut_config COMMAND tide_island_shortcut_config_tests)
endif()

set_source_files_properties(Theme.qml ConfigStore.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(tide-island-config-app
    URI TideIsland
    VERSION 1.0

    QML_FILES
        Main.qml
        Theme.qml
        ConfigStore.qml
        PagePanel.qml
        ConfigTextField.qml
        General.qml
        CustomPage.qml
        Wallpaper.qml
        WallpaperSettings.qml
        TlpSettings.qml
        FontSettings.qml
        Interaction.qml
        Shortcut.qml
)

install(TARGETS tide-island-config-app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/TideIsland
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml
    PATTERN "*.qrc" EXCLUDE
)

install(FILES tide-island-config.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)
