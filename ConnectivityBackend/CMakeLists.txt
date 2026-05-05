cmake_minimum_required(VERSION 3.21)

project(ConnectivityBackend LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml)

qt_add_qml_module(ConnectivityBackend
    URI ConnectivityBackend
    VERSION 1.0
    SOURCES
        BluetoothPairingAgent.cpp
        BluetoothPairingAgent.h
        ConnectivityBackendPlugin.cpp
        ConnectivityBackendPlugin.h
        WifiController.cpp
        WifiController.h
        WifiNetworkModel.cpp
        WifiNetworkModel.h
)

target_link_libraries(ConnectivityBackend PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Qml
)

# Install ConnectivityBackend backing library to /usr/lib
install(TARGETS ConnectivityBackend
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install ConnectivityBackend plugin to Qt6 QML directory
install(TARGETS ConnectivityBackendplugin
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/ConnectivityBackend
)

install(FILES 
    ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/qt6/qml/ConnectivityBackend
)
