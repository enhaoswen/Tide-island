#include "LyricsCore.h"

#include <QtTest/QtTest>

using namespace lyricsmpris;

class LyricsMprisCoreTests final : public QObject {
    Q_OBJECT

private slots:
    void parsesSyncedLrc();
    void parsesMultiTimestampLines();
    void keepsPlainLyricsFallback();
    void filtersPlaceholderLyrics();
    void normalizesNoisyTitles();
    void scoresLikelyMatches();
    void acceptsChineseAndAliasMatches();
    void acceptsListedCollaborators();
    void rejectsWrongVersionsAndDurations();
    void rejectsConflictingLyricMetadata();
    void requiresTrustedOrLyricMetadata();
    void acceptsMusixmatchWithRequestMetadata();
    void parsesNeteaseSearchShapes();
    void parsesProviderFixtures();
    void releasesDocumentStorage();
};

void LyricsMprisCoreTests::parsesSyncedLrc() {
    const LyricDocument document = parseLyrics("[ar:Artist]\n[00:01.50] First line\n[00:03.250]Second line\n", "test");
    QVERIFY(document.hasSyncedLines());
    QCOMPARE(document.syncedLines.size(), 2);
    QCOMPARE(document.syncedLines.at(0).timeMs, 1500);
    QCOMPARE(document.syncedLines.at(1).timeMs, 3250);
    QCOMPARE(selectLineAt(document, 1400), QString());
    QCOMPARE(selectLineAt(document, 2000), QString("First line"));
    QCOMPARE(selectLineAt(document, 4000), QString("Second line"));
}

void LyricsMprisCoreTests::parsesMultiTimestampLines() {
    const LyricDocument document = parseLyrics("[00:10.00][00:20.00]Chorus\n[00:30.0]\n", "test");
    QCOMPARE(document.syncedLines.size(), 3);
    QCOMPARE(document.syncedLines.at(0).timeMs, 10000);
    QCOMPARE(document.syncedLines.at(1).timeMs, 20000);
    QCOMPARE(document.syncedLines.at(2).timeMs, 30000);
    QCOMPARE(selectLineAt(document, 21000), QString("Chorus"));
    QCOMPARE(selectLineAt(document, 31000), QString());
}

void LyricsMprisCoreTests::keepsPlainLyricsFallback() {
    const LyricDocument document = parseLyrics("Line one\n\nLine two\n", "plain");
    QVERIFY(!document.hasSyncedLines());
    QCOMPARE(document.plainLines.size(), 2);
    QCOMPARE(selectLineAt(document, 0), QString("Line one"));
}

void LyricsMprisCoreTests::filtersPlaceholderLyrics() {
    QVERIFY(parseLyrics("[00:01.00]暂无歌词\n").isEmpty());
    QVERIFY(parseLyrics("纯音乐，请欣赏\n").isEmpty());
}

void LyricsMprisCoreTests::normalizesNoisyTitles() {
    QCOMPARE(normalizedTitle("Song Title (feat. Someone) - Remastered 2011"), QString("song title"));
    QCOMPARE(normalizedTitle("HELLO!!! [Official Lyric Video]"), QString("hello"));
    QCOMPARE(normalizedArtist("Artist feat. Guest"), QString("artist"));
}

void LyricsMprisCoreTests::scoresLikelyMatches() {
    TrackQuery query;
    query.title = "Song Title (Remastered)";
    query.artist = "Main Artist";
    query.album = "Album";
    query.durationMs = 180000;

    ProviderCandidate good;
    good.title = "Song Title";
    good.artist = "Main Artist";
    good.album = "Album";
    good.durationMs = 181000;
    good.syncedLyrics = "[00:01.00]Hello";

    ProviderCandidate bad = good;
    bad.title = "Different Song";
    bad.artist = "Other Artist";
    bad.durationMs = 240000;

    QVERIFY(scoreCandidate(query, good) >= 100);
    QVERIFY(scoreCandidate(query, bad) < scoreCandidate(query, good));
}

