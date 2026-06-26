import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: backend

    signal translateResponseReceived(string result)
    signal translateErrorReceived(string error)

    property bool translateLoading: false

    function translate(text, sourceLang, targetLang) {
        if (text.trim() === "")
            return;
        if (backend.translateLoading)
            return;
        backend.translateLoading = true;

        const encoded = encodeURIComponent(text);
        const langPair = sourceLang + "|" + targetLang;
        const url = "https://api.mymemory.translated.net/get?q=" + encoded + "&langpair=" + langPair;

        translateProcess.command = ["curl", "-s", url];
        translateProcess.running = true;
    }

    property var translateProcess: Process {
        property string output: ""
        stdout: SplitParser {
            onRead: data => translateProcess.output += data
        }
        onExited: {
            backend.translateLoading = false;
            const raw = translateProcess.output;
            translateProcess.output = "";
            try {
                const parsed = JSON.parse(raw);
                if (parsed.responseStatus === 200) {
                    backend.translateResponseReceived(parsed.responseData.translatedText);
                } else {
                    backend.translateErrorReceived(parsed.responseDetails || "Translation failed");
                }
            } catch (e) {
                backend.translateErrorReceived("Failed to parse response");
            }
        }
    }
}
