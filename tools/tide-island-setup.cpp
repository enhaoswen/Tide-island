#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QStringList>
#include <QTextStream>
#include <QUrl>

#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <termios.h>
#include <unistd.h>

namespace {
constexpr auto configDirName = "tide-island";
constexpr auto configFileName = "userconfig.json";
constexpr auto setupLockFileName = "setup-wizard.lock";
constexpr auto wallpaperPathKey = "wallpaperPath";
constexpr auto wallpaperLibraryPathKey = "wallpaperLibraryPath";
constexpr auto tlpSudoPasswordKey = "tlpSudoPassword";
constexpr auto tlpPermissionModeKey = "tlpPermissionMode";
constexpr auto hyprlandBindKey = "hyprlandBind";
constexpr auto hyprlandBindModeKey = "hyprlandBindMode";
constexpr auto overviewBindCommand = "qs ipc -p /usr/share/tide-island call overview toggle";
constexpr auto overviewBindLine = "bind = SUPER, TAB, exec, qs ipc -p /usr/share/tide-island call overview toggle";
constexpr qint64 setupLockMaxAgeSeconds = 60 * 60;

struct SetupStep {
    QString key;
    QString label;
};

QString envString(const char *name)
{
    return QString::fromLocal8Bit(qgetenv(name));
}

QString homePath()
{
    const QString home = envString("HOME");
    if (!home.isEmpty())
        return home;

    return QDir::homePath();
}

QString expandUserPath(QString path)
{
    if (path == "~")
        return homePath();
    if (path.startsWith("~/"))
        return homePath() + path.sliced(1);
    return path;
}

QString configHome()
{
    const QString override = envString("TIDE_ISLAND_CONFIG_HOME");
    if (!override.isEmpty())
        return expandUserPath(override);

    const QString xdgConfigHome = envString("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return expandUserPath(xdgConfigHome);

    return homePath() + QStringLiteral("/.config");
}

QString userConfigPath()
{
    const QString override = envString("TIDE_ISLAND_USER_CONFIG");
    if (!override.isEmpty())
        return expandUserPath(override);

    return configHome() + QStringLiteral("/") + configDirName + QStringLiteral("/") + configFileName;
}

bool userConfigExists()
{
    return QFileInfo::exists(userConfigPath());
}

QString setupLockPath()
{
    return configHome() + QStringLiteral("/") + configDirName + QStringLiteral("/") + setupLockFileName;
}

QString hyprlandConfigPath()
{
    const QString override = envString("TIDE_ISLAND_HYPRLAND_CONFIG");
    if (!override.isEmpty())
        return expandUserPath(override);

    return configHome() + QStringLiteral("/hypr/hyprland.conf");
}

QJsonArray stringArray(std::initializer_list<QString> values)
{
    QJsonArray result;
    for (const QString &value : values)
        result.append(value);
    return result;
}

QJsonObject defaultUserConfig()
{
    return {
        {QString::fromLatin1(wallpaperPathKey), QString()},
        {QString::fromLatin1(wallpaperLibraryPathKey), QString()},
        {QStringLiteral("iconFontFamily"), QStringLiteral("JetBrainsMono Nerd Font")},
        {QStringLiteral("textFontFamily"), QStringLiteral("Inter Display")},
        {QStringLiteral("heroFontFamily"), QStringLiteral("Inter Display")},
        {QStringLiteral("timeFontFamily"), QStringLiteral("Inter Display")},
        {QString::fromLatin1(tlpSudoPasswordKey), QString()},
        {QString::fromLatin1(tlpPermissionModeKey), QString()},
        {QStringLiteral("overviewGlobalShortcutAppid"), QStringLiteral("quickshell")},
        {QStringLiteral("overviewGlobalShortcutName"), QStringLiteral("dynamic-island-overview")},
        {QStringLiteral("workspaceOverviewWindowDragButton"), 1},
        {QStringLiteral("dynamicIslandPrimaryButton"), 1},
        {QStringLiteral("dynamicIslandPrimaryAction"), QStringLiteral("toggleExpandedPlayer")},
        {QStringLiteral("dynamicIslandSecondaryButton"), 3},
        {QStringLiteral("dynamicIslandSecondaryAction"), QStringLiteral("toggleControlCenter")},
        {QStringLiteral("dynamicIslandLeftSwipeItems"), stringArray({QStringLiteral("cava"), QStringLiteral("battery")})},
        {QStringLiteral("disableAutoExpandOnTrackChange"), false},
        {QStringLiteral("enableHoverExpand"), false},
        {QStringLiteral("hoverExpandAction"), 1},
        {QStringLiteral("islandWidth"), 140},
        {QStringLiteral("islandHeight"), 38},
        {QStringLiteral("islandPositionX"), 50},
        {QStringLiteral("bodyFontSize"), 16},
        {QStringLiteral("titleFontSize"), 20},
        {QStringLiteral("iconFontSize"), 18},
    };
}

bool ensurePrivateConfigDir(const QString &filePath)
{
    const QFileInfo info(filePath);
    QDir dir(info.absolutePath());
    if (!dir.exists() && !dir.mkpath(QStringLiteral(".")))
        return false;

    QFile::setPermissions(info.absolutePath(), QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    return true;
}

QJsonObject loadUserConfig()
{
    QFile file(userConfigPath());
    if (!file.exists())
        return {};
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    QByteArray bytes = file.readAll();
    if (bytes.trimmed().isEmpty())
        return {};

    // Strip JSONC comments before parsing
    {
        QString text = QString::fromUtf8(bytes);
        // Block comments /* ... */
        static const QRegularExpression blockRe(QStringLiteral("/\\*.*?\\*/"),
            QRegularExpression::DotMatchesEverythingOption);
        text.replace(blockRe, QString());
        // Line comments //
        const QStringList lines = text.split(u'\n');
        QStringList stripped;
        bool inString = false;
        for (const QString &line : lines) {
            QString out;
            for (int i = 0; i < line.size(); ++i) {
                const QChar ch = line.at(i);
                if (ch == u'"' && (i == 0 || line.at(i - 1) != u'\\'))
                    inString = !inString;
                if (!inString && ch == u'/' && i + 1 < line.size() && line.at(i + 1) == u'/')
                    break;
                out.append(ch);
            }
            stripped.append(out);
        }
        bytes = stripped.join(u'\n').toUtf8();
    }

    QJsonParseError error;
    const QJsonDocument document = QJsonDocument::fromJson(bytes, &error);
    if (error.error != QJsonParseError::NoError || !document.isObject())
        return {};

    return document.object();
}

QString formatJsonArray(const QJsonArray &arr)
{
    QStringList items;
    for (const QJsonValue &value : arr) {
        if (value.isString())
            items.append(QStringLiteral("\"%1\"").arg(value.toString()));
    }
    return QStringLiteral("[%1]").arg(items.join(QStringLiteral(", ")));
}

QString formatUserConfig(const QJsonObject &data)
{
    auto str = [&](const QString &key, const QString &fallback = QString()) {
        const QJsonValue v = data.value(key);
        return v.isString() ? v.toString() : fallback;
    };
    auto num = [&](const QString &key, int fallback = 0) {
        const QJsonValue v = data.value(key);
        return v.isDouble() ? qRound(v.toDouble()) : fallback;
    };
    auto boolean = [&](const QString &key, bool fallback = false) {
        const QJsonValue v = data.value(key);
        return v.isBool() ? v.toBool() : fallback;
    };
    auto array = [&](const QString &key) {
        return formatJsonArray(data.value(key).toArray());
    };

    QString result;
    QTextStream t(&result);

    t << "// =============================================================================\n"
         "//  Tide Island - User Configuration\n"
         "// =============================================================================\n"
         "//  Changes take effect immediately when this file is saved.\n"
         "//  This file supports // line comments and /* block comments */.\n"
         "\n"
         "{\n"
         "    // ===========================================================================\n"
         "    //  APPEARANCE  - Island capsule size & position\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Capsule width in resting (collapsed) state, in pixels.\n"
         "    \"islandWidth\": " << num("islandWidth", 140) << ",\n"
         "\n"
         "    // Capsule height in resting state, in pixels.\n"
         "    \"islandHeight\": " << num("islandHeight", 38) << ",\n"
         "\n"
         "    // Horizontal position as percentage of screen width.\n"
         "    // 0 = left edge, 50 = center, 100 = right edge.\n"
         "    \"islandPositionX\": " << num("islandPositionX", 50) << ",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  FONTS - Families\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Icon font (requires a Nerd Font for full icon coverage).\n"
         "    \"iconFontFamily\": \"" << str("iconFontFamily", "JetBrainsMono Nerd Font") << "\",\n"
         "\n"
         "    // Body / paragraph text font.\n"
         "    \"textFontFamily\": \"" << str("textFontFamily", "Inter Display") << "\",\n"
         "\n"
         "    // Heading / hero text font.\n"
         "    \"heroFontFamily\": \"" << str("heroFontFamily", "Inter Display") << "\",\n"
         "\n"
         "    // Clock / time display font.\n"
         "    \"timeFontFamily\": \"" << str("timeFontFamily", "Inter Display") << "\",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  FONTS - Sizes\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Base pixel size for body text. Small text derives from this (e.g. bodyFontSize - 4).\n"
         "    \"bodyFontSize\": " << num("bodyFontSize", 16) << ",\n"
         "\n"
         "    // Base pixel size for headings / hero text.\n"
         "    \"titleFontSize\": " << num("titleFontSize", 20) << ",\n"
         "\n"
         "    // Base pixel size for icon glyphs.\n"
         "    \"iconFontSize\": " << num("iconFontSize", 18) << ",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  INTERACTION - Click\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Mouse button for primary click. Qt numbering: 1 = left, 2 = middle, 3 = right.\n"
         "    \"dynamicIslandPrimaryButton\": " << num("dynamicIslandPrimaryButton", 1) << ",\n"
         "\n"
         "    // Action for primary click. See the list of available actions below.\n"
         "    \"dynamicIslandPrimaryAction\": \"" << str("dynamicIslandPrimaryAction", "toggleExpandedPlayer") << "\",\n"
         "\n"
         "    // Mouse button for secondary click.\n"
         "    \"dynamicIslandSecondaryButton\": " << num("dynamicIslandSecondaryButton", 3) << ",\n"
         "\n"
         "    // Action for secondary click.\n"
         "    \"dynamicIslandSecondaryAction\": \"" << str("dynamicIslandSecondaryAction", "toggleControlCenter") << "\",\n"
         "\n"
         "    // ---- Available click actions -----------------------------------------------\n"
         "    //  \"none\"                       Do nothing\n"
         "    //  \"toggleExpandedPlayer\"       Toggle music player\n"
         "    //  \"openExpandedPlayer\"         Open music player\n"
         "    //  \"closeExpandedPlayer\"        Close music player\n"
         "    //  \"toggleControlCenter\"        Toggle control center\n"
         "    //  \"openControlCenter\"          Open control center\n"
         "    //  \"closeControlCenter\"         Close control center\n"
         "    //  \"toggleOverview\"             Toggle workspace overview\n"
         "    //  \"openOverview\"               Open workspace overview\n"
         "    //  \"closeOverview\"              Close workspace overview\n"
         "    //  \"toggleLyrics\"               Toggle lyrics / time\n"
         "    //  \"showLyrics\"                 Show lyrics view\n"
         "    //  \"showTime\"                   Show time capsule\n"
         "    //  \"restoreRestingCapsule\"      Collapse to resting state\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  INTERACTION - Left Swipe\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Components shown when swiping left on the island capsule.\n"
         "    // Available:  time, date, battery, volume, brightness,\n"
         "    //             workspace, cpu, ram, cava\n"
         "    \"dynamicIslandLeftSwipeItems\": " << array("dynamicIslandLeftSwipeItems") << ",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  WORKSPACE OVERVIEW\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Quickshell app-id for the global shortcut.\n"
         "    \"overviewGlobalShortcutAppid\": \"" << str("overviewGlobalShortcutAppid", "quickshell") << "\",\n"
         "\n"
         "    // Quickshell shortcut name (registered as SUPER+TAB in Hyprland).\n"
         "    \"overviewGlobalShortcutName\": \"" << str("overviewGlobalShortcutName", "dynamic-island-overview") << "\",\n"
         "\n"
         "    // Mouse button for dragging windows in the overview.\n"
         "    \"workspaceOverviewWindowDragButton\": " << num("workspaceOverviewWindowDragButton", 1) << ",\n"
         "\n"
         "    // Current wallpaper file path. The wallpaper picker copies the selected\n"
         "    // library image here, then uses this same file for awww and workspace overview.\n"
         "    \"wallpaperPath\": \"" << str("wallpaperPath") << "\",\n"
         "\n"
         "    // Directory scanned by the wallpaper picker.\n"
         "    \"wallpaperLibraryPath\": \"" << str("wallpaperLibraryPath") << "\",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  POWER - TLP Profile Switching\n"
         "    // ===========================================================================\n"
         "\n"
         "    // Sudo permission mode for TLP power-profile controls.\n"
         "    //  \"skip\"       Disable TLP controls entirely\n"
         "    //  \"ask\"        Prompt for password each time\n"
         "    //  \"password\"   Use the stored password below\n"
         "    \"tlpPermissionMode\": \"" << str("tlpPermissionMode") << "\",\n"
         "\n"
         "    // Sudo password. Only read when tlpPermissionMode is \"password\".\n"
         "    \"tlpSudoPassword\": \"" << str("tlpSudoPassword") << "\",\n"
         "\n"
         "\n"
         "    // ===========================================================================\n"
         "    //  OTHER\n"
         "    // ===========================================================================\n"
         "\n"
          "    // When true, the capsule stays collapsed when a new track starts playing.\n"
          "    \"disableAutoExpandOnTrackChange\": " << (boolean("disableAutoExpandOnTrackChange", false) ? "true" : "false") << ",\n"
          "\n"
          "\n"
          "    // ===========================================================================\n"
          "    //  INTERACTION - Hover\n"
          "    // ===========================================================================\n"
          "\n"
          "    // When true, hovering over the island capsule will automatically expand it.\n"
          "    \"enableHoverExpand\": " << (boolean("enableHoverExpand", false) ? "true" : "false") << ",\n"
          "\n"
          "    // What to expand when hovering.\n"
          "    //  1 = Music Player (expanded player view)\n"
          "    //  2 = Control Center\n"
          "    \"hoverExpandAction\": " << num("hoverExpandAction", 1) << "\n"
         "}\n";

    return result;
}

bool saveUserConfig(const QJsonObject &data)
{
    const QString path = userConfigPath();
    if (!ensurePrivateConfigDir(path))
        return false;

    if (userConfigExists()) {
        const QJsonObject existing = loadUserConfig();
        if (existing == data)
            return true;
    }

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    file.write(formatUserConfig(data).toUtf8());
    if (!file.commit())
        return false;

    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

bool jsonValueHasExpectedType(const QJsonValue &value, const QJsonValue &fallback)
{
    if (fallback.isString())
        return value.isString();
    if (fallback.isDouble())
        return value.isDouble();
    if (fallback.isArray())
        return value.isArray();
    if (fallback.isObject())
        return value.isObject();
    if (fallback.isBool())
        return value.isBool();

    return !value.isUndefined() && !value.isNull();
}

void mergeObjectDefaults(QJsonObject *target, const QJsonObject &fallback)
{
    for (auto it = fallback.constBegin(); it != fallback.constEnd(); ++it) {
        const QJsonValue value = target->value(it.key());
        if (!value.isUndefined() && !value.isNull() && jsonValueHasExpectedType(value, it.value()))
            continue;

        target->insert(it.key(), it.value());
    }
}

void mergeUserConfigDefaults(QJsonObject *data)
{
    const QJsonObject defaults = defaultUserConfig();
    for (auto it = defaults.constBegin(); it != defaults.constEnd(); ++it) {
        const QString key = it.key();
        const QJsonValue fallback = it.value();
        QJsonValue value = data->value(key);

        if (fallback.isObject() && value.isObject()) {
            QJsonObject object = value.toObject();
            mergeObjectDefaults(&object, fallback.toObject());
            data->insert(key, object);
            continue;
        }

        if (!value.isUndefined() && !value.isNull() && jsonValueHasExpectedType(value, fallback))
            continue;

        data->insert(key, fallback);
    }

    data->remove(QStringLiteral("controlCenterIcons"));
    data->remove(QStringLiteral("statusIcons"));
    data->remove(QStringLiteral("workspaceOverviewWindowRadius"));
    data->remove(QStringLiteral("overviewCloseKey"));
    data->remove(QStringLiteral("overviewPreviousWorkspaceKey"));
    data->remove(QStringLiteral("overviewNextWorkspaceKey"));
    data->remove(QStringLiteral("workspaceOverviewWorkspaceActivateButton"));
    data->remove(QStringLiteral("workspaceOverviewWindowFocusButton"));
    data->remove(QStringLiteral("workspaceOverviewWindowCloseButton"));
    data->remove(QStringLiteral("dynamicIslandSwipeButton"));
}

QString configString(const QJsonObject &data, const QString &key)
{
    const QJsonValue value = data.value(key);
    return value.isString() ? value.toString() : QString();
}

QString cleanInputPath(QString path)
{
    path = path.trimmed();
    path.remove(u'\'');
    path.remove(u'"');

    const QUrl url(path);
    if (url.isLocalFile())
        path = url.toLocalFile();

    return expandUserPath(path);
}

bool readableFilePath(const QString &path)
{
    const QString cleanPath = cleanInputPath(path);
    if (cleanPath.isEmpty())
        return false;

    const QFileInfo info(cleanPath);
    return info.isFile() && info.isReadable();
}

bool readableDirectoryPath(const QString &path)
{
    const QString cleanPath = cleanInputPath(path);
    if (cleanPath.isEmpty())
        return false;

    const QFileInfo info(cleanPath);
    return info.isDir() && info.isReadable();
}

QString stripComment(const QString &line)
{
    bool quoted = false;
    bool escaped = false;
    QString result;
    result.reserve(line.size());

    for (const QChar ch : line) {
        if (escaped) {
            result.append(ch);
            escaped = false;
            continue;
        }

        if (ch == u'\\') {
            result.append(ch);
            escaped = true;
            continue;
        }

        if (ch == u'"') {
            quoted = !quoted;
            result.append(ch);
            continue;
        }

        if (ch == u'#' && !quoted)
            break;

        result.append(ch);
    }

    return result.trimmed();
}

QString normalizeSpace(const QString &value)
{
    return value.simplified();
}

QStringList readHyprlandLines()
{
    QFile file(hyprlandConfigPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const QString text = QString::fromUtf8(file.readAll());
    return text.split(u'\n');
}

QHash<QString, QString> hyprlandVariables(const QStringList &lines)
{
    QHash<QString, QString> variables;
    for (const QString &line : lines) {
        const QString clean = stripComment(line);
        if (!clean.startsWith(u'$') || !clean.contains(u'='))
            continue;

        const int equals = clean.indexOf(u'=');
        const QString name = clean.left(equals).trimmed().sliced(1);
        const QString value = clean.mid(equals + 1).trimmed();
        if (!name.isEmpty())
            variables.insert(name, value);
    }

    return variables;
}

QSet<QString> resolveHyprlandMods(QString rawMods, const QHash<QString, QString> &variables)
{
    for (auto it = variables.constBegin(); it != variables.constEnd(); ++it)
        rawMods.replace(QStringLiteral("$") + it.key(), it.value());

    rawMods.replace(u'+', u' ');
    rawMods.replace(u'|', u' ');

    QSet<QString> mods;
    for (const QString &part : rawMods.split(u' ', Qt::SkipEmptyParts))
        mods.insert(part.toUpper());
    return mods;
}

bool overviewBindPresent()
{
    const QStringList lines = readHyprlandLines();
    const QHash<QString, QString> variables = hyprlandVariables(lines);
    const QString targetCommand = normalizeSpace(QString::fromLatin1(overviewBindCommand));

    for (const QString &line : lines) {
        const QString clean = stripComment(line);
        if (!clean.toLower().startsWith(QStringLiteral("bind")) || !clean.contains(u'='))
            continue;

        const int equals = clean.indexOf(u'=');
        const QString binding = clean.mid(equals + 1);
        const QStringList parts = binding.split(u',');
        if (parts.size() < 4)
            continue;

        const QString rawMods = parts.at(0).trimmed();
        const QString key = parts.at(1).trimmed();
        const QString dispatcher = parts.at(2).trimmed();
        const QString command = parts.mid(3).join(u',').trimmed();

        if (key.toUpper() != QStringLiteral("TAB") || dispatcher.toLower() != QStringLiteral("exec"))
            continue;
        if (resolveHyprlandMods(rawMods, variables) != QSet<QString>{QStringLiteral("SUPER")})
            continue;
        if (normalizeSpace(command).remove(u'\'').remove(u'"') == targetCommand)
            return true;
    }

    return false;
}

QString displayPath(const QString &path)
{
    const QString home = homePath();
    if (path == home)
        return QStringLiteral("~");
    if (path.startsWith(home + QStringLiteral("/")))
        return QStringLiteral("~") + path.sliced(home.size());
    return path;
}

bool validTlpPermissionMode(const QString &mode)
{
    return mode == QStringLiteral("skip")
        || mode == QStringLiteral("ask")
        || mode == QStringLiteral("password");
}

QStringList missingItems(QJsonObject *normalizedConfig = nullptr)
{
    QJsonObject data = loadUserConfig();
    QStringList missing;
    mergeUserConfigDefaults(&data);

    QString tlpPermissionMode = configString(data, tlpPermissionModeKey);
    const QString tlpPassword = configString(data, tlpSudoPasswordKey);
    if (tlpPermissionMode.isEmpty() && !tlpPassword.isEmpty()) {
        tlpPermissionMode = QStringLiteral("password");
        data.insert(tlpPermissionModeKey, tlpPermissionMode);
    }

    if (!readableFilePath(configString(data, wallpaperPathKey)))
        missing.append(wallpaperPathKey);
    if (!readableDirectoryPath(configString(data, wallpaperLibraryPathKey)))
        missing.append(wallpaperLibraryPathKey);
    if (!validTlpPermissionMode(tlpPermissionMode)
        || (tlpPermissionMode == QStringLiteral("password") && tlpPassword.isEmpty())) {
        missing.append(tlpSudoPasswordKey);
    }
    if (!overviewBindPresent() && configString(data, hyprlandBindModeKey) != QStringLiteral("manual"))
        missing.append(hyprlandBindKey);

    missing.removeDuplicates();
    if (normalizedConfig)
        *normalizedConfig = data;
    return missing;
}

QList<SetupStep> setupSteps(const QStringList &missing)
{
    const QList<SetupStep> ordered = {
        {QString::fromLatin1(wallpaperPathKey), QStringLiteral("Current wallpaper file")},
        {QString::fromLatin1(wallpaperLibraryPathKey), QStringLiteral("Wallpaper library directory")},
        {QString::fromLatin1(hyprlandBindKey), QStringLiteral("SUPER+TAB Hyprland binding")},
        {QString::fromLatin1(tlpSudoPasswordKey), QStringLiteral("TLP mode switching password  optional")},
    };

    QList<SetupStep> result;
    for (const SetupStep &step : ordered) {
        if (missing.contains(step.key))
            result.append(step);
    }
    return result;
}

void printWelcome(const QList<SetupStep> &steps)
{
    QTextStream out(stdout);
    out << "Welcome to Tide Island setup.\n\n";
    out << "We found a few things that need your attention before Tide Island can start:\n\n";

    for (int index = 0; index < steps.size(); ++index)
        out << "  " << index + 1 << ". " << steps.at(index).label << "\n";

    out << "\nThis setup will only write to:\n";
    out << "  " << displayPath(userConfigPath()) << "\n";
    out << "  " << displayPath(hyprlandConfigPath()) << "  if you allow it\n\n";
    out << "No system files will be changed.\n";
}

void printCheck(const QStringList &missing)
{
    QTextStream out(stdout);
    if (missing.isEmpty()) {
        out << "ok\n";
        return;
    }

    out << "missing\n";
    for (const QString &item : missing)
        out << item << '\n';
}

bool processExists(qint64 pid)
{
    if (pid <= 0)
        return false;

    if (::kill(static_cast<pid_t>(pid), 0) == 0)
        return true;
    return errno == EPERM;
}

void clearSetupLock()
{
    QFile::remove(setupLockPath());
}

QJsonObject readSetupLock()
{
    QFile file(setupLockPath());
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};

    const QJsonDocument document = QJsonDocument::fromJson(file.readAll());
    return document.isObject() ? document.object() : QJsonObject();
}

bool setupLockActive()
{
    const QJsonObject data = readSetupLock();
    const qint64 pid = static_cast<qint64>(data.value(QStringLiteral("pid")).toDouble(-1));
    if (!processExists(pid)) {
        clearSetupLock();
        return false;
    }

    const qint64 createdAt = static_cast<qint64>(data.value(QStringLiteral("createdAt")).toDouble(0));
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    if (createdAt > 0 && (now - createdAt) > setupLockMaxAgeSeconds) {
        clearSetupLock();
        return false;
    }

    return true;
}

bool writeSetupLock(qint64 pid, bool initialSetup = false)
{
    const QString path = setupLockPath();
    if (!ensurePrivateConfigDir(path))
        return false;

    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        return false;

    const QJsonObject data{
        {QStringLiteral("pid"), double(pid)},
        {QStringLiteral("createdAt"), double(QDateTime::currentSecsSinceEpoch())},
        {QStringLiteral("initialSetup"), initialSetup},
    };
    file.write(QJsonDocument(data).toJson(QJsonDocument::Compact));
    file.write("\n");
    if (!file.commit())
        return false;

    QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    return true;
}

QString readLine(const QString &prompt)
{
    QTextStream out(stdout);
    out << prompt;
    out.flush();

    char buffer[4096];
    if (!std::fgets(buffer, sizeof(buffer), stdin))
        return {};

    return QString::fromLocal8Bit(buffer).trimmed();
}

QString readHiddenLine(const QString &prompt)
{
    QTextStream out(stdout);
    out << prompt;
    out.flush();

    termios oldTermios;
    if (tcgetattr(STDIN_FILENO, &oldTermios) != 0)
        return readLine(QString());

    termios newTermios = oldTermios;
    newTermios.c_lflag &= ~ECHO;
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &newTermios);

    QTextStream in(stdin);
    char buffer[4096];
    const QString value = std::fgets(buffer, sizeof(buffer), stdin)
        ? QString::fromLocal8Bit(buffer).trimmed()
        : QString();
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &oldTermios);
    out << '\n';
    return value;
}

void printStepHeader(QTextStream &out, int step, int total, const QString &title)
{
    out << "\nStep " << step << "/" << total << ": " << title << "\n\n";
}

bool confirmYes(const QString &prompt)
{
    QTextStream out(stdout);
    while (true) {
        const QString answer = readLine(prompt).trimmed().toLower();
        if (answer.isEmpty() && std::feof(stdin))
            return false;
        if (answer.isEmpty())
            return true;
        if (answer == QStringLiteral("y") || answer == QStringLiteral("yes"))
            return true;
        if (answer == QStringLiteral("n") || answer == QStringLiteral("no"))
            return false;
        out << "Please enter y or n.\n";
    }
}

void promptWallpaper(QJsonObject *data, int step, int total)
{
    QTextStream out(stdout);
    printStepHeader(out, step, total, QStringLiteral("Current wallpaper file"));
    out << "Tide Island uses this file for the workspace overview background.\n";
    out << "The wallpaper picker will copy the selected library image to this path, then set it with awww.\n";
    out << "You can also change it in " << displayPath(userConfigPath()) << "\n\n";

    const QString current = configString(*data, wallpaperPathKey);
    if (!current.isEmpty())
        out << "Current value is not usable:\n  " << current << "\n\n";
    out.flush();

    while (true) {
        const QString value = readLine(QStringLiteral("Enter the current wallpaper image path: "));
        if (value.isEmpty() && std::feof(stdin))
            return;

        const QString cleanPath = cleanInputPath(value);
        const QFileInfo path(cleanPath);
        if (!value.isEmpty() && path.isFile() && path.isReadable()) {
            data->insert(wallpaperPathKey, path.absoluteFilePath());
            saveUserConfig(*data);
            out << "Saved wallpaper path.\n";
            return;
        }

        if (!cleanPath.isEmpty())
            out << "Checked: " << cleanPath << "\n";
        out << "That path does not exist or is not readable. Please try again.\n";
    }
}

void promptWallpaperLibrary(QJsonObject *data, int step, int total)
{
    QTextStream out(stdout);
    printStepHeader(out, step, total, QStringLiteral("Wallpaper library"));
    out << "The wallpaper picker scans this directory for candidate images.\n";
    out << "Selecting one copies it to wallpaperPath and applies wallpaperPath with awww.\n";
    out << "You can also change it in " << displayPath(userConfigPath()) << "\n\n";

    const QString current = configString(*data, wallpaperLibraryPathKey);
    if (!current.isEmpty())
        out << "Current value is not usable:\n  " << current << "\n\n";
    out.flush();

    while (true) {
        const QString value = readLine(QStringLiteral("Enter a wallpaper library directory: "));
        if (value.isEmpty() && std::feof(stdin))
            return;

        const QString cleanPath = cleanInputPath(value);
        const QFileInfo path(cleanPath);
        if (!value.isEmpty() && path.isDir() && path.isReadable()) {
            data->insert(wallpaperLibraryPathKey, path.absoluteFilePath());
            saveUserConfig(*data);
            out << "Saved wallpaper library path.\n";
            return;
        }

        if (!cleanPath.isEmpty())
            out << "Checked: " << cleanPath << "\n";
        out << "That directory does not exist or is not readable. Please try again.\n";
    }
}

void promptTlpPermissions(QJsonObject *data, int step, int total)
{
    QTextStream out(stdout);
    printStepHeader(out, step, total, QStringLiteral("TLP permissions"));
    out << "Tide Island can switch TLP modes from the control center.\n\n";
    out << "We promise we won't use your password to do anything unrelated to this.\n\n";
    out << "Choose how you want to handle permissions:\n\n";
    out << "  1. Skip this feature for now\n";
    out << "  2. Ask for password when needed\n";
    out << "  3. Input password\n\n";
    out.flush();

    while (true) {
        const QString choice = readLine(QStringLiteral("Enter 1, 2, or 3: ")).trimmed();
        if (choice.isEmpty() && std::feof(stdin))
            return;

        if (choice == QStringLiteral("1")) {
            data->insert(tlpPermissionModeKey, QStringLiteral("skip"));
            data->insert(tlpSudoPasswordKey, QString());
            saveUserConfig(*data);
            out << "Skipped TLP mode switching for now.\n";
            return;
        }

        if (choice == QStringLiteral("2")) {
            data->insert(tlpPermissionModeKey, QStringLiteral("ask"));
            data->insert(tlpSudoPasswordKey, QString());
            saveUserConfig(*data);
            out << "Tide Island will ask for permission when needed.\n";
            return;
        }

        if (choice != QStringLiteral("3")) {
            out << "Choose 1, 2, or 3.\n";
            continue;
        }

        const QString first = readHiddenLine(QStringLiteral("Enter your sudo password: "));
        if (first.isEmpty() && std::feof(stdin))
            return;

        if (first.isEmpty()) {
            out << "The password cannot be empty, or this setup will run again next time.\n";
            continue;
        }

        const QString second = readHiddenLine(QStringLiteral("Enter it again to confirm: "));
        if (first == second) {
            data->insert(tlpPermissionModeKey, QStringLiteral("password"));
            data->insert(tlpSudoPasswordKey, first);
            saveUserConfig(*data);
            out << "Saved TLP sudo password.\n";
            return;
        }

        out << "The two entries did not match. Please try again.\n";
    }
}

bool appendHyprlandBind(QString *errorMessage)
{
    if (overviewBindPresent())
        return false;

    const QString path = hyprlandConfigPath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    QString existing;
    QFile input(path);
    if (input.exists()) {
        if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
            if (errorMessage)
                *errorMessage = input.errorString();
            return false;
        }
        existing = QString::fromUtf8(input.readAll());
    }

    QFile output(path);
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        if (errorMessage)
            *errorMessage = output.errorString();
        return false;
    }

