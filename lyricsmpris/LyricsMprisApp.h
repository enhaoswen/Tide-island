#pragma once

#include "LyricsCore.h"

#include <QDateTime>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QObject>
#include <QSet>
#include <QStringList>
#include <QTimer>
#include <QUrl>

namespace lyricsmpris {

struct AppOptions {
    bool pipe = true;
    bool lookupMode = false;
    QString preferredService;
    QString lookupTitle;
    QString lookupArtist;
    QString lookupAlbum;
    int lookupDurationMs = 0;
    QStringList providers;
    QSet<QString> blockedServices;
};

class LyricsMprisApp final : public QObject {
    Q_OBJECT

public:
    explicit LyricsMprisApp(AppOptions options, QObject *parent = nullptr);

public slots:
    void start();

private slots:
    void refreshPlayers();
    void handleNameOwnerChanged(const QString &name, const QString &oldOwner, const QString &newOwner);
    void handlePropertiesChanged(const QString &interfaceName, const QVariantMap &changedProperties, const QStringList &invalidatedProperties);
    void updatePosition();
    void startFallbackProviders();
    void handleNetworkFinished();

private:
    struct PlayerInfo {
        QString service;
        QString playbackStatus;
        QString title;
        QString artist;
        QString album;
        QString url;
        QString trackId;
        QString inlineLyrics;
        qint64 lengthMs = 0;
        qint64 positionMs = 0;
        QDateTime lastActive;
        bool valid = false;
    };

    void emitStatus(const QString &status);
    void emitLine(const QString &line, bool synced);
    void clearCurrentTrack();
    void releaseCurrentDocument();
    void abortNetwork();
    void startLookup();
    void chooseActivePlayer();
    void updatePlayer(const QString &service);
    void startTrack(const PlayerInfo &player);
    QString trackKeyFor(const PlayerInfo &player) const;
    TrackQuery queryFor(const PlayerInfo &player) const;
    void tryInlineLyrics(const PlayerInfo &player, bool *hasSyncedDocument);
    void tryLocalLyrics(const PlayerInfo &player, bool *hasSyncedDocument);
    void startRemoteProviders();
    void startProvider(const QString &provider);
    void startLrclib();
    void startLrcx();
    void startNetease();
    void startQq();
    void startKugou();
    void startMusixmatch();
    QNetworkReply *get(const QUrl &url, const QString &provider, const QString &stage);
    void copyCandidateMetadata(QNetworkReply *reply, const ProviderCandidate &candidate);
    ProviderCandidate candidateFromReply(QNetworkReply *reply, ProviderCandidate candidate) const;
    void considerCandidate(ProviderCandidate candidate);
    void acceptDocument(LyricDocument document, const QString &status, bool finalSynced);
    void maybeFinishSearch();
    void rememberSyncedCandidate(LyricDocument document, int score);
    void rememberPlainCandidate(ProviderCandidate candidate, int score);
    void maybeQuitLookup();
    void debugCandidate(const ProviderCandidate &candidate, const CandidateEvaluation &evaluation, const QString &action) const;
    bool serviceBlocked(const QString &service) const;
    static QVariant unwrapDbusVariant(const QVariant &value);
    static QString variantToString(const QVariant &value);
    static QString variantToStringListText(const QVariant &value);
    static qint64 variantToLongLong(const QVariant &value);

    AppOptions m_options;
    QNetworkAccessManager m_network;
    QTimer m_refreshTimer;
    QTimer m_positionTimer;
    QTimer m_fallbackTimer;
    QHash<QString, PlayerInfo> m_players;
    QString m_activeService;
    QString m_currentTrackKey;
    PlayerInfo m_currentPlayer;
    LyricDocument m_currentDocument;
    LyricDocument m_bestSyncedDocument;
    ProviderCandidate m_bestPlainCandidate;
    int m_bestSyncedScore = 0;
    int m_bestPlainScore = 0;
    int m_generation = 0;
    int m_pendingReplies = 0;
    bool m_fallbackStarted = false;
    bool m_hasAcceptedDocument = false;
    QString m_lastStatus;
    QString m_lastLine;
    bool m_lastLineSynced = false;
    QList<QNetworkReply *> m_replies;
    QSet<QString> m_startedProviders;
};

} // namespace lyricsmpris
