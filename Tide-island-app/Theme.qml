pragma Singleton
import QtQuick

QtObject {
    // Semantic mapping of the supplied settings-page reference.
    readonly property color totalBgColor: "#faf9f5"
    readonly property color componentBgColor: "#f0efe9"
    readonly property color cardBgColor: "#ffffff"
    readonly property color cardBorderColor: "#e8e6dd"
    readonly property color tableHeaderBgColor: "#f0efe9"
    readonly property color tableFooterBgColor: "#faf9f5"

    readonly property color inputBgColor: "#faf9f5"
    readonly property color inputHoverBgColor: "#faf9f5"
    readonly property color inputBorderColor: "#e8e6dd"
    readonly property color inputHoverBorderColor: "#e8e6dd"
    readonly property color focusBorderColor: "#cc785c"
    readonly property color focusRingColor: "#f3e7df"

    readonly property color textColor: "#1f1e1b"
    readonly property color secondaryTextColor: "#6b6a63"
    readonly property color subtleTextColor: "#6b6a63"
    readonly property color splitLineColor: "#e8e6dd"

    readonly property color buttonColor: "#cc785c"
    readonly property color buttonHoverColor: "#b4634a"
    readonly property color buttonPressedColor: "#a85740"
    readonly property color buttonTextColor: "#ffffff"
    readonly property color mutedButtonColor: "#ffffff"
    readonly property color mutedButtonHoverColor: "#f0efe9"
    readonly property color mutedButtonTextColor: "#1f1e1b"
    readonly property color controlHoverColor: "#f0efe9"
    readonly property color controlPressedColor: "#e8e6dd"

    readonly property color accentColor: "#cc785c"
    readonly property color accentDarkColor: "#b4634a"
    readonly property color accentSoftColor: "#f3e7df"
    readonly property color selectedColor: "#cc785c"
    readonly property color overlayColor: "#1f1e1b66"

    readonly property int animationDuration: 160

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