    const QString separator = existing.isEmpty() || existing.endsWith(u'\n') ? QString() : QStringLiteral("\n");
    const QString addition = QStringLiteral("\n# Tide Island workspace overview\n") + QString::fromLatin1(overviewBindLine) + QStringLiteral("\n");
    output.write((existing + separator + addition).toUtf8());
    return true;
}

bool reloadHyprland()
{
    QProcess reloadProcess;
    reloadProcess.setProgram(QStringLiteral("hyprctl"));
    reloadProcess.setArguments({QStringLiteral("reload")});
    reloadProcess.setStandardOutputFile(QProcess::nullDevice());
    reloadProcess.setStandardErrorFile(QProcess::nullDevice());
    reloadProcess.start();
    return reloadProcess.waitForFinished(5000)
        && reloadProcess.exitStatus() == QProcess::NormalExit
        && reloadProcess.exitCode() == 0;
}

void printManualHyprlandBind(QTextStream &out)
{
    out << "You can add this manually:\n\n";
    out << "  " << overviewBindLine << "\n";
}

void configureHyprlandBind(QJsonObject *data, int step, int total)
{
    QTextStream out(stdout);
    printStepHeader(out, step, total, QStringLiteral("Hyprland binding"));
    out << "Tide Island can use SUPER+TAB to toggle the workspace overview.\n\n";
    out << "The following line can be added to:\n";
    out << "  " << displayPath(hyprlandConfigPath()) << "\n\n";
    out << "  " << overviewBindLine << "\n\n";
    out.flush();

    if (!confirmYes(QStringLiteral("Add it automatically? [Y/n] "))) {
        out << "\nNo problem. Add this line manually when you're ready:\n\n";
        out << "  " << overviewBindLine << "\n";
        data->insert(hyprlandBindModeKey, QStringLiteral("manual"));
        saveUserConfig(*data);
        return;
    }

    QString errorMessage;
    const bool changed = appendHyprlandBind(&errorMessage);
    if (!changed && !errorMessage.isEmpty()) {
        out << "\nTide Island could not edit your Hyprland config.\n\n";
        printManualHyprlandBind(out);
        out << "\nDetails: " << errorMessage << "\n";
        data->insert(hyprlandBindModeKey, QStringLiteral("manual"));
        saveUserConfig(*data);
        return;
    }

    if (!changed) {
        out << "\nThe SUPER+TAB binding already exists.\n";
        return;
    }

    out << "\nAdded the SUPER+TAB binding.\n";
    if (reloadHyprland())
        out << "Reloaded Hyprland.\n";
    else
        out << "Hyprland did not reload automatically. Run hyprctl reload manually, or log out and back in.\n";
}

