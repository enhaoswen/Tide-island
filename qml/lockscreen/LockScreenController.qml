pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import IslandBackend
import "../island"
import "../common/SpotifyTrack.js" as SpotifyTrack

Scope {
    id: root
    property var weatherService: null
    readonly property bool locked: sessionLock.locked
    readonly property bool secure: sessionLock.secure
    property bool savedWatchFiles: true
    property bool unlockAuthorized: false
    property bool capsLock: false
    property bool capsProbePending: false
    signal lockFailed(string reason)
    signal clearInputs()

    function lock() {
        if (sessionLock.locked) return;
        UserConfig.reload();
        savedWatchFiles = Quickshell.watchFiles;
        unlockAuthorized = false;
        // Do not hot-reload the password conversation while a user is typing.
        Quickshell.watchFiles = false;
        sessionLock.locked = true;
        acquisitionTimeout.restart();
    }

    // Keyboard LEDs mirror the compositor's lock state on every Linux backend, so
    // this works the same under Hyprland and niri without compositor IPC.
    function probeCapsLock() {
        if (!sessionLock.locked) return;
        if (capsProbe.running) capsProbePending = true;
        else capsProbe.running = true;
    }
    Process {
        id: capsProbe
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: root.capsLock = this.text.split("\n").some(line => line.trim() !== "" && line.trim() !== "0")
        }
        onRunningChanged: if (!running && root.capsProbePending) {
            root.capsProbePending = false;
            running = true;
        }
    }
    Timer { id: capsDebounce; interval: 40; onTriggered: root.probeCapsLock() }

    function runPowerAction(action) {
        // Only an established, secure lock may act; the view merely asks.
        if (!sessionLock.secure || root.unlockAuthorized || !(UserConfig.lockScreen.showPowerActions ?? true)) return;
        const commands = {
            suspend: ["systemctl", "suspend"],
            reboot: ["systemctl", "reboot"],
            poweroff: ["systemctl", "poweroff"]
        };
        if (commands[action]) Quickshell.execDetached(commands[action]);
    }

    PamContext { id: pamContext; config: "login" }
    LockScreenTransition {
        id: transition
        active: sessionLock.secure
        onExitFinished: {
            // The visual timeline has no authority to unlock on its own.
            if (root.unlockAuthorized && sessionLock.secure && sessionLock.locked)
                sessionLock.locked = false;
        }
    }
    LockAuthentication {
        id: authentication
        pam: pamContext
        successResult: PamResult.Success
        sessionLocked: sessionLock.secure
        onClearInputs: root.clearInputs()
        onAuthenticated: {
            if (sessionLock.secure && !root.unlockAuthorized) {
                root.unlockAuthorized = true;
                root.clearInputs();
                transition.beginExit();
            }
        }
    }
    Timer {
        id: acquisitionTimeout
        interval: 5000
        onTriggered: {
            if (!sessionLock.secure) {
                sessionLock.locked = false;
                Quickshell.watchFiles = root.savedWatchFiles;
                root.lockFailed("The compositor did not accept the session lock. Another locker may already be active.");
            }
        }
    }
    Loader {
        id: mediaLoader
        active: sessionLock.locked
        sourceComponent: IslandMprisController { expanded: true; clientId: "lock-screen" }
    }

    WlSessionLock {
        id: sessionLock
        onSecureChanged: if (secure) {
            acquisitionTimeout.stop();
            root.probeCapsLock();
        }
        onLockedChanged: {
            if (!locked) {
                root.capsLock = false;
                root.unlockAuthorized = false;
                authentication.cancel();
                root.clearInputs();
                Quickshell.watchFiles = root.savedWatchFiles;
            }
        }

        WlSessionLockSurface {
            id: surface
            color: StyleTokens.panel
            LockScreenView {
                id: view
                anchors.fill: parent
                settings: UserConfig.lockScreen
                styleTokens: StyleTokens
                interactive: sessionLock.secure && !root.unlockAuthorized
                entrance: transition.entrance
                departure: transition.departure
                unlocking: transition.exiting
                userName: Quickshell.env("USER") || "User"
                homePath: Quickshell.env("HOME")
                wallpaperPath: UserConfig.wallpaperPath
                textFont: UserConfig.textFontFamily
                timeFont: UserConfig.timeFontFamily
                busy: authentication.busy
                retryBlocked: authentication.retryBlocked
                authMessage: authentication.message
                authError: authentication.failed
                prompt: authentication.prompt
                responseVisible: authentication.responseVisible
                capsLock: root.capsLock

                readonly property var media: mediaLoader.item
                readonly property var player: media ? media.activePlayer : null
                readonly property string spotifyUri: SpotifyTrack.currentUri(player)
                trackTitle: media ? media.currentTrack : ""
                trackArtist: media ? media.currentArtist : ""
                albumArt: media ? media.currentArtUrl : ""
                playing: player !== null && player.playbackState === MprisPlaybackState.Playing
                canPlay: player !== null && player.canControl && (player.canTogglePlaying || (playing ? player.canPause : player.canPlay))
                canPrevious: player !== null && player.canControl && player.canGoPrevious
                canNext: player !== null && player.canControl && player.canGoNext
                canFavorite: SpotifyTrack.isSpotifyPlayer(player) && spotifyUri !== ""
                    && SpotifyBridge.connected && SpotifyBridge.stateKnown
                    && SpotifyBridge.trackUri === spotifyUri && !SpotifyBridge.busy
                favorite: canFavorite && SpotifyBridge.liked
                favoriteHint: canFavorite ? (favorite ? "Remove from favorites" : "Add to favorites") : "Favorite · requires connected Spotify"
                progress: media ? media.trackProgress : 0
                elapsed: media ? media.timePlayed : "0:00"
                duration: media ? media.timeTotal : "0:00"

                readonly property var weather: root.weatherService
                weatherReady: weather !== null && weather.weatherEnabled && weather.hasData
                weatherStale: weatherReady && weather.isStale
                temperature: weatherReady ? weather.tempString : "--"
                weatherCondition: weatherReady ? weather.condition : weather && !weather.weatherEnabled ? "Weather is disabled" : "Weather unavailable"
                weatherLocation: weatherReady ? weather.displayLocation : "Local weather"
                weatherType: weatherReady ? weather.weatherType : "cloudy"
                weatherRange: weatherReady ? weather.rangeString : ""
                feelsLike: weatherReady ? weather.feelsLikeString : "--"
                humidity: weatherReady ? weather.humidity + "%" : "--"
                hasBattery: SysBackend.batteryStatus !== "" && SysBackend.batteryStatus !== "Unknown" && SysBackend.batteryStatus !== "Not present"
                batteryPercent: SysBackend.batteryCapacity
                charging: SysBackend.batteryStatus === "Charging" || SysBackend.batteryStatus === "Full"

                onSubmitted: response => authentication.submit(response)
                onCancelAuthentication: authentication.cancel()
                onPreviousRequested: if (canPrevious) media.previous()
                onNextRequested: if (canNext) player.next()
                onPlayPauseRequested: {
                    if (!canPlay) return;
                    if (player.canTogglePlaying) player.togglePlaying();
                    else if (playing && player.canPause) player.pause();
                    else if (player.canPlay) player.play();
                }
                onFavoriteRequested: if (canFavorite) SpotifyBridge.setFavorite(spotifyUri, !favorite)
                onPowerRequested: action => root.runPowerAction(action)
                onInputActivity: capsDebounce.restart()

                Timer { interval: 1000; running: true; repeat: true; onTriggered: view.now = new Date() }
                Connections { target: root; function onClearInputs() { view.clearInput(); } }
                Connections {
                    target: surface
                    function onVisibleChanged() {
                        if (!surface.visible) return;
                        view.focusInput();
                        view.wake();
                        root.probeCapsLock();
                    }
                }
            }
        }
    }
}