void LyricsMprisCoreTests::acceptsChineseAndAliasMatches() {
    TrackQuery chinese;
    chinese.title = "告白气球";
    chinese.artist = "周杰伦";
    chinese.durationMs = 215000;

    ProviderCandidate candidate;
    candidate.title = "告白氣球";
    candidate.artist = "周傑倫 (Jay Chou)";
    candidate.durationMs = 209000;
    candidate.syncedLyrics = "[ti:告白氣球]\n[ar:周傑倫]\n[00:01.00]塞納河畔";

    const CandidateEvaluation chineseEvaluation = evaluateCandidate(chinese, candidate);
    QVERIFY2(chineseEvaluation.accepted, qPrintable(chineseEvaluation.reason));
    QVERIFY(chineseEvaluation.highConfidence);

    TrackQuery englishAlias;
    englishAlias.title = "光年之外";
    englishAlias.artist = "G.E.M. 邓紫棋";
    englishAlias.durationMs = 235000;

    ProviderCandidate aliasCandidate;
    aliasCandidate.title = "光年之外";
    aliasCandidate.artist = "G E M 鄧紫棋";
    aliasCandidate.durationMs = 235500;
    aliasCandidate.syncedLyrics = "[ti:光年之外]\n[ar:G.E.M. 鄧紫棋]\n[00:01.00]感受停在我发端的指尖";

    const CandidateEvaluation aliasEvaluation = evaluateCandidate(englishAlias, aliasCandidate);
    QVERIFY2(aliasEvaluation.accepted, qPrintable(aliasEvaluation.reason));
    QVERIFY(aliasEvaluation.highConfidence);
}

void LyricsMprisCoreTests::acceptsListedCollaborators() {
    TrackQuery query;
    query.title = "你知道你比晚霞好看吗";
    query.artist = "BK";
    query.durationMs = 179000;

    ProviderCandidate collaboration;
    collaboration.title = "你知道你比晚霞好看嗎 - Better than Sunset";
    collaboration.artist = "Tr33, BK, & Seluu";
    collaboration.durationMs = 179000;
    collaboration.syncedLyrics = "[00:01.00]Hey";

    const CandidateEvaluation collaborationEvaluation = evaluateCandidate(query, collaboration);
    QVERIFY2(collaborationEvaluation.accepted, qPrintable(collaborationEvaluation.reason));

    ProviderCandidate unrelated = collaboration;
    unrelated.title = "Grow With The Flow";
    unrelated.artist = "BILLKIN";
    QCOMPARE(evaluateCandidate(query, unrelated).reason, QString("title_mismatch"));
}

void LyricsMprisCoreTests::rejectsWrongVersionsAndDurations() {
    TrackQuery query;
    query.title = "告白气球";
    query.artist = "周杰伦";
    query.durationMs = 215000;

    ProviderCandidate shortClip;
    shortClip.title = "告白气球";
    shortClip.artist = "周杰伦";
    shortClip.durationMs = 60000;
    shortClip.syncedLyrics = "[00:01.00]Wrong short clip";
    QCOMPARE(evaluateCandidate(query, shortClip).reason, QString("duration_mismatch"));

    TrackQuery shortQuery = query;
    shortQuery.durationMs = 60000;
    ProviderCandidate missingDuration = shortClip;
    missingDuration.durationMs = 0;
    QCOMPARE(evaluateCandidate(shortQuery, missingDuration).reason, QString("missing_candidate_duration"));

    ProviderCandidate cover = shortClip;
    cover.title = "告白气球 (Cover)";
    cover.artist = "Xai小爱";
    cover.durationMs = 215000;
    QCOMPARE(evaluateCandidate(query, cover).reason, QString("version_mismatch"));

    ProviderCandidate piano = shortClip;
    piano.title = "告白气球 (钢琴版) [原唱: 周杰伦]";
    piano.durationMs = 215000;
    QCOMPARE(evaluateCandidate(query, piano).reason, QString("version_mismatch"));

    ProviderCandidate live = shortClip;
    live.title = "告白气球 (Live)";
    live.durationMs = 264000;
    QCOMPARE(evaluateCandidate(query, live).reason, QString("version_mismatch"));
}

void LyricsMprisCoreTests::rejectsConflictingLyricMetadata() {
    TrackQuery query;
    query.title = "Song Title";
    query.artist = "Main Artist";
    query.durationMs = 180000;

    ProviderCandidate wrongTitle;
    wrongTitle.title = "Song Title";
    wrongTitle.artist = "Main Artist";
    wrongTitle.durationMs = 180000;
    wrongTitle.syncedLyrics = "[ti:Different Song]\n[ar:Main Artist]\n[00:01.00]Hello";
    QCOMPARE(evaluateCandidate(query, wrongTitle).reason, QString("lyric_title_mismatch"));

    ProviderCandidate wrongArtist = wrongTitle;
    wrongArtist.syncedLyrics = "[ti:Song Title]\n[ar:Other Artist]\n[00:01.00]Hello";
    QCOMPARE(evaluateCandidate(query, wrongArtist).reason, QString("lyric_artist_mismatch"));
}

