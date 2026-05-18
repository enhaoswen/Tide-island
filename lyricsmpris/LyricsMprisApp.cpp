#include "LyricsMprisApp.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QDBusVariant>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTextStream>
#include <QUrlQuery>
#include <algorithm>
#include <cstdio>

namespace lyricsmpris {
namespace {

constexpr int kPrimaryFallbackDelayMs = 1800;
constexpr int kRefreshIntervalMs = 1500;
constexpr int kPositionIntervalMs = 350;
constexpr int kNetworkTimeoutMs = 7000;
constexpr int kDownloadCandidateLimit = 5;
constexpr qsizetype kMaxLocalLyricsSize = 1024 * 1024;

QStringList defaultProviders() {
    QStringList providers = {
        QStringLiteral("lrclib"),
        QStringLiteral("lrcx"),
        QStringLiteral("netease"),
        QStringLiteral("qq"),
        QStringLiteral("kugou")
    };
    if (!qEnvironmentVariable("MUSIXMATCH_API_KEY").isEmpty())
        providers.append(QStringLiteral("musixmatch"));
    return providers;
}

QStringList splitProviderList(QStringList providers) {
    if (providers.isEmpty()) providers = defaultProviders();
    QStringList normalized;
    for (const QString &providerList : providers) {
        const QStringList parts = providerList.split(QLatin1Char(','), Qt::SkipEmptyParts);
        for (QString part : parts) {
            part = part.trimmed().toLower();
            if (!part.isEmpty() && !normalized.contains(part)) normalized.append(part);
        }
    }
    return normalized;
}

bool isMprisService(const QString &service) {
    return service.startsWith(QStringLiteral("org.mpris.MediaPlayer2."));
}

QUrl withQuery(const QString &base, const QUrlQuery &query) {
    QUrl url(base);
    url.setQuery(query);
    return url;
}

QString makeSearchQuery(const TrackQuery &query) {
    return (query.title + QLatin1Char(' ') + query.artist).trimmed();
}

QByteArray safeBody(QNetworkReply *reply) {
    const QByteArray body = reply->readAll();
    return body.left(2 * 1024 * 1024);
}

bool lyricsDebugEnabled() {
    return !qEnvironmentVariableIsEmpty("LYRICSMPRIS_DEBUG");
}

} // namespace

LyricsMprisApp::LyricsMprisApp(AppOptions options, QObject *parent)
    : QObject(parent),
      m_options(std::move(options)) {
    m_options.providers = splitProviderList(m_options.providers);

    m_refreshTimer.setInterval(kRefreshIntervalMs);
    m_refreshTimer.setSingleShot(false);
    connect(&m_refreshTimer, &QTimer::timeout, this, &LyricsMprisApp::refreshPlayers);

    m_positionTimer.setInterval(kPositionIntervalMs);
    m_positionTimer.setSingleShot(false);
    connect(&m_positionTimer, &QTimer::timeout, this, &LyricsMprisApp::updatePosition);

    m_fallbackTimer.setInterval(kPrimaryFallbackDelayMs);
    m_fallbackTimer.setSingleShot(true);
    connect(&m_fallbackTimer, &QTimer::timeout, this, &LyricsMprisApp::startFallbackProviders);
}

void LyricsMprisApp::start() {
    if (m_options.lookupMode) {
        startLookup();
        return;
    }

    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(
        QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("/org/freedesktop/DBus"),
        QStringLiteral("org.freedesktop.DBus"),
        QStringLiteral("NameOwnerChanged"),
        this,
        SLOT(handleNameOwnerChanged(QString,QString,QString)));
    bus.connect(
        QString(),
        QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QStringLiteral("PropertiesChanged"),
        this,
        SLOT(handlePropertiesChanged(QString,QVariantMap,QStringList)));

    refreshPlayers();
    m_refreshTimer.start();
}

void LyricsMprisApp::startLookup() {
    PlayerInfo player;
    player.playbackStatus = QStringLiteral("Playing");
    player.title = m_options.lookupTitle;
    player.artist = m_options.lookupArtist;
    player.album = m_options.lookupAlbum;
    player.lengthMs = m_options.lookupDurationMs;
    player.trackId = QStringLiteral("lookup");
    player.valid = true;
    startTrack(player);
}

void LyricsMprisApp::refreshPlayers() {
    QDBusConnectionInterface *interface = QDBusConnection::sessionBus().interface();
    if (!interface) {
        emitStatus(QStringLiteral("error"));
        return;
    }

    QDBusReply<QStringList> namesReply = interface->registeredServiceNames();
    if (!namesReply.isValid()) {
        emitStatus(QStringLiteral("error"));
        return;
    }

    const QStringList services = namesReply.value();
    QSet<QString> seen;
    for (const QString &service : services) {
        if (!isMprisService(service) || serviceBlocked(service)) continue;
        seen.insert(service);
        updatePlayer(service);
    }

    const QList<QString> knownServices = m_players.keys();
    for (const QString &service : knownServices) {
        if (!seen.contains(service)) m_players.remove(service);
    }

    chooseActivePlayer();
}

void LyricsMprisApp::handleNameOwnerChanged(const QString &name, const QString &, const QString &) {
    if (isMprisService(name)) QTimer::singleShot(0, this, &LyricsMprisApp::refreshPlayers);
}

void LyricsMprisApp::handlePropertiesChanged(const QString &interfaceName, const QVariantMap &, const QStringList &) {
    if (interfaceName == QLatin1String("org.mpris.MediaPlayer2.Player"))
        QTimer::singleShot(0, this, &LyricsMprisApp::refreshPlayers);
}

void LyricsMprisApp::emitStatus(const QString &status) {
    if (status == m_lastStatus) return;
    m_lastStatus = status;

    QJsonObject object;
    object.insert(QStringLiteral("type"), QStringLiteral("status"));
    object.insert(QStringLiteral("status"), status);
    const QByteArray line = QJsonDocument(object).toJson(QJsonDocument::Compact);
    std::fwrite(line.constData(), 1, size_t(line.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

void LyricsMprisApp::emitLine(const QString &line, bool synced) {
    if (line == m_lastLine && synced == m_lastLineSynced) return;
    m_lastLine = line;
    m_lastLineSynced = synced;

    QJsonObject object;
    object.insert(QStringLiteral("type"), QStringLiteral("line"));
    object.insert(QStringLiteral("text"), line);
    object.insert(QStringLiteral("synced"), synced && !line.isEmpty());
    const QByteArray payload = QJsonDocument(object).toJson(QJsonDocument::Compact);
    std::fwrite(payload.constData(), 1, size_t(payload.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

void LyricsMprisApp::updatePlayer(const QString &service) {
    QDBusInterface properties(
        service,
        QStringLiteral("/org/mpris/MediaPlayer2"),
        QStringLiteral("org.freedesktop.DBus.Properties"),
        QDBusConnection::sessionBus());
    if (!properties.isValid()) return;

    QDBusMessage reply = properties.call(
        QStringLiteral("GetAll"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"));
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().isEmpty()) return;

    QVariantMap propertyMap = qdbus_cast<QVariantMap>(reply.arguments().first());
    PlayerInfo player = m_players.value(service);
    player.service = service;
    player.valid = true;
    player.playbackStatus = variantToString(propertyMap.value(QStringLiteral("PlaybackStatus")));
    if (player.playbackStatus == QLatin1String("Playing")) player.lastActive = QDateTime::currentDateTimeUtc();

    QVariantMap metadata = qdbus_cast<QVariantMap>(unwrapDbusVariant(propertyMap.value(QStringLiteral("Metadata"))));
    player.title = variantToString(metadata.value(QStringLiteral("xesam:title")));
    player.artist = variantToStringListText(metadata.value(QStringLiteral("xesam:artist")));
    player.album = variantToString(metadata.value(QStringLiteral("xesam:album")));
    player.url = variantToString(metadata.value(QStringLiteral("xesam:url")));
    player.trackId = variantToString(metadata.value(QStringLiteral("mpris:trackid")));
    player.lengthMs = variantToLongLong(metadata.value(QStringLiteral("mpris:length"))) / 1000;
    player.inlineLyrics = variantToString(metadata.value(QStringLiteral("xesam:asText")));
    if (player.inlineLyrics.isEmpty()) player.inlineLyrics = variantToString(metadata.value(QStringLiteral("xesam:comment")));

    QDBusMessage positionReply = properties.call(
        QStringLiteral("Get"),
        QStringLiteral("org.mpris.MediaPlayer2.Player"),
        QStringLiteral("Position"));
    if (positionReply.type() != QDBusMessage::ErrorMessage && !positionReply.arguments().isEmpty()) {
        player.positionMs = variantToLongLong(positionReply.arguments().first()) / 1000;
    }

    m_players.insert(service, player);
}

void LyricsMprisApp::chooseActivePlayer() {
    QString chosen;

    if (!m_options.preferredService.isEmpty() && m_players.contains(m_options.preferredService)) {
        chosen = m_options.preferredService;
    }

    if (chosen.isEmpty()) {
        for (auto it = m_players.cbegin(); it != m_players.cend(); ++it) {
            if (it->playbackStatus == QLatin1String("Playing") && (!it->title.isEmpty() || !it->trackId.isEmpty())) {
                chosen = it.key();
                break;
            }
        }
    }

    if (chosen.isEmpty()) {
        QDateTime latest;
        for (auto it = m_players.cbegin(); it != m_players.cend(); ++it) {
            if (!it->lastActive.isValid()) continue;
            if (!latest.isValid() || it->lastActive > latest) {
                latest = it->lastActive;
                chosen = it.key();
            }
        }
    }

    if (chosen.isEmpty()) {
        for (auto it = m_players.cbegin(); it != m_players.cend(); ++it) {
            if (it->playbackStatus == QLatin1String("Paused") && (!it->title.isEmpty() || !it->trackId.isEmpty())) {
                chosen = it.key();
                break;
            }
        }
    }

    if (chosen.isEmpty() && !m_players.isEmpty()) chosen = m_players.cbegin().key();

    if (chosen.isEmpty()) {
        clearCurrentTrack();
        return;
    }

    const PlayerInfo player = m_players.value(chosen);
    if (player.playbackStatus == QLatin1String("Stopped") || (player.title.isEmpty() && player.trackId.isEmpty())) {
        clearCurrentTrack();
        return;
    }

    m_activeService = chosen;
    const QString nextTrackKey = trackKeyFor(player);
    if (nextTrackKey != m_currentTrackKey) {
        startTrack(player);
    } else {
        m_currentPlayer = player;
        updatePosition();
    }
}

QString LyricsMprisApp::trackKeyFor(const PlayerInfo &player) const {
    return QStringList({
        player.service,
        player.trackId,
        player.title,
        player.artist,
        player.album,
        QString::number(player.lengthMs)
    }).join(QLatin1Char('|'));
}

TrackQuery LyricsMprisApp::queryFor(const PlayerInfo &player) const {
    TrackQuery query;
    query.title = player.title;
    query.artist = player.artist;
    query.album = player.album;
    query.durationMs = int(player.lengthMs);
    return query;
}

void LyricsMprisApp::startTrack(const PlayerInfo &player) {
    clearCurrentTrack();
    m_generation++;
    m_activeService = player.service;
    m_currentPlayer = player;
    m_currentTrackKey = trackKeyFor(player);
    m_fallbackStarted = false;
    m_hasAcceptedDocument = false;
    m_bestSyncedScore = 0;
    m_bestPlainScore = 0;
    m_bestSyncedDocument.clearAndFree();
    m_bestPlainCandidate = ProviderCandidate();
    emitLine(QString(), false);
    emitStatus(QStringLiteral("searching"));

    if (player.title.trimmed().isEmpty()) {
        emitStatus(QStringLiteral("not_found"));
        maybeQuitLookup();
        return;
    }

    bool hasSyncedDocument = false;
    tryInlineLyrics(player, &hasSyncedDocument);
    if (!hasSyncedDocument) tryLocalLyrics(player, &hasSyncedDocument);
    if (hasSyncedDocument) return;

    startRemoteProviders();
}

void LyricsMprisApp::tryInlineLyrics(const PlayerInfo &player, bool *hasSyncedDocument) {
    if (player.inlineLyrics.trimmed().isEmpty()) return;

    ProviderCandidate candidate;
    candidate.provider = QStringLiteral("mpris");
    candidate.title = player.title;
    candidate.artist = player.artist;
    candidate.album = player.album;
    candidate.durationMs = int(player.lengthMs);
    candidate.syncedLyrics = player.inlineLyrics;

    LyricDocument document = documentFromCandidate(candidate);
    if (document.hasSyncedLines()) {
        acceptDocument(std::move(document), QStringLiteral("synced"), true);
        *hasSyncedDocument = true;
        return;
    }

    if (document.hasPlainLines()) {
        candidate.syncedLyrics.clear();
        candidate.plainLyrics = player.inlineLyrics;
        rememberPlainCandidate(candidate, 100);
        acceptDocument(std::move(document), QStringLiteral("plain"), false);
    }
}

void LyricsMprisApp::tryLocalLyrics(const PlayerInfo &player, bool *hasSyncedDocument) {
    if (player.url.isEmpty()) return;

    QUrl url(player.url);
    QString localPath;
    if (url.isLocalFile()) localPath = url.toLocalFile();
    else if (QFileInfo::exists(player.url)) localPath = player.url;
    if (localPath.isEmpty()) return;

    const QFileInfo mediaInfo(localPath);
    const QString base = mediaInfo.completeBaseName();
    const QString dir = mediaInfo.absolutePath();
    const QStringList candidates = {
        dir + QLatin1Char('/') + base + QStringLiteral(".lrc"),
        dir + QLatin1Char('/') + base + QStringLiteral(".LRC"),
        localPath + QStringLiteral(".lrc"),
        dir + QStringLiteral("/lyrics/") + base + QStringLiteral(".lrc")
    };

    for (const QString &path : candidates) {
        QFile file(path);
        if (!file.exists() || file.size() <= 0 || file.size() > kMaxLocalLyricsSize) continue;
        if (!file.open(QIODevice::ReadOnly)) continue;

        ProviderCandidate candidate;
        candidate.provider = QStringLiteral("local");
        candidate.title = player.title;
        candidate.artist = player.artist;
        candidate.album = player.album;
        candidate.durationMs = int(player.lengthMs);
        candidate.syncedLyrics = QString::fromUtf8(file.readAll());

        LyricDocument document = documentFromCandidate(candidate);
        if (document.hasSyncedLines()) {
            acceptDocument(std::move(document), QStringLiteral("synced"), true);
            *hasSyncedDocument = true;
            return;
        }
        if (document.hasPlainLines()) {
            candidate.syncedLyrics.clear();
            candidate.plainLyrics = document.plainLines.join(QLatin1Char('\n'));
            rememberPlainCandidate(candidate, 100);
            acceptDocument(std::move(document), QStringLiteral("plain"), false);
        }
    }
}

void LyricsMprisApp::startRemoteProviders() {
    bool startedPrimary = false;
    for (const QString &provider : m_options.providers) {
        if (provider == QLatin1String("lrclib") || provider == QLatin1String("lrcx") || provider == QLatin1String("musixmatch")) {
            startProvider(provider);
            startedPrimary = true;
        }
    }

    if (startedPrimary) m_fallbackTimer.start();
    else startFallbackProviders();
}

void LyricsMprisApp::startFallbackProviders() {
    if (m_fallbackStarted || m_currentTrackKey.isEmpty() || m_currentDocument.hasSyncedLines()) return;
    m_fallbackStarted = true;
    for (const QString &provider : m_options.providers) {
        if (provider == QLatin1String("netease") || provider == QLatin1String("qq") || provider == QLatin1String("kugou"))
            startProvider(provider);
    }
    maybeFinishSearch();
}

void LyricsMprisApp::startProvider(const QString &provider) {
    if (m_startedProviders.contains(provider)) return;
    m_startedProviders.insert(provider);

    if (provider == QLatin1String("lrclib")) startLrclib();
    else if (provider == QLatin1String("lrcx")) startLrcx();
    else if (provider == QLatin1String("netease")) startNetease();
    else if (provider == QLatin1String("qq")) startQq();
    else if (provider == QLatin1String("kugou")) startKugou();
    else if (provider == QLatin1String("musixmatch")) startMusixmatch();
}

void LyricsMprisApp::startLrclib() {
    const TrackQuery query = queryFor(m_currentPlayer);

    QUrlQuery getQuery;
    getQuery.addQueryItem(QStringLiteral("track_name"), query.title);
    getQuery.addQueryItem(QStringLiteral("artist_name"), query.artist);
    if (!query.album.isEmpty()) getQuery.addQueryItem(QStringLiteral("album_name"), query.album);
    if (query.durationMs > 0) getQuery.addQueryItem(QStringLiteral("duration"), QString::number(qMax(1, query.durationMs / 1000)));
    get(withQuery(QStringLiteral("https://lrclib.net/api/get"), getQuery), QStringLiteral("lrclib"), QStringLiteral("lrclib-get"));

    QUrlQuery searchQuery;
    searchQuery.addQueryItem(QStringLiteral("track_name"), query.title);
    searchQuery.addQueryItem(QStringLiteral("artist_name"), query.artist);
    get(withQuery(QStringLiteral("https://lrclib.net/api/search"), searchQuery), QStringLiteral("lrclib"), QStringLiteral("lrclib-search"));
}

void LyricsMprisApp::startLrcx() {
    const TrackQuery query = queryFor(m_currentPlayer);

    QUrlQuery advanced;
    advanced.addQueryItem(QStringLiteral("title"), query.title);
    advanced.addQueryItem(QStringLiteral("artist"), query.artist);
    if (!query.album.isEmpty()) advanced.addQueryItem(QStringLiteral("album"), query.album);
    if (query.durationMs > 0) advanced.addQueryItem(QStringLiteral("duration"), QString::number(qMax(1, query.durationMs / 1000)));
    get(withQuery(QStringLiteral("https://api.lrc.cx/api/v1/lyrics/advance"), advanced), QStringLiteral("lrcx"), QStringLiteral("lrcx-json"));

    QUrlQuery legacy;
    legacy.addQueryItem(QStringLiteral("title"), query.title);
    legacy.addQueryItem(QStringLiteral("artist"), query.artist);
    get(withQuery(QStringLiteral("https://api.lrc.cx/lyrics"), legacy), QStringLiteral("lrcx"), QStringLiteral("lrcx-text"));
}

void LyricsMprisApp::startNetease() {
    const TrackQuery query = queryFor(m_currentPlayer);
    QUrlQuery urlQuery;
    urlQuery.addQueryItem(QStringLiteral("s"), makeSearchQuery(query));
    urlQuery.addQueryItem(QStringLiteral("type"), QStringLiteral("1"));
    urlQuery.addQueryItem(QStringLiteral("limit"), QStringLiteral("5"));
    urlQuery.addQueryItem(QStringLiteral("offset"), QStringLiteral("0"));
    get(withQuery(QStringLiteral("https://music.163.com/api/search/get"), urlQuery), QStringLiteral("netease"), QStringLiteral("netease-search"));
}

void LyricsMprisApp::startQq() {
    const TrackQuery query = queryFor(m_currentPlayer);
    QUrlQuery urlQuery;
    urlQuery.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
    urlQuery.addQueryItem(QStringLiteral("p"), QStringLiteral("1"));
    urlQuery.addQueryItem(QStringLiteral("n"), QStringLiteral("5"));
    urlQuery.addQueryItem(QStringLiteral("w"), makeSearchQuery(query));
    get(withQuery(QStringLiteral("https://c.y.qq.com/soso/fcgi-bin/client_search_cp"), urlQuery), QStringLiteral("qq"), QStringLiteral("qq-search"));
}

void LyricsMprisApp::startKugou() {
    const TrackQuery query = queryFor(m_currentPlayer);
    QUrlQuery urlQuery;
    urlQuery.addQueryItem(QStringLiteral("keyword"), makeSearchQuery(query));
    urlQuery.addQueryItem(QStringLiteral("page"), QStringLiteral("1"));
    urlQuery.addQueryItem(QStringLiteral("pagesize"), QStringLiteral("5"));
    get(withQuery(QStringLiteral("https://songsearch.kugou.com/song_search_v2"), urlQuery), QStringLiteral("kugou"), QStringLiteral("kugou-song-search"));
}

void LyricsMprisApp::startMusixmatch() {
    const QString apiKey = qEnvironmentVariable("MUSIXMATCH_API_KEY");
    if (apiKey.isEmpty()) return;

    const TrackQuery query = queryFor(m_currentPlayer);
    QUrlQuery subtitleQuery;
    subtitleQuery.addQueryItem(QStringLiteral("q_track"), query.title);
    subtitleQuery.addQueryItem(QStringLiteral("q_artist"), query.artist);
    subtitleQuery.addQueryItem(QStringLiteral("apikey"), apiKey);
    get(withQuery(QStringLiteral("https://api.musixmatch.com/ws/1.1/matcher.subtitle.get"), subtitleQuery), QStringLiteral("musixmatch"), QStringLiteral("musixmatch-subtitle"));

    QUrlQuery lyricsQuery = subtitleQuery;
    get(withQuery(QStringLiteral("https://api.musixmatch.com/ws/1.1/matcher.lyrics.get"), lyricsQuery), QStringLiteral("musixmatch"), QStringLiteral("musixmatch-lyrics"));
}

QNetworkReply *LyricsMprisApp::get(const QUrl &url, const QString &provider, const QString &stage) {
    QNetworkRequest request(url);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lyricsmpris-cpp/2.1 TideIsland"));
    request.setRawHeader("Accept", "application/json,text/plain,*/*");
    if (provider == QLatin1String("netease"))
        request.setRawHeader("Referer", "https://music.163.com/");
    else if (provider == QLatin1String("qq"))
        request.setRawHeader("Referer", "https://y.qq.com/");
    else if (provider == QLatin1String("kugou"))
        request.setRawHeader("Referer", "https://www.kugou.com/");
    request.setTransferTimeout(kNetworkTimeoutMs);

    QNetworkReply *reply = m_network.get(request);
    reply->setProperty("generation", m_generation);
    reply->setProperty("provider", provider);
    reply->setProperty("stage", stage);
    m_replies.append(reply);
    m_pendingReplies++;
    connect(reply, &QNetworkReply::finished, this, &LyricsMprisApp::handleNetworkFinished);
    return reply;
}

void LyricsMprisApp::copyCandidateMetadata(QNetworkReply *reply, const ProviderCandidate &candidate) {
    reply->setProperty("candidateTitle", candidate.title);
    reply->setProperty("candidateArtist", candidate.artist);
    reply->setProperty("candidateAlbum", candidate.album);
    reply->setProperty("candidateDurationMs", candidate.durationMs);
    reply->setProperty("candidateMetadataTrusted", candidate.metadataTrusted);
}

ProviderCandidate LyricsMprisApp::candidateFromReply(QNetworkReply *reply, ProviderCandidate candidate) const {
    if (candidate.title.isEmpty()) candidate.title = reply->property("candidateTitle").toString();
    if (candidate.artist.isEmpty()) candidate.artist = reply->property("candidateArtist").toString();
    if (candidate.album.isEmpty()) candidate.album = reply->property("candidateAlbum").toString();
    if (candidate.durationMs <= 0) candidate.durationMs = reply->property("candidateDurationMs").toInt();
    if (reply->property("candidateMetadataTrusted").isValid())
        candidate.metadataTrusted = reply->property("candidateMetadataTrusted").toBool();
    return candidate;
}

void LyricsMprisApp::handleNetworkFinished() {
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply) return;

    m_replies.removeOne(reply);
    m_pendingReplies = qMax(0, m_pendingReplies - 1);

    const int generation = reply->property("generation").toInt();
    const QString provider = reply->property("provider").toString();
    const QString stage = reply->property("stage").toString();
    const bool current = generation == m_generation && !m_currentTrackKey.isEmpty();
    const QByteArray body = current && reply->error() == QNetworkReply::NoError ? safeBody(reply) : QByteArray();

    if (current && !body.isEmpty()) {
        if (stage == QLatin1String("lrclib-get") || stage == QLatin1String("lrclib-search")) {
            for (ProviderCandidate candidate : parseLrclibJson(body)) considerCandidate(candidate);
        } else if (stage == QLatin1String("lrcx-json")) {
            for (ProviderCandidate candidate : parseLrcxJson(body)) considerCandidate(candidate);
        } else if (stage == QLatin1String("lrcx-text")) {
            ProviderCandidate candidate;
            candidate.provider = provider;
            candidate.metadataTrusted = false;
            candidate.syncedLyrics = QString::fromUtf8(body);
            considerCandidate(candidate);
        } else if (stage == QLatin1String("netease-search")) {
            QList<ProviderCandidate> candidates = parseNeteaseSearchJson(body);
            const TrackQuery trackQuery = queryFor(m_currentPlayer);
            std::sort(candidates.begin(), candidates.end(), [&trackQuery](const ProviderCandidate &left, const ProviderCandidate &right) {
                return scoreCandidate(trackQuery, left) > scoreCandidate(trackQuery, right);
            });
            int requested = 0;
            for (int index = 0; index < candidates.size() && requested < kDownloadCandidateLimit; ++index) {
                const ProviderCandidate &candidate = candidates.at(index);
                const CandidateEvaluation evaluation = evaluateCandidate(trackQuery, candidate);
                debugCandidate(candidate, evaluation, evaluation.accepted ? QStringLiteral("download") : QStringLiteral("skip"));
                if (!evaluation.accepted) continue;
                QUrlQuery query;
                query.addQueryItem(QStringLiteral("os"), QStringLiteral("pc"));
                query.addQueryItem(QStringLiteral("id"), candidate.syncedLyrics);
                query.addQueryItem(QStringLiteral("lv"), QStringLiteral("-1"));
                query.addQueryItem(QStringLiteral("tv"), QStringLiteral("-1"));
                QNetworkReply *next = get(withQuery(QStringLiteral("https://music.163.com/api/song/lyric"), query), provider, QStringLiteral("netease-lyric"));
                copyCandidateMetadata(next, candidate);
                requested++;
            }
        } else if (stage == QLatin1String("netease-lyric")) {
            considerCandidate(candidateFromReply(reply, parseNeteaseLyricJson(body)));
        } else if (stage == QLatin1String("qq-search")) {
            QList<ProviderCandidate> candidates = parseQqSearchJson(body);
            const TrackQuery trackQuery = queryFor(m_currentPlayer);
            std::sort(candidates.begin(), candidates.end(), [&trackQuery](const ProviderCandidate &left, const ProviderCandidate &right) {
                return scoreCandidate(trackQuery, left) > scoreCandidate(trackQuery, right);
            });
            int requested = 0;
            for (int index = 0; index < candidates.size() && requested < kDownloadCandidateLimit; ++index) {
                const ProviderCandidate &candidate = candidates.at(index);
                const CandidateEvaluation evaluation = evaluateCandidate(trackQuery, candidate);
                debugCandidate(candidate, evaluation, evaluation.accepted ? QStringLiteral("download") : QStringLiteral("skip"));
                if (!evaluation.accepted) continue;
                QUrlQuery query;
                query.addQueryItem(QStringLiteral("songmid"), candidate.syncedLyrics);
                query.addQueryItem(QStringLiteral("format"), QStringLiteral("json"));
                query.addQueryItem(QStringLiteral("nobase64"), QStringLiteral("1"));
                QNetworkReply *next = get(withQuery(QStringLiteral("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg"), query), provider, QStringLiteral("qq-lyric"));
                copyCandidateMetadata(next, candidate);
                requested++;
            }
        } else if (stage == QLatin1String("qq-lyric")) {
            considerCandidate(candidateFromReply(reply, parseQqLyricJson(body)));
        } else if (stage == QLatin1String("kugou-song-search")) {
            QList<ProviderCandidate> candidates = parseKugouSongSearchJson(body);
            const TrackQuery trackQuery = queryFor(m_currentPlayer);
            std::sort(candidates.begin(), candidates.end(), [&trackQuery](const ProviderCandidate &left, const ProviderCandidate &right) {
                return scoreCandidate(trackQuery, left) > scoreCandidate(trackQuery, right);
            });
            int requested = 0;
            for (int index = 0; index < candidates.size() && requested < kDownloadCandidateLimit; ++index) {
                const ProviderCandidate &candidate = candidates.at(index);
                const CandidateEvaluation evaluation = evaluateCandidate(trackQuery, candidate);
                debugCandidate(candidate, evaluation, evaluation.accepted ? QStringLiteral("download") : QStringLiteral("skip"));
                if (!evaluation.accepted) continue;
                QUrlQuery query;
                query.addQueryItem(QStringLiteral("ver"), QStringLiteral("1"));
                query.addQueryItem(QStringLiteral("man"), QStringLiteral("yes"));
                query.addQueryItem(QStringLiteral("client"), QStringLiteral("pc"));
                query.addQueryItem(QStringLiteral("keyword"), (candidate.title + QLatin1Char(' ') + candidate.artist).trimmed());
                query.addQueryItem(QStringLiteral("duration"), QString::number(qMax(1, candidate.durationMs)));
                query.addQueryItem(QStringLiteral("hash"), candidate.syncedLyrics);
                QNetworkReply *next = get(withQuery(QStringLiteral("https://lyrics.kugou.com/search"), query), provider, QStringLiteral("kugou-lyric-search"));
                copyCandidateMetadata(next, candidate);
                requested++;
            }
        } else if (stage == QLatin1String("kugou-lyric-search")) {
            const QList<QJsonObject> candidates = parseKugouLyricSearchJson(body);
            if (!candidates.isEmpty()) {
                const QJsonObject first = candidates.first();
                QUrlQuery query;
                query.addQueryItem(QStringLiteral("ver"), QStringLiteral("1"));
                query.addQueryItem(QStringLiteral("client"), QStringLiteral("pc"));
                query.addQueryItem(QStringLiteral("id"), QString::number(first.value(QStringLiteral("id")).toInt()));
                query.addQueryItem(QStringLiteral("accesskey"), first.value(QStringLiteral("accesskey")).toString());
                query.addQueryItem(QStringLiteral("fmt"), QStringLiteral("lrc"));
                query.addQueryItem(QStringLiteral("charset"), QStringLiteral("utf8"));
                QNetworkReply *next = get(withQuery(QStringLiteral("https://lyrics.kugou.com/download"), query), provider, QStringLiteral("kugou-download"));
                next->setProperty("candidateTitle", reply->property("candidateTitle"));
                next->setProperty("candidateArtist", reply->property("candidateArtist"));
                next->setProperty("candidateAlbum", reply->property("candidateAlbum"));
                next->setProperty("candidateDurationMs", reply->property("candidateDurationMs"));
            }
        } else if (stage == QLatin1String("kugou-download")) {
            considerCandidate(candidateFromReply(reply, parseKugouDownloadJson(body)));
        } else if (stage.startsWith(QStringLiteral("musixmatch"))) {
            for (ProviderCandidate candidate : parseMusixmatchJson(body, provider)) {
                candidate = candidateFromReply(reply, std::move(candidate));
                considerCandidate(candidate);
            }
        }
    }

    reply->deleteLater();
    if (m_pendingReplies == 0 && !m_fallbackStarted && !m_currentDocument.hasSyncedLines()) startFallbackProviders();
    maybeFinishSearch();
}

void LyricsMprisApp::considerCandidate(ProviderCandidate candidate) {
    if (m_currentDocument.hasSyncedLines()) return;

    const CandidateEvaluation evaluation = evaluateCandidate(queryFor(m_currentPlayer), candidate);
    debugCandidate(candidate, evaluation, evaluation.accepted ? QStringLiteral("candidate") : QStringLiteral("reject"));
    if (!evaluation.accepted) return;

    LyricDocument document = documentFromCandidate(candidate);
    if (document.isEmpty()) return;

    if (document.hasSyncedLines()) {
        if (evaluation.highConfidence) {
            acceptDocument(std::move(document), QStringLiteral("synced"), true);
            return;
        }
        rememberSyncedCandidate(std::move(document), evaluation.score);
        return;
    }

    if (document.hasPlainLines())
        rememberPlainCandidate(std::move(candidate), evaluation.score);
}

void LyricsMprisApp::rememberSyncedCandidate(LyricDocument document, int score) {
    if (score <= m_bestSyncedScore) return;
    m_bestSyncedScore = score;
    m_bestSyncedDocument.clearAndFree();
    m_bestSyncedDocument = std::move(document);
}

void LyricsMprisApp::rememberPlainCandidate(ProviderCandidate candidate, int score) {
    if (score <= m_bestPlainScore) return;
    m_bestPlainScore = score;
    m_bestPlainCandidate = std::move(candidate);
}

void LyricsMprisApp::acceptDocument(LyricDocument document, const QString &status, bool finalSynced) {
    releaseCurrentDocument();
    m_currentDocument = std::move(document);
    m_hasAcceptedDocument = true;
    emitStatus(status);
    updatePosition();

    if (finalSynced) {
        abortNetwork();
        m_fallbackTimer.stop();
    }
    maybeQuitLookup();
}

void LyricsMprisApp::maybeFinishSearch() {
    if (m_pendingReplies > 0 || !m_fallbackStarted || m_currentTrackKey.isEmpty()) return;
    if (m_currentDocument.hasSyncedLines()) return;

    if (m_bestSyncedDocument.hasSyncedLines()) {
        acceptDocument(std::move(m_bestSyncedDocument), QStringLiteral("synced"), true);
        return;
    }

    if (!m_bestPlainCandidate.plainLyrics.isEmpty()) {
        LyricDocument plain = documentFromCandidate(m_bestPlainCandidate);
        if (!plain.isEmpty()) {
            acceptDocument(std::move(plain), QStringLiteral("plain"), false);
            return;
        }
    }

    if (!m_hasAcceptedDocument) {
        emitLine(QString(), false);
        emitStatus(QStringLiteral("not_found"));
        maybeQuitLookup();
    }
}

void LyricsMprisApp::updatePosition() {
    if (m_currentTrackKey.isEmpty() || m_currentDocument.isEmpty()) {
        m_positionTimer.stop();
        return;
    }

    PlayerInfo player = m_players.value(m_activeService, m_currentPlayer);
    if (player.service.isEmpty()) player = m_currentPlayer;

    if (!player.service.isEmpty()) {
        QDBusInterface properties(
            player.service,
            QStringLiteral("/org/mpris/MediaPlayer2"),
            QStringLiteral("org.freedesktop.DBus.Properties"),
            QDBusConnection::sessionBus());
        QDBusMessage positionReply = properties.call(
            QStringLiteral("Get"),
            QStringLiteral("org.mpris.MediaPlayer2.Player"),
            QStringLiteral("Position"));
        if (positionReply.type() != QDBusMessage::ErrorMessage && !positionReply.arguments().isEmpty())
            player.positionMs = variantToLongLong(positionReply.arguments().first()) / 1000;
    }

    const QString line = selectLineAt(m_currentDocument, player.positionMs);
    emitLine(line, m_currentDocument.hasSyncedLines());

    const bool shouldPoll = m_currentDocument.hasSyncedLines()
        && player.playbackStatus != QLatin1String("Stopped")
        && !m_currentTrackKey.isEmpty();
    if (shouldPoll && !m_positionTimer.isActive()) m_positionTimer.start();
    else if (!shouldPoll && m_positionTimer.isActive()) m_positionTimer.stop();
}

void LyricsMprisApp::clearCurrentTrack() {
    m_fallbackTimer.stop();
    m_positionTimer.stop();
    abortNetwork();
    releaseCurrentDocument();
    m_bestSyncedDocument.clearAndFree();
    m_currentTrackKey.clear();
    m_currentTrackKey.squeeze();
    m_currentPlayer = PlayerInfo();
    m_activeService.clear();
    m_activeService.squeeze();
    m_startedProviders.clear();
    m_fallbackStarted = false;
    m_hasAcceptedDocument = false;
    m_bestSyncedScore = 0;
    m_bestPlainScore = 0;
    m_bestPlainCandidate = ProviderCandidate();
    emitLine(QString(), false);
    emitStatus(QStringLiteral("idle"));
}

void LyricsMprisApp::releaseCurrentDocument() {
    m_currentDocument.clearAndFree();
}

void LyricsMprisApp::abortNetwork() {
    for (QNetworkReply *reply : std::as_const(m_replies)) {
        if (!reply) continue;
        disconnect(reply, nullptr, this, nullptr);
        reply->abort();
        reply->deleteLater();
    }
    m_replies.clear();
    m_pendingReplies = 0;
}

void LyricsMprisApp::maybeQuitLookup() {
    if (m_options.lookupMode)
        QTimer::singleShot(0, QCoreApplication::instance(), &QCoreApplication::quit);
}

void LyricsMprisApp::debugCandidate(const ProviderCandidate &candidate, const CandidateEvaluation &evaluation, const QString &action) const {
    if (!lyricsDebugEnabled()) return;

    QTextStream stream(stderr);
    stream << "[LyricsMatch] " << action
           << " provider=" << candidate.provider
           << " title=\"" << candidate.title << "\""
           << " artist=\"" << candidate.artist << "\""
           << " album=\"" << candidate.album << "\""
           << " durationMs=" << candidate.durationMs
           << " trusted=" << (candidate.metadataTrusted ? "true" : "false")
           << " score=" << evaluation.score
           << " accepted=" << (evaluation.accepted ? "true" : "false")
           << " high=" << (evaluation.highConfidence ? "true" : "false")
           << " reason=" << evaluation.reason;
    if (!evaluation.lyricMetadata.isEmpty()) {
        stream << " lrcTitle=\"" << evaluation.lyricMetadata.title << "\""
               << " lrcArtist=\"" << evaluation.lyricMetadata.artist << "\"";
    }
    stream << Qt::endl;
}

bool LyricsMprisApp::serviceBlocked(const QString &service) const {
    const QString lower = service.toLower();
    for (const QString &blocked : m_options.blockedServices) {
        if (!blocked.isEmpty() && lower.contains(blocked)) return true;
    }
    return false;
}

QVariant LyricsMprisApp::unwrapDbusVariant(const QVariant &value) {
    if (value.metaType().id() == qMetaTypeId<QDBusVariant>())
        return qvariant_cast<QDBusVariant>(value).variant();
    return value;
}

QString LyricsMprisApp::variantToString(const QVariant &value) {
    const QVariant unwrapped = unwrapDbusVariant(value);
    if (unwrapped.metaType().id() == qMetaTypeId<QDBusObjectPath>())
        return qvariant_cast<QDBusObjectPath>(unwrapped).path();
    if (unwrapped.metaType().id() == qMetaTypeId<QDBusArgument>())
        return qdbus_cast<QString>(unwrapped);
    if (unwrapped.canConvert<QString>()) return unwrapped.toString();
    return QString();
}

QString LyricsMprisApp::variantToStringListText(const QVariant &value) {
    const QVariant unwrapped = unwrapDbusVariant(value);
    if (unwrapped.metaType().id() == qMetaTypeId<QDBusArgument>())
        return qdbus_cast<QStringList>(unwrapped).join(QStringLiteral(", "));
    if (unwrapped.canConvert<QStringList>())
        return unwrapped.toStringList().join(QStringLiteral(", "));
    if (unwrapped.metaType().id() == QMetaType::QVariantList) {
        QStringList values;
        for (const QVariant &item : unwrapped.toList()) values.append(variantToString(item));
        return values.join(QStringLiteral(", "));
    }
    return variantToString(unwrapped);
}

qint64 LyricsMprisApp::variantToLongLong(const QVariant &value) {
    const QVariant unwrapped = unwrapDbusVariant(value);
    if (unwrapped.metaType().id() == qMetaTypeId<QDBusArgument>())
        return qdbus_cast<qlonglong>(unwrapped);
    return unwrapped.toLongLong();
}

} // namespace lyricsmpris
