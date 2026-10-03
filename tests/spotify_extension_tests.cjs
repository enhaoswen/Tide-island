const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const trackA = "spotify:track:0123456789ABCDEFGHIJKL";
const trackB = "spotify:track:abcdefghijklmnopqrstuv";
const source = fs.readFileSync(path.join(__dirname, "../integrations/spicetify/tide-island.js"), "utf8")
    .replace("/* TIDE_ISLAND_CONFIG */ null", JSON.stringify({ version: 1, endpoint: "ws://127.0.0.1:8976", token: "a".repeat(64) }));
const flush = async () => { for (let i = 0; i < 12; i++) await Promise.resolve(); };

function harness(overrides = {}) {
    let now = 0, nextTimer = 0;
    const timers = new Map();
    const connections = [], mutations = [], listeners = new Set();
    const item = { uri: trackA, metadata: { "collection.in_collection": "false" } };
    const player = {
        data: { item },
        addEventListener(_, listener) { listeners.add(listener); },
        removeEventListener(_, listener) { listeners.delete(listener); }
    };
    const library = {
        async add({ uris }) {
            mutations.push(["add", ...uris]);
            item.metadata["collection.in_collection"] = "true";
        },
        async remove({ uris }) {
            mutations.push(["remove", ...uris]);
            item.metadata["collection.in_collection"] = "false";
        },
        ...overrides
    };
    class Socket {
        static OPEN = 1;
        readyState = 0;
        messages = [];
        constructor(endpoint) { this.endpoint = endpoint; connections.push(this); }
        send(text) { this.messages.push(JSON.parse(text)); }
        close() { this.readyState = 3; this.onclose?.(); }
        open() { this.readyState = 1; this.onopen?.(); }
        receive(message) { this.onmessage?.({ data: JSON.stringify(message) }); }
    }
    const timeout = (callback, milliseconds, interval = false) => {
        const id = ++nextTimer;
        timers.set(id, { callback, at: now + milliseconds, milliseconds, interval });
        return id;
    };
    const context = vm.createContext({
        Spicetify: { Player: player, Platform: { LibraryAPI: library } },
        WebSocket: Socket,
        Date: class extends Date { static now() { return now; } },
        setTimeout: (callback, ms) => timeout(callback, ms),
        clearTimeout: id => timers.delete(id),
        setInterval: (callback, ms) => timeout(callback, ms, true),
        clearInterval: id => timers.delete(id)
    });
    vm.runInContext(source, context);
    const socket = connections[0];
    socket.open();
    socket.receive({ type: "welcome", version: 1 });
    return {
        context, socket, connections, player, item, library, mutations, listeners,
        command(uri = trackA, liked = true, id = "request-1", connection = socket) {
            connection.receive({ type: "setFavorite", uri, liked, id });
        },
        async advance(milliseconds) {
            const target = now + milliseconds;
            for (;;) {
                let earliest;
                for (const entry of timers) {
                    if (entry[1].at <= target && (!earliest || entry[1].at < earliest[1].at)) earliest = entry;
                }
                if (!earliest) break;
                const [id, timer] = earliest;
                now = timer.at;
                if (timer.interval) timer.at += timer.milliseconds;
                else timers.delete(id);
                timer.callback();
                await flush();
            }
            now = target;
            await flush();
        },
        dispose() { context.__tideIslandBridge.dispose(); }
    };
}

test("authenticates and publishes state; saves and removes explicit track URIs", async () => {
    const h = harness();
    assert.equal(h.socket.messages[0].type, "hello");
    assert.equal(h.socket.messages[0].token, "a".repeat(64));
    assert.equal(h.socket.messages[1].liked, false);
    h.command();
    await flush();
    assert.deepEqual(h.mutations, [["add", trackA]]);
    assert.equal(h.socket.messages.find(message => message.type === "result").ok, true);
    h.command(trackA, false, "request-2");
    await flush();
    assert.deepEqual(h.mutations[1], ["remove", trackA]);
    assert.equal(h.socket.messages.filter(message => message.type === "result").at(-1).liked, false);
    h.dispose();
});

test("stale songs and malformed commands cannot mutate the library", async () => {
    const h = harness();
    h.command(trackB);
    h.command(trackA, "true");
    h.command("spotify:episode:0123456789ABCDEFGHIJKL");
    await flush();
    assert.equal(h.mutations.length, 0);
    assert.equal(h.socket.messages.find(message => message.type === "result").ok, false);
    h.dispose();
});

test("a song change during a save does not mark the new song as liked", async () => {
    let resolveSave;
    const h = harness({ add: () => new Promise(resolve => { resolveSave = resolve; }) });
    h.command();
    h.player.data.item = { uri: trackB, metadata: { "collection.in_collection": "false" } };
    resolveSave();
    await flush();
    const result = h.socket.messages.find(message => message.type === "result");
    assert.equal(result.uri, trackA);
    assert.equal(result.ok, true);
    assert.equal(h.socket.messages.at(-1).uri, trackB);
    assert.equal(h.socket.messages.at(-1).liked, false);
    h.dispose();
});

test("network errors report failure without leaking Spotify response data", async () => {
    const h = harness({ add: async () => { throw new Error("Spotify response: secret-cookie-and-token"); } });
    h.command();
    await flush();
    const result = h.socket.messages.find(message => message.type === "result");
    assert.equal(result.ok, false);
    assert.ok(!JSON.stringify(h.socket.messages).includes("secret-cookie-and-token"));
    assert.equal(h.socket.messages.at(-1).liked, false);
    h.dispose();
});

test("missing metadata or missing library APIs disables favorites", () => {
    const h = harness();
    delete h.item.metadata["collection.in_collection"];
    for (const listener of h.listeners) listener();
    assert.equal(h.socket.messages.at(-1).liked, null);
    h.library.add = undefined;
    for (const listener of h.listeners) listener();
    assert.match(h.socket.messages.at(-1).error, /Update Spicetify/);
    h.dispose();
});

test("a timed-out mutation cannot overlap another write", async () => {
    let resolveSave;
    const h = harness({ add: () => new Promise(resolve => { resolveSave = resolve; }) });
    h.command();
    await h.advance(6001);
    assert.equal(h.socket.messages.find(message => message.type === "result").ok, false);
    h.command(trackA, false, "second");
    await flush();
    assert.match(h.socket.messages.find(message => message.id === "second").error, /still updating/);
    resolveSave();
    await flush();
    h.dispose();
});

test("reconnects after Tide Island restarts and cleans up on extension reload", async () => {
    const h = harness();
    h.socket.close();
    await h.advance(1000);
    assert.equal(h.connections.length, 2);
    h.connections[1].open();
    h.connections[1].receive({ type: "welcome", version: 1 });
    assert.equal(h.connections[1].messages.at(-1).type, "state");
    vm.runInContext(source, h.context);
    assert.equal(h.connections[1].readyState, 3);
    assert.equal(h.listeners.size, 1);
    h.dispose();
    await h.advance(15000);
    assert.equal(h.connections.length, 3);
    assert.equal(h.listeners.size, 0);
});