void LyricsMprisCoreTests::requiresTrustedOrLyricMetadata() {
    TrackQuery query;
    query.title = "Song Title";
    query.artist = "Main Artist";
    query.durationMs = 180000;

    ProviderCandidate untrusted;
    untrusted.metadataTrusted = false;
    untrusted.syncedLyrics = "[00:01.00]Hello";
    QCOMPARE(evaluateCandidate(query, untrusted).reason, QString("untrusted_metadata"));

    untrusted.syncedLyrics = "[ti:Song Title]\n[ar:Main Artist]\n[00:01.00]Hello";
    const CandidateEvaluation evaluation = evaluateCandidate(query, untrusted);
    QVERIFY2(evaluation.accepted, qPrintable(evaluation.reason));
}

void LyricsMprisCoreTests::acceptsMusixmatchWithRequestMetadata() {
    TrackQuery query;
    query.title = "Song Title";
    query.artist = "Main Artist";
    query.album = "Album";
    query.durationMs = 180000;

    const QByteArray payload = R"({
        "message": {
            "body": {
                "subtitle": {
                    "subtitle_body": "[00:01.00]Hello"
                }
            }
        }
    })";

    QList<ProviderCandidate> candidates = parseMusixmatchJson(payload, QStringLiteral("musixmatch"));
    QCOMPARE(candidates.size(), 1);
    QCOMPARE(evaluateCandidate(query, candidates.first()).reason, QString("untrusted_metadata"));

    ProviderCandidate candidate = candidates.first();
    candidate.title = query.title;
    candidate.artist = query.artist;
    candidate.album = query.album;
    candidate.durationMs = query.durationMs;
    candidate.metadataTrusted = true;

    const CandidateEvaluation evaluation = evaluateCandidate(query, candidate);
    QVERIFY2(evaluation.accepted, qPrintable(evaluation.reason));
    QVERIFY(documentFromCandidate(candidate).hasSyncedLines());
}

void LyricsMprisCoreTests::parsesNeteaseSearchShapes() {
    const QByteArray modern = R"({
        "result": {
            "songs": [{
                "name": "告白气球",
                "id": 12345,
                "ar": [{"name": "周杰伦"}],
                "al": {"name": "周杰伦的床边故事"},
                "dt": 215000
            }]
        }
    })";
    QList<ProviderCandidate> modernCandidates = parseNeteaseSearchJson(modern);
    QCOMPARE(modernCandidates.size(), 1);
    QCOMPARE(modernCandidates.first().artist, QString("周杰伦"));
    QCOMPARE(modernCandidates.first().album, QString("周杰伦的床边故事"));
    QCOMPARE(modernCandidates.first().durationMs, 215000);
    QCOMPARE(modernCandidates.first().syncedLyrics, QString("12345"));

    const QByteArray encrypted = R"({"result":"35b1748964af8a7c","code":200})";
    QVERIFY(parseNeteaseSearchJson(encrypted).isEmpty());
}

void LyricsMprisCoreTests::parsesProviderFixtures() {
    const QByteArray lrclib = R"([
        {"trackName":"Song","artistName":"Artist","albumName":"Album","duration":120,"syncedLyrics":"[00:01.00]Hi","plainLyrics":"Hi"}
    ])";
    QList<ProviderCandidate> candidates = parseLrclibJson(lrclib);
    QCOMPARE(candidates.size(), 1);
    QCOMPARE(candidates.first().provider, QString("lrclib"));
    QCOMPARE(candidates.first().durationMs, 120000);
    QVERIFY(documentFromCandidate(candidates.first()).hasSyncedLines());

    const QByteArray netease = R"({"lrc":{"lyric":"[00:02.00]Hello"}})";
    ProviderCandidate neteaseLyric = parseNeteaseLyricJson(netease);
    QCOMPARE(neteaseLyric.provider, QString("netease"));
    QVERIFY(documentFromCandidate(neteaseLyric).hasSyncedLines());

    const QByteArray kugou = R"({"content":"WzAwOjAxLjAwXUhvbGE="})";
    ProviderCandidate kugouLyric = parseKugouDownloadJson(kugou);
    QVERIFY(documentFromCandidate(kugouLyric).hasSyncedLines());
}

void LyricsMprisCoreTests::releasesDocumentStorage() {
    LyricDocument document = parseLyrics("[00:01.00]Hello\n[00:02.00]World\n", "test");
    QVERIFY(document.syncedLines.capacity() > 0);
    document.clearAndFree();
    QVERIFY(document.isEmpty());
    QCOMPARE(document.syncedLines.capacity(), qsizetype(0));
}

QTEST_MAIN(LyricsMprisCoreTests)
#include "lyricsmpris_core_tests.moc"
