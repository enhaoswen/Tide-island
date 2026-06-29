cmake_minimum_required(VERSION 3.16)
project(Tide-island-config-app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Gui Quick QuickControls2)

if (QT_KNOWN_POLICY_QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()

qt_add_executable(Tide-island-config-app
    main.cpp
    resources.qrc
)

target_link_libraries(Tide-island-config-app PRIVATE
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
)

set_source_files_properties(Theme.qml PROPERTIES
    QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(Tide-island-config-app
    URI Theme
    VERSION 1.0

    QML_FILES
        Theme.qml
)
