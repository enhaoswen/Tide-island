.pragma library

function normalizeUri(value) {
    const source = String(value || "");
    let match = /^spotify:track:([A-Za-z0-9]{22})$/.exec(source);
    if (!match)
        match = /^https:\/\/open\.spotify\.com\/(?:intl-[a-zA-Z-]+\/)?track\/([A-Za-z0-9]{22})(?:[?#].*)?$/.exec(source);
    if (!match)
        match = /^\/com\/spotify\/track\/([A-Za-z0-9]{22})$/.exec(source);
    return match ? "spotify:track:" + match[1] : "";
}

function isSpotifyPlayer(player) {
    if (!player) return false;
    const busName = String(player.dbusName || "");
    return /(?:^|\.)spotify(?:[.\-]|$)/i.test(busName)
        || (!busName && String(player.identity || "").toLowerCase() === "spotify");
}

function currentUri(player) {
    if (!isSpotifyPlayer(player) || !player.metadata) return "";
    return normalizeUri(player.metadata["xesam:url"])
        || normalizeUri(player.metadata["mpris:trackid"]);
}
