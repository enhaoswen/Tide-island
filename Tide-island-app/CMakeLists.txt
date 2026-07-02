cmake_minimum_required(VERSION 3.16)
project(tide-island-config-app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS
    Gui
    Qml
    Quick
    QuickControls2
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
)

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
        FontSettings.qml
        Document.qml
        Interaction.qml
        Shortcut.qml
)