QString executablePath()
{
    const QString path = QCoreApplication::applicationFilePath();
    return path.isEmpty() ? QStringLiteral("tide-island-setup") : path;
}

QString findExecutable(const QString &name)
{
    const QStringList paths = envString("PATH").split(u':', Qt::SkipEmptyParts);
    for (const QString &dir : paths) {
        const QString candidate = dir + QStringLiteral("/") + name;
        const QFileInfo info(candidate);
        if (info.isFile() && info.isExecutable())
            return candidate;
    }
    return {};
}

QStringList terminalCommand(QStringList base)
{
    const QString name = QFileInfo(base.value(0)).fileName();
    const QString script = executablePath();
    const QString title = QStringLiteral("Tide Island Setup");

    if (name == QStringLiteral("kitty") || name == QStringLiteral("foot"))
        return base << QStringLiteral("--title") << title << script << QStringLiteral("--wizard");
    if (name == QStringLiteral("alacritty"))
        return base << QStringLiteral("--title") << title << QStringLiteral("-e") << script << QStringLiteral("--wizard");
    if (name == QStringLiteral("wezterm"))
        return base << QStringLiteral("start") << QStringLiteral("--") << script << QStringLiteral("--wizard");
    if (name == QStringLiteral("konsole"))
        return base << QStringLiteral("--new-tab") << QStringLiteral("-p") << QStringLiteral("tabtitle=Tide Island Setup") << QStringLiteral("-e") << script << QStringLiteral("--wizard");
    if (name == QStringLiteral("gnome-terminal"))
        return base << QStringLiteral("--title=Tide Island Setup") << QStringLiteral("--") << script << QStringLiteral("--wizard");
    if (name == QStringLiteral("xterm"))
        return base << QStringLiteral("-T") << title << QStringLiteral("-e") << script << QStringLiteral("--wizard");

    return base << QStringLiteral("-e") << script << QStringLiteral("--wizard");
}

