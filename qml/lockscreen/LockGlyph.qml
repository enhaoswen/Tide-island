import QtQuick

Image {
    id: root
    property string name: "lock"
    property color ink: "#f5f5f7"
    property bool filled: false
    property real stroke: 1.7
    sourceSize: Qt.size(width * 2, height * 2)
    fillMode: Image.PreserveAspectFit
    smooth: true
    source: {
        const paths = {
            lock: '<rect x="5" y="10.5" width="14" height="10.5" rx="2.6"/><path d="M8 10.5V7.5a4 4 0 0 1 8 0v3"/>',
            unlock: '<rect x="5" y="10.5" width="14" height="10.5" rx="2.6"/><path d="M8 10.5V7.5a4 4 0 0 1 7.7-1.6"/>',
            arrow: '<path d="M5 12h14m-6-6 6 6-6 6"/>',
            previous: '<path d="M11 6.2v11.6a.6.6 0 0 1-1 .5L3.2 12.5a.6.6 0 0 1 0-1L10 5.7a.6.6 0 0 1 1 .5Zm9.5 0v11.6a.6.6 0 0 1-1 .5l-6.8-5.8a.6.6 0 0 1 0-1l6.8-5.8a.6.6 0 0 1 1 .5Z"/>',
            next: '<path d="M3.5 6.2v11.6a.6.6 0 0 0 1 .5l6.8-5.8a.6.6 0 0 0 0-1L4.5 5.7a.6.6 0 0 0-1 .5Zm9.5 0v11.6a.6.6 0 0 0 1 .5l6.8-5.8a.6.6 0 0 0 0-1l-6.8-5.8a.6.6 0 0 0-1 .5Z"/>',
            play: '<path d="M7 5.3v13.4a.8.8 0 0 0 1.2.7l10.9-6.7a.8.8 0 0 0 0-1.4L8.2 4.6a.8.8 0 0 0-1.2.7Z"/>',
            pause: '<rect x="6" y="4.5" width="4" height="15" rx="1.2"/><rect x="14" y="4.5" width="4" height="15" rx="1.2"/>',
            heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0l-1 1-1-1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z"/>',
            music: '<path d="M9 17V5l12-2v12M9 9l12-2"/><circle cx="6" cy="17" r="3"/><circle cx="18" cy="15" r="3"/>',
            sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2.5v2m0 15v2M2.5 12h2m15 0h2M5.3 5.3l1.4 1.4m10.6 10.6 1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>',
            partly: '<path d="M8.5 2.5v1.3M3.4 4.6l.9.9M1.8 9.7h1.3M13.6 4.6l-.9.9"/><path d="M5 12.6a4 4 0 1 1 7-3.9"/><path d="M8.6 20.5a3.6 3.6 0 0 1-.3-7.2 5.2 5.2 0 0 1 10 1.4 3 3 0 0 1-.4 5.8Z"/>',
            cloud: '<path d="M7 19a4.5 4.5 0 0 1-.4-9 6.5 6.5 0 0 1 12.5 1.9A3.6 3.6 0 0 1 18.4 19Z"/>',
            fog: '<path d="M5.5 11a6.5 6.5 0 0 1 12.8-1.4M3 14.5h18M5 18h14M8.5 21.5h7"/>',
            rain: '<path d="M7 15.5a4.2 4.2 0 0 1-.4-8.4 6 6 0 0 1 11.6 1.8 3.4 3.4 0 0 1-.5 6.6"/><path d="m9 18-1 3m5-3-1 3m5-3-1 3"/>',
            thunder: '<path d="M7 15.5a4.2 4.2 0 0 1-.4-8.4 6 6 0 0 1 11.6 1.8 3.4 3.4 0 0 1-.5 6.6"/><path d="m12.5 12-2.5 4.5h4L11.5 21"/>',
            snow: '<path d="M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5 12 7l2.5-2.5M9.5 19.5 12 17l2.5 2.5"/>',
            bolt: '<path d="m13 2-9 12h7l-1 8 10-13h-7Z"/>',
            user: '<circle cx="12" cy="8" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
            check: '<path d="m5 12.5 4.5 4.5L19 7"/>',
            eye: '<path d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12Z"/><circle cx="12" cy="12" r="3"/>',
            eyeOff: '<path d="m3.5 3.5 17 17"/><path d="M9.9 5.8A9.6 9.6 0 0 1 12 5.5c6 0 9.5 6.5 9.5 6.5a17 17 0 0 1-2.9 3.7M6.4 7.2C3.9 8.9 2.5 12 2.5 12S6 18.5 12 18.5c1.6 0 3-.4 4.2-1.1"/><path d="M9.9 9.9a3 3 0 0 0 4.2 4.2"/>',
            capslock: '<path d="M12 4.5 5 12h3.8v4.5h6.4V12H19Z"/><path d="M8.8 20h6.4"/>',
            power: '<path d="M12 3.5V12"/><path d="M6.6 6.8a7.5 7.5 0 1 0 10.8 0"/>',
            restart: '<path d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path d="M19.5 4.5v4.6h-4.6"/>',
            sleep: '<path d="M19.5 14.6A8 8 0 0 1 9.4 4.5a8 8 0 1 0 10.1 10.1Z"/>',
            spinner: '<path d="M12 3a9 9 0 1 1-9 9"/>'
        };
        return "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="'
            + (filled ? ink : 'none') + '" stroke="' + ink + '" stroke-width="' + stroke + '" stroke-linecap="round" stroke-linejoin="round">'
            + (paths[name] || paths.lock) + '</svg>');
    }
}
