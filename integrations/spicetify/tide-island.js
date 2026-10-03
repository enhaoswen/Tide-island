// Installed by tide-island-spotify-setup. This token authenticates only the local
// bridge; no Spotify password, cookie, or access token is exported to Tide Island.
(() => {
    "use strict";
    const config = /* TIDE_ISLAND_CONFIG */ null;
    if (!config || config.version !== 1) return;
    // Spicetify can reload extensions without restarting Spotify.
    globalThis.__tideIslandBridge?.dispose();

    let disposed = false;
    let socket = null;
    let welcomed = false;
    let reconnectTimer = null;
    let reconnectDelay = 1000;
    let pollTimer = null;
    let startTimer = null;
    let lastState = "";
    let lastSentAt = 0;
    let mutationInFlight = false;
    let commandActive = false;
    const trackPattern = /^spotify:track:[A-Za-z0-9]{22}$/;
    class FavoriteError extends Error {}
    const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

    function readState() {
        const item = Spicetify.Player.data?.item;
        const uri = item?.uri || "";
        if (!trackPattern.test(uri)) return { type: "state", uri: "", liked: null };
        const value = item.metadata?.["collection.in_collection"];
        const liked = value === "true" || value === true ? true
            : value === "false" || value === false ? false : null;
        const library = Spicetify.Platform?.LibraryAPI;
        const supported = typeof library?.add === "function" && typeof library?.remove === "function";
        return {
            type: "state", uri, liked: supported ? liked : null,
            error: supported ? "" : "Spotify favorites are unavailable. Update Spicetify."
        };
    }

    function send(message, target = socket) {
        if (!disposed && target?.readyState === WebSocket.OPEN)
            target.send(JSON.stringify(message));
    }

    function publish(force = false) {
        if (disposed || !welcomed || commandActive) return;
        const state = JSON.stringify(readState());
        // Poll local player metadata, not Spotify's network APIs. Unchanged state
        // still acts as a heartbeat so stale connections cannot enable the button.
        if (force || state !== lastState || Date.now() - lastSentAt >= 3000) {
            send(JSON.parse(state));
            lastState = state;
            lastSentAt = Date.now();
        }
    }

    async function withTimeout(promise, milliseconds) {
        let timer;
        try {
            return await Promise.race([promise, new Promise((_, reject) => {
                timer = setTimeout(() => reject(new FavoriteError("Spotify did not confirm the favorite. Try again.")), milliseconds);
            })]);
        } finally {
            clearTimeout(timer);
        }
    }

    async function setFavorite(command, connection) {
        if (typeof command.id !== "string" || command.id.length > 64
                || !trackPattern.test(command.uri) || typeof command.liked !== "boolean") return;
        const reply = { type: "result", id: command.id, uri: command.uri, ok: false };
        const current = readState();
        if (commandActive || mutationInFlight) {
            send({ ...reply, error: "Spotify is still updating a favorite. Please wait." }, connection);
            return;
        }
        if (current.uri !== command.uri || current.liked === null) {
            send({ ...reply, error: "The song changed or its favorite state is unavailable. Try again." }, connection);
            publish(true);
            return;
        }
        commandActive = true;
        try {
            const library = Spicetify.Platform.LibraryAPI;
            // Use an explicit URI and desired state. Player.setHeart() operates on
            // whichever song is current and does not return the mutation promise.
            const mutation = library[command.liked ? "add" : "remove"]({ uris: [command.uri] });
            if (!mutation || typeof mutation.then !== "function")
                throw new FavoriteError("Spotify favorites could not be confirmed. Update Spicetify.");
            mutationInFlight = true;
            const settled = Promise.resolve(mutation).finally(() => { mutationInFlight = false; });
            await withTimeout(settled, 6000);
            // Await Spotify's metadata update before changing the displayed heart.
            for (let attempt = 0; attempt < 20; attempt++) {
                const state = readState();
                if (state.uri !== command.uri || state.liked === command.liked) {
                    send({ ...reply, ok: true, liked: command.liked }, connection);
                    return;
                }
                await delay(100);
            }
            throw new FavoriteError("Spotify did not refresh the favorite state. Try again.");
        } catch (error) {
            // Never forward Spotify response bodies or credentials into the bridge.
            const message = error instanceof FavoriteError
                ? error.message : "Could not update Spotify favorites. Check your connection and try again.";
            send({ ...reply, error: message }, connection);
        } finally {
            commandActive = false;
            publish(true);
        }
    }

    function scheduleReconnect() {
        if (disposed || reconnectTimer) return;
        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connect();
        }, reconnectDelay);
        reconnectDelay = Math.min(reconnectDelay * 2, 10000);
    }

    function connect() {
        if (disposed) return;
        let connection;
        try {
            connection = new WebSocket(config.endpoint);
        } catch (_) {
            scheduleReconnect();
            return;
        }
        socket = connection;
        const handshakeTimer = setTimeout(() => connection.close(), 5000);
        connection.onopen = () => send({ type: "hello", version: 1, token: config.token }, connection);
        connection.onmessage = event => {
            if (disposed || connection !== socket) return;
            let message;
            try { message = JSON.parse(event.data); } catch (_) { return; }
            if (message.type === "welcome" && message.version === 1) {
                clearTimeout(handshakeTimer);
                welcomed = true;
                reconnectDelay = 1000;
                publish(true);
            } else if (welcomed && message.type === "setFavorite") {
                void setFavorite(message, connection);
            }
        };
        connection.onerror = () => connection.close();
        connection.onclose = () => {
            clearTimeout(handshakeTimer);
            if (connection !== socket) return;
            welcomed = false;
            socket = null;
            lastState = "";
            scheduleReconnect();
        };
    }

    function start() {
        if (disposed) return;
        if (!globalThis.Spicetify?.Player?.addEventListener || !Spicetify.Platform) {
            startTimer = setTimeout(start, 500);
            return;
        }
        Spicetify.Player.addEventListener("songchange", onSongChange);
        pollTimer = setInterval(() => publish(), 1000);
        connect();
    }
    function onSongChange() { publish(true); }

    globalThis.__tideIslandBridge = {
        dispose() {
            disposed = true;
            clearTimeout(startTimer);
            clearTimeout(reconnectTimer);
            clearInterval(pollTimer);
            globalThis.Spicetify?.Player?.removeEventListener?.("songchange", onSongChange);
            socket?.close();
        }
    };
    start();
})();