int launchWizard()
{
    const bool initialSetup = !userConfigExists();
    QJsonObject normalized;
    const QStringList missing = missingItems(&normalized);
    if (missing.isEmpty()) {
        clearSetupLock();
        return 0;
    }

    saveUserConfig(normalized);
    if (!initialSetup)
        return 0;

    if (setupLockActive())
        return 0;

    writeSetupLock(QCoreApplication::applicationPid(), true);

    QList<QStringList> candidates;
    const QString terminal = envString("TERMINAL");
    if (!terminal.isEmpty())
        candidates.append(QProcess::splitCommand(terminal));

    for (const QString &name : {QStringLiteral("kitty"), QStringLiteral("foot"), QStringLiteral("alacritty"),
         QStringLiteral("wezterm"), QStringLiteral("ghostty"), QStringLiteral("konsole"),
         QStringLiteral("gnome-terminal"), QStringLiteral("xterm")}) {
        const QString path = findExecutable(name);
        if (!path.isEmpty())
            candidates.append({path});
    }

    for (const QStringList &candidate : candidates) {
        if (candidate.isEmpty())
            continue;

        qint64 pid = -1;
        const QStringList command = terminalCommand(candidate);
        if (!QProcess::startDetached(command.first(), command.mid(1), QString(), &pid))
            continue;

        writeSetupLock(pid, initialSetup);
        return 0;
    }

    QTextStream err(stderr);
    err << "Tide Island setup is missing configuration, but no terminal emulator was found.\n";
    err << "Run this manually: " << executablePath() << " --wizard\n";
    return 1;
}

