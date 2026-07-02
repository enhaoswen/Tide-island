pragma Singleton
import QtQuick

QtObject {
    readonly property color totalBgColor: "#faf9f5"
    readonly property color componentBgColor: "#e8e6dc"
    readonly property color cardBgColor: "#fffdf9"
    readonly property color cardBorderColor: "#e2cfc4"
    readonly property color tableHeaderBgColor: "#f6e7df"
    readonly property color tableFooterBgColor: "#f8ebe4"
    readonly property color inputBgColor: "#f7efe8"
    readonly property color inputBorderColor: "#dcc2b5"
    readonly property color focusBorderColor: "#c86a4b"
    readonly property color secondaryTextColor: "#6f665e"
    readonly property color subtleTextColor: "#8f857c"
    readonly property color textColor: "#141413"
    readonly property color splitLineColor: "#e8e6dc"
    readonly property color buttonColor: "#d97757"
    readonly property color buttonHoverColor: "#c96a49"
    readonly property color buttonTextColor: "#fffaf5"
    readonly property color mutedButtonColor: "#f1e3da"
    readonly property color mutedButtonTextColor: "#7b685d"
    readonly property color accentSoftColor: "#f4dfd5"
    readonly property color selectedColor: "#d97757"
    readonly property color overlayColor: "#5c443833"

    readonly property int animationDuration: 200

    readonly property string textFontFamily: textFont.status === FontLoader.Ready ? textFont.name : "Inter"
    readonly property string titleFontFamily: titleFont.status === FontLoader.Ready ? titleFont.name : "Serif"
    readonly property string interFontFamily: textFontFamily
    readonly property string loraFontFamily: titleFontFamily
    readonly property string fontFamily: textFontFamily

    readonly property FontLoader textFont: FontLoader {
        source: "qrc:/RES/InterVariable.ttf"
    }

    readonly property FontLoader titleFont: FontLoader {
        source: "qrc:/RES/Lora-Regular.ttf"
    }
}
