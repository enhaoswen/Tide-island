// Exercise the unmodified extension against the actual Qt WebSocket backend,
// replacing only Spotify's authenticated library API with a local fixture.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const item = {
    uri: "spotify:track:0123456789ABCDEFGHIJKL",
    metadata: { "collection.in_collection": "false" }
};
globalThis.Spicetify = {
    Player: { data: { item }, addEventListener() {}, removeEventListener() {} },
    Platform: {
        LibraryAPI: {
            async add({ uris }) {
                if (uris[0] !== item.uri) throw new Error("Unexpected track");
                item.metadata["collection.in_collection"] = "true";
            },
            async remove({ uris }) {
                if (uris[0] !== item.uri) throw new Error("Unexpected track");
                item.metadata["collection.in_collection"] = "false";
            }
        }
    }
};
const config = { version: 1, endpoint: `ws://127.0.0.1:${process.argv[2]}`, token: process.argv[3] };
const source = fs.readFileSync(path.join(__dirname, "../integrations/spicetify/tide-island.js"), "utf8")
    .replace("/* TIDE_ISLAND_CONFIG */ null", JSON.stringify(config));
vm.runInThisContext(source);
process.on("SIGTERM", () => {
    globalThis.__tideIslandBridge.dispose();
    process.exit(0);
});