int runWizard()
{
    const bool initialSetup = !userConfigExists()
        || readSetupLock().value(QStringLiteral("initialSetup")).toBool(false);
    writeSetupLock(QCoreApplication::applicationPid(), initialSetup);
    QJsonObject data;
    QStringList missing = missingItems(&data);
    if (missing.isEmpty()) {
        clearSetupLock();
        QTextStream(stdout) << "All complete.\n";
        return 0;
    }

    saveUserConfig(data);

    const QList<SetupStep> steps = setupSteps(missing);
    if (initialSetup)
        printWelcome(steps);

    for (int index = 0; index < steps.size(); ++index) {
        const SetupStep &step = steps.at(index);
        const int stepNumber = index + 1;
        const int stepTotal = steps.size();

        if (step.key == QString::fromLatin1(wallpaperPathKey)) {
            promptWallpaper(&data, stepNumber, stepTotal);
        } else if (step.key == QString::fromLatin1(wallpaperLibraryPathKey)) {
            promptWallpaperLibrary(&data, stepNumber, stepTotal);
        } else if (step.key == QString::fromLatin1(tlpSudoPasswordKey)) {
            promptTlpPermissions(&data, stepNumber, stepTotal);
        } else if (step.key == QString::fromLatin1(hyprlandBindKey)) {
            configureHyprlandBind(&data, stepNumber, stepTotal);
        }
    }

    QTextStream out(stdout);
    missing = missingItems(&data);
    saveUserConfig(data);
    clearSetupLock();

    if (!missing.isEmpty()) {
        out << "\nStill missing:\n";
        for (const QString &item : missing)
            out << item << '\n';
        return 1;
    }

    out << "\nSetup complete. This wizard will not appear on the next Tide Island start.\n";
    return 0;
}

void printUsage()
{
    QTextStream err(stderr);
    err << "Usage: tide-island-setup --check | --launch | --wizard\n";
}
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    const QStringList args = app.arguments().mid(1);
    if (args.size() != 1) {
        printUsage();
        return 2;
    }

    const QString arg = args.first();
    if (arg == QStringLiteral("--check")) {
        const bool initialSetup = !userConfigExists();
        QJsonObject normalized;
        const QStringList missing = missingItems(&normalized);
        if (!initialSetup)
            saveUserConfig(normalized);
        if (initialSetup && !missing.isEmpty())
            writeSetupLock(QCoreApplication::applicationPid(), true);
        printCheck(missing);
        return missing.isEmpty() ? 0 : 1;
    }

    if (arg == QStringLiteral("--launch"))
        return launchWizard();

    if (arg == QStringLiteral("--wizard"))
        return runWizard();

    printUsage();
    return 2;
}
