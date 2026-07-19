#include "backend.hpp"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QProcess>
#include <QSaveFile>
#include <QTemporaryFile>
#include <QVariant>
#include <QVariantList>

namespace {
constexpr auto shortcutBindingsKey = "shortcutBindings";
constexpr auto tideShortcutPrefix = "/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call ";
constexpr auto legacyTideShortcutPrefix = "/usr/bin/quickshell ipc -p /usr/share/tide-island call ";
constexpr auto quickshellPath = "/usr/bin/quickshell";
constexpr auto tideQmlPath = "/usr/share/tide-island";

struct ShortcutBinding {
    QString mods;
    QString key;
    QString target;
    QString method;
};

QVariantMap shortcutMap(const QString &mods, const QString &key, const QString &target, const QString &method)
{
    return {
        {QStringLiteral("mods"), mods},
        {QStringLiteral("key"), key},
        {QStringLiteral("target"), target},
        {QStringLiteral("method"), method},
    };
}

bool isOverviewBinding(const ShortcutBinding &binding)
{
    return binding.target.compare(QStringLiteral("overview"), Qt::CaseInsensitive) == 0;
}

QVariantList defaultShortcutBindings()
{
    return {
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("TAB"), QStringLiteral("overview"), QStringLiteral("toggle")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("right"), QStringLiteral("tide"), QStringLiteral("swipeRight")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("left"), QStringLiteral("tide"), QStringLiteral("showCustom")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("down"), QStringLiteral("tide"), QStringLiteral("showClock")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("M"), QStringLiteral("tide"), QStringLiteral("togglePlayer")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("C"), QStringLiteral("tide"), QStringLiteral("toggleControlCenter")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("N"), QStringLiteral("tide"), QStringLiteral("toggleNotificationCenter")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("W"), QStringLiteral("tide"), QStringLiteral("toggleWallpaperPicker")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("F"), QStringLiteral("island"), QStringLiteral("toggle")),
    };
}

QString configHome()
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    return QDir::homePath() + QStringLiteral("/.config");
}

QString expandedPath(const QString &path)
{
    return path.startsWith(QStringLiteral("~/")) ? QDir::homePath() + path.sliced(1) : path;
}

bool desktopEnvironmentContains(const QString &desktopNames, const QString &desktop)
{
    const QStringList names = desktopNames.split(u':', Qt::SkipEmptyParts);
    for (const QString &name : names) {
        if (name.trimmed().compare(desktop, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

QString cleanShortcutPart(const QVariant &value)
{
    QString text = value.toString().trimmed();
    text.replace(u'\n', u' ');
    text.replace(u'\r', u' ');
    text.replace(u',', u' ');
    return text.simplified();
}

ShortcutBinding bindingFromVariant(const QVariant &value)
{
    const QVariantMap map = value.toMap();
    return {
        cleanShortcutPart(map.value(QStringLiteral("mods"))),
        cleanShortcutPart(map.value(QStringLiteral("key"))),
        cleanShortcutPart(map.value(QStringLiteral("target"))),
        cleanShortcutPart(map.value(QStringLiteral("method"))),
    };
}

QVariantList filteredShortcutBindingsForCapabilities(const QVariantList &shortcutBindings, bool includeWorkspaceOverview)
{
    QVariantList filtered;
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        if (!includeWorkspaceOverview && isOverviewBinding(binding))
            continue;
        filtered.append(value);
    }
    return filtered;
}

bool isIslandBinding(const ShortcutBinding &binding)
{
    return binding.target.compare(QStringLiteral("island"), Qt::CaseInsensitive) == 0;
}

ShortcutBinding migratedShortcutBinding(ShortcutBinding binding)
{
    if (isIslandBinding(binding)
        && binding.method.compare(QStringLiteral("toggle"), Qt::CaseInsensitive) == 0
        && binding.mods.compare(QStringLiteral("SUPER"), Qt::CaseInsensitive) == 0
        && binding.key.compare(QStringLiteral("I"), Qt::CaseInsensitive) == 0) {
        binding.key = QStringLiteral("F");
    }

    if (binding.target.compare(QStringLiteral("tide"), Qt::CaseInsensitive) == 0
        && binding.method.compare(QStringLiteral("showLyrics"), Qt::CaseInsensitive) == 0
        && binding.mods.compare(QStringLiteral("SUPER"), Qt::CaseInsensitive) == 0
        && binding.key.compare(QStringLiteral("right"), Qt::CaseInsensitive) == 0) {
        binding.method = QStringLiteral("swipeRight");
    }

    return binding;
}

QVariantList normalizedShortcutBindings(const QVariantList &shortcutBindings)
{
    QVariantList normalized;
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = migratedShortcutBinding(bindingFromVariant(value));
        if (binding.key.isEmpty() || binding.target.isEmpty() || binding.method.isEmpty())
            continue;
        if (isIslandBinding(binding) && binding.method.compare(QStringLiteral("toggle"), Qt::CaseInsensitive) != 0)
            continue;

        normalized.append(shortcutMap(binding.mods, binding.key, binding.target, binding.method));
    }
    return normalized;
}

QString shortcutIdentity(const ShortcutBinding &binding)
{
    return binding.target.toLower() + u':' + binding.method.toLower();
}

QVariantList mergedShortcutBindings(const QVariantList &baseBindings, const QVariantList &updates)
{
    QVariantList merged = normalizedShortcutBindings(baseBindings);
    const QVariantList normalizedUpdates = normalizedShortcutBindings(updates);

    for (const QVariant &value : normalizedUpdates) {
        const QString identity = shortcutIdentity(bindingFromVariant(value));
        bool replaced = false;
        for (qsizetype index = 0; index < merged.size(); ++index) {
            if (shortcutIdentity(bindingFromVariant(merged.at(index))) == identity) {
                merged[index] = value;
                replaced = true;
                break;
            }
        }
        if (!replaced)
            merged.append(value);
    }

    return merged;
}

QString shortcutCommand(const ShortcutBinding &binding)
{
    return QString::fromLatin1(tideShortcutPrefix) + binding.target + u' ' + binding.method;
}

QStringList shortcutCommandArgs(const ShortcutBinding &binding)
{
    return {
        QString::fromLatin1(quickshellPath),
        QStringLiteral("ipc"),
        QStringLiteral("--any-display"),
        QStringLiteral("-p"),
        QString::fromLatin1(tideQmlPath),
        QStringLiteral("call"),
        binding.target,
        binding.method,
    };
}

QString hyprlandConfBindLine(const ShortcutBinding &binding)
{
    return QStringLiteral("bind = %1, %2, exec, %3")
        .arg(binding.mods, binding.key, shortcutCommand(binding));
}

QString kdlQuote(QString value)
{
    value.replace(u'\\', QStringLiteral("\\\\"));
    value.replace(u'"', QStringLiteral("\\\""));
    value.replace(u'\n', QStringLiteral("\\n"));
    value.replace(u'\r', QStringLiteral("\\r"));
    return u'"' + value + u'"';
}

QString niriModifierName(const QString &modifier)
{
    const QString normalized = modifier.trimmed().toUpper();
    if (normalized == QStringLiteral("SUPER") || normalized == QStringLiteral("MOD"))
        return QStringLiteral("Super");
    if (normalized == QStringLiteral("CTRL") || normalized == QStringLiteral("CONTROL"))
        return QStringLiteral("Ctrl");
    if (normalized == QStringLiteral("ALT"))
        return QStringLiteral("Alt");
    if (normalized == QStringLiteral("SHIFT"))
        return QStringLiteral("Shift");
    return modifier.trimmed();
}

QString niriKeyName(const QString &key)
{
    const QString normalized = key.trimmed();
    const QString lower = normalized.toLower();
    const QString upper = normalized.toUpper();

    if (upper == QStringLiteral("TAB"))
        return QStringLiteral("Tab");
    if (lower == QStringLiteral("left"))
        return QStringLiteral("Left");
    if (lower == QStringLiteral("right"))
        return QStringLiteral("Right");
    if (lower == QStringLiteral("up"))
        return QStringLiteral("Up");
    if (lower == QStringLiteral("down"))
        return QStringLiteral("Down");
    if (lower == QStringLiteral("space"))
        return QStringLiteral("space");
    if (lower == QStringLiteral("return") || lower == QStringLiteral("enter"))
        return QStringLiteral("Return");
    if (lower == QStringLiteral("backspace"))
        return QStringLiteral("BackSpace");
    if (lower == QStringLiteral("delete"))
        return QStringLiteral("Delete");
    if (lower == QStringLiteral("insert"))
        return QStringLiteral("Insert");
    if (lower == QStringLiteral("home"))
        return QStringLiteral("Home");
    if (lower == QStringLiteral("end"))
        return QStringLiteral("End");
    if (lower == QStringLiteral("page_up"))
        return QStringLiteral("Page_Up");
    if (lower == QStringLiteral("page_down"))
        return QStringLiteral("Page_Down");

    return normalized;
}

QString niriBindChord(ShortcutBinding binding)
{
    QStringList parts;
    binding.mods.replace(u'+', u' ');
    const QStringList mods = binding.mods.split(u' ', Qt::SkipEmptyParts);
    for (const QString &modifier : mods) {
        const QString name = niriModifierName(modifier);
        if (!name.isEmpty())
            parts.append(name);
    }

    const QString key = niriKeyName(binding.key);
    if (!key.isEmpty())
        parts.append(key);

    return parts.join(u'+');
}

QString niriSpawnLine(const ShortcutBinding &binding)
{
    QStringList quotedArgs;
    const QStringList args = shortcutCommandArgs(binding);
    quotedArgs.reserve(args.size());
    for (const QString &arg : args)
        quotedArgs.append(kdlQuote(arg));

    return QStringLiteral("    %1 { spawn %2; }").arg(niriBindChord(binding), quotedArgs.join(u' '));
}

QString niriConfigForBindings(const QVariantList &shortcutBindings)
{
    QStringList lines;
    lines.append(QStringLiteral("// Generated by Tide Island. Edit shortcuts in the Tide Island config app."));
    lines.append(QStringLiteral("// These binds call Quickshell IPC; the same commands can be reused in scripts."));
    lines.append(QStringLiteral("binds {"));

    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        if (niriBindChord(binding).isEmpty())
            continue;
        lines.append(niriSpawnLine(binding));
    }

    lines.append(QStringLiteral("}"));
    lines.append(QString());
    return lines.join(u'\n');
}

QByteArray stripJsonComments(const QByteArray &input){
    QByteArray output;
    output.reserve(input.size());

    enum class State {
        Normal,
        String,
        LineComment,
        BlockComment,
    };

    State state = State::Normal;
    bool escaped = false;

    for (qsizetype i = 0; i < input.size(); ++i) {
        const char ch = input.at(i);
        const char next = i + 1 < input.size() ? input.at(i + 1) : '\0';

        switch (state) {
        case State::Normal:
            if (ch == '"') {
                output.append(ch);
                state = State::String;
            } else if (ch == '/' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::LineComment;
            } else if (ch == '/' && next == '*') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::BlockComment;
            } else {
                output.append(ch);
            }
            break;
        case State::String:
            output.append(ch);
            if (escaped) {
                escaped = false;
            } else if (ch == '\\') {
                escaped = true;
            } else if (ch == '"') {
                state = State::Normal;
            }
            break;
        case State::LineComment:
            if (ch == '\n' || ch == '\r') {
                output.append(ch);
                state = State::Normal;
            } else {
                output.append(' ');
            }
            break;
        case State::BlockComment:
            if (ch == '*' && next == '/') {
                output.append(' ');
                output.append(' ');
                ++i;
                state = State::Normal;
            } else if (ch == '\n' || ch == '\r') {
                output.append(ch);
            } else {
                output.append(' ');
            }
            break;
        }
    }

    return output;
}

UserConfigMap toUserConfigMap(const QVariantMap &userConfig){
    UserConfigMap result;
    result.reserve(static_cast<std::size_t>(userConfig.size()));

    for (auto it = userConfig.cbegin(); it != userConfig.cend(); ++it)
        result.emplace(it.key(), it.value());

    return result;
}
}

std::size_t QStringHash::operator()(const QString &key) const noexcept{
    return static_cast<std::size_t>(qHash(key));
}

Backend::Backend(QObject *parent) : QObject(parent), m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json")){
    load();
}

QString Backend::userConfigPath() const{
    return m_userConfigPath;
}

QString Backend::errorString() const{
    return m_errorString;
}

QVariantMap Backend::userConfig() const{
    return toVariantMap();
}

bool Backend::save(const QVariantMap &userConfig){
    const QFileInfo configInfo(m_userConfigPath);
    QDir directory(configInfo.absolutePath());
    if (!directory.exists() && !QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    const QJsonDocument document = QJsonDocument::fromVariant(userConfig);
    if (!document.isObject()) {
        setErrorString(QStringLiteral("User config must be a JSON object."));
        return false;
    }

    QSaveFile file(m_userConfigPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    file.write(document.toJson(QJsonDocument::Indented));
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(m_userConfigPath, file.errorString()));
        return false;
    }

    setUserConfig(userConfig);
    setErrorString(QString());
    return true;
}

bool Backend::copyToClipboard(const QString &text){
    QClipboard *clipboard = QGuiApplication::clipboard();
    if (!clipboard) {
        setErrorString(QStringLiteral("Clipboard is not available."));
        return false;
    }

    clipboard->setText(text);
    setErrorString(QString());
    return true;
}

QVariantList Backend::shortcutBindings() const{
    const bool includeWorkspaceOverview = supportsTideWorkspaceOverview();
    QVariantList bindings = defaultShortcutBindings();
    const auto it = m_userConfig.find(QString::fromLatin1(shortcutBindingsKey));
    if (it != m_userConfig.end())
        bindings = mergedShortcutBindings(bindings, it->second.toList());

    return filteredShortcutBindingsForCapabilities(
        bindings,
        includeWorkspaceOverview);
}

QString Backend::currentCompositor() const{
    const QString requested = QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_COMPOSITOR")).trimmed().toLower();
    if (requested == QStringLiteral("niri"))
        return QStringLiteral("niri");
    if (requested == QStringLiteral("hypr") || requested == QStringLiteral("hyprland"))
        return QStringLiteral("hyprland");

    if (desktopEnvironmentContains(
            QString::fromLocal8Bit(qgetenv("XDG_CURRENT_DESKTOP")),
            QStringLiteral("niri"))) {
        return QStringLiteral("niri");
    }

    if (desktopEnvironmentContains(
            QString::fromLocal8Bit(qgetenv("XDG_CURRENT_DESKTOP")),
            QStringLiteral("hyprland"))) {
        return QStringLiteral("hyprland");
    }

    if (!qEnvironmentVariableIsEmpty("NIRI_SOCKET"))
        return QStringLiteral("niri");

    return QStringLiteral("hyprland");
}

QString Backend::compositorDisplayName() const{
    return currentCompositor() == QStringLiteral("niri")
        ? QStringLiteral("niri")
        : QStringLiteral("Hyprland");
}

bool Backend::supportsTideWorkspaceOverview() const{
    return currentCompositor() == QStringLiteral("hyprland");
}

bool Backend::supportsHyprlandShortcutSnippets() const{
    return currentCompositor() == QStringLiteral("hyprland");
}

bool Backend::supportsNiriShortcutSnippets() const{
    return currentCompositor() != QStringLiteral("hyprland");
}

QString Backend::nightLightBackendName() const{
    return currentCompositor() == QStringLiteral("hyprland")
        ? QStringLiteral("hyprsunset")
        : QStringLiteral("gammastep");
}

QString Backend::niriConfigCommands() const{
    return niriConfigForBindings(filteredShortcutBindingsForCapabilities(
        normalizedShortcutBindings(shortcutBindings()),
        false));
}

bool Backend::niriShortcutBindingsNeedApply() const{
    if (!QFileInfo::exists(niriConfigPath()))
        return false;

    const QVariantList bindings = filteredShortcutBindingsForCapabilities(
        normalizedShortcutBindings(shortcutBindings()),
        false);
    QFile managedConfig(managedNiriShortcutConfigPath());
    if (!managedConfig.open(QIODevice::ReadOnly | QIODevice::Text)
        || QString::fromUtf8(managedConfig.readAll()) != niriConfigForBindings(bindings)) {
        return true;
    }

    QFile compositorConfig(niriConfigPath());
    if (!compositorConfig.open(QIODevice::ReadOnly | QIODevice::Text))
        return true;

    const QString includeLine = QStringLiteral("include %1").arg(kdlQuote(managedNiriShortcutConfigPath()));
    const QStringList lines = QString::fromUtf8(compositorConfig.readAll()).split(u'\n');
    for (const QString &line : lines) {
        if (line.trimmed() == includeLine)
            return false;
    }

    return true;
}

bool Backend::ensureNiriShortcutBindings(){
    if (!QFileInfo::exists(niriConfigPath())) {
        setErrorString(QStringLiteral("Niri config does not exist: %1").arg(niriConfigPath()));
        return false;
    }

    const QVariantList bindings = filteredShortcutBindingsForCapabilities(
        normalizedShortcutBindings(shortcutBindings()),
        false);
    if (bindings.isEmpty()) {
        setErrorString(QStringLiteral("Niri shortcut bindings are empty."));
        return false;
    }

    if (!installManagedNiriShortcutConfig(bindings))
        return false;

    setErrorString(QString());
    return true;
}

bool Backend::applyShortcutBindings(const QVariantList &shortcutBindings){
    const bool includeWorkspaceOverview = supportsTideWorkspaceOverview();
    const QVariantList updates = normalizedShortcutBindings(shortcutBindings);
    if (updates.isEmpty()) {
        setErrorString(QStringLiteral("Shortcut bindings are empty."));
        return false;
    }

    QVariantList savedBindings = defaultShortcutBindings();
    const auto savedIt = m_userConfig.find(QString::fromLatin1(shortcutBindingsKey));
    if (savedIt != m_userConfig.end())
        savedBindings = mergedShortcutBindings(savedBindings, savedIt->second.toList());
    const QVariantList completeBindings = mergedShortcutBindings(savedBindings, updates);
    const QVariantList compositorBindings = filteredShortcutBindingsForCapabilities(
        completeBindings,
        includeWorkspaceOverview);

    QVariantMap data = toVariantMap();
    data.insert(QString::fromLatin1(shortcutBindingsKey), completeBindings);

    if (!save(data))
        return false;

    if (currentCompositor() == QStringLiteral("niri"))
        return ensureNiriShortcutBindings();

    if (QFileInfo::exists(niriConfigPath()) && !ensureNiriShortcutBindings())
        return false;

    if (!writeManagedShortcutConfig(compositorBindings))
        return false;

    if (!ensureManagedShortcutSource())
        return false;

    if (!reloadHyprland()) {
        setErrorString(QStringLiteral("Saved shortcuts, but Hyprland did not reload. Run hyprctl reload or restart Hyprland."));
        return false;
    }

    setErrorString(QString());
    return true;
}

QString Backend::hyprlandConfigPath() const{
    const QString override = QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_HYPRLAND_CONFIG"));
    if (!override.isEmpty())
        return expandedPath(override);

    return configHome() + QStringLiteral("/hypr/hyprland.conf");
}

QString Backend::niriConfigPath() const{
    const QString override = QString::fromLocal8Bit(qgetenv("TIDE_ISLAND_NIRI_CONFIG"));
    if (!override.isEmpty())
        return expandedPath(override);

    const QString niriConfig = QString::fromLocal8Bit(qgetenv("NIRI_CONFIG"));
    if (!niriConfig.isEmpty())
        return expandedPath(niriConfig);

    return configHome() + QStringLiteral("/niri/config.kdl");
}

QString Backend::managedShortcutConfigPath() const{
    return configHome() + QStringLiteral("/tide-island/hyprland-shortcuts.conf");
}

QString Backend::managedNiriShortcutConfigPath() const{
    return configHome() + QStringLiteral("/tide-island/niri-shortcuts.kdl");
}

bool Backend::writeManagedShortcutConfig(const QVariantList &shortcutBindings){
    const QFileInfo configInfo(managedShortcutConfigPath());
    if (!QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    QStringList lines;
    lines.append(QStringLiteral("# Generated by Tide Island. Edit shortcuts in the Tide Island config app."));
    lines.append(QStringLiteral("# These binds call Quickshell IPC; the same commands can be reused in scripts."));
    lines.append(QStringLiteral("# Island command: island toggle."));
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        lines.append(hyprlandConfBindLine(binding));
    }
    lines.append(QString());

    QSaveFile file(configInfo.absoluteFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    file.write(lines.join(u'\n').toUtf8());
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    return true;
}

bool Backend::installManagedNiriShortcutConfig(const QVariantList &shortcutBindings){
    const QFileInfo mainConfigInfo(niriConfigPath());
    QFile mainConfig(mainConfigInfo.absoluteFilePath());
    if (!mainConfig.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not read %1: %2").arg(mainConfigInfo.absoluteFilePath(), mainConfig.errorString()));
        return false;
    }
    const QString existingMainConfig = QString::fromUtf8(mainConfig.readAll());

    const QFileInfo managedConfigInfo(managedNiriShortcutConfigPath());
    if (!QDir().mkpath(managedConfigInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(managedConfigInfo.absolutePath()));
        return false;
    }

    const QByteArray managedConfigContents = niriConfigForBindings(shortcutBindings).toUtf8();
    QTemporaryFile candidateManagedConfig(
        managedConfigInfo.absolutePath() + QStringLiteral("/.niri-shortcuts-XXXXXX.kdl"));
    candidateManagedConfig.setAutoRemove(true);
    if (!candidateManagedConfig.open()) {
        setErrorString(QStringLiteral("Could not create a temporary niri shortcut config."));
        return false;
    }
    candidateManagedConfig.write(managedConfigContents);
    candidateManagedConfig.flush();

    const QString managedIncludeLine = QStringLiteral("include %1").arg(kdlQuote(managedConfigInfo.absoluteFilePath()));
    const QString candidateIncludeLine = QStringLiteral("include %1").arg(kdlQuote(candidateManagedConfig.fileName()));
    const QStringList existingLines = existingMainConfig.split(u'\n');
    QStringList validationLines;
    validationLines.reserve(existingLines.size() + 3);
    bool includePresent = false;
    for (const QString &line : existingLines) {
        if (line.trimmed() == managedIncludeLine) {
            includePresent = true;
            validationLines.append(candidateIncludeLine);
        } else {
            validationLines.append(line);
        }
    }
    if (!includePresent) {
        if (!validationLines.isEmpty() && !validationLines.last().trimmed().isEmpty())
            validationLines.append(QString());
        validationLines.append(QStringLiteral("// Tide Island shortcut bindings"));
        validationLines.append(candidateIncludeLine);
    }

    QString validationConfig = validationLines.join(u'\n');
    if (!validationConfig.endsWith(u'\n'))
        validationConfig.append(u'\n');
    if (!validateNiriConfig(validationConfig))
        return false;

    QSaveFile managedConfig(managedConfigInfo.absoluteFilePath());
    if (!managedConfig.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(managedConfigInfo.absoluteFilePath(), managedConfig.errorString()));
        return false;
    }
    managedConfig.write(managedConfigContents);
    if (!managedConfig.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(managedConfigInfo.absoluteFilePath(), managedConfig.errorString()));
        return false;
    }

    if (includePresent)
        return true;

    QStringList outputLines = existingLines;
    if (!outputLines.isEmpty() && !outputLines.last().trimmed().isEmpty())
        outputLines.append(QString());
    outputLines.append(QStringLiteral("// Tide Island shortcut bindings"));
    outputLines.append(managedIncludeLine);
    QString output = outputLines.join(u'\n');
    if (!output.endsWith(u'\n'))
        output.append(u'\n');

    QSaveFile outputConfig(mainConfigInfo.absoluteFilePath());
    if (!outputConfig.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(mainConfigInfo.absoluteFilePath(), outputConfig.errorString()));
        return false;
    }
    outputConfig.write(output.toUtf8());
    if (!outputConfig.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(mainConfigInfo.absoluteFilePath(), outputConfig.errorString()));
        return false;
    }

    return true;
}

bool Backend::ensureManagedShortcutSource(){
    const QFileInfo configInfo(hyprlandConfigPath());
    if (!QDir().mkpath(configInfo.absolutePath())) {
        setErrorString(QStringLiteral("Could not create %1").arg(configInfo.absolutePath()));
        return false;
    }

    QString existing;
    QFile input(configInfo.absoluteFilePath());
    if (input.exists()) {
        if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) {
            setErrorString(QStringLiteral("Could not read %1: %2").arg(configInfo.absoluteFilePath(), input.errorString()));
            return false;
        }
        existing = QString::fromUtf8(input.readAll());
    }

    const QString sourcePath = managedShortcutConfigPath();
    const QString sourceLine = QStringLiteral("source = %1").arg(sourcePath);
    const QStringList inputLines = existing.split(u'\n');
    QStringList outputLines;
    outputLines.reserve(inputLines.size() + 4);

    bool sourcePresent = false;
    for (const QString &line : inputLines) {
        const QString trimmed = line.trimmed();
        if (trimmed == sourceLine) {
            sourcePresent = true;
            outputLines.append(line);
            continue;
        }

        if (trimmed.contains(QString::fromLatin1(tideShortcutPrefix))
            || trimmed.contains(QString::fromLatin1(legacyTideShortcutPrefix)))
            continue;
        if (trimmed == QStringLiteral("# Tide Island shortcuts")
            || trimmed == QStringLiteral("# Tide Island shortcut bindings"))
            continue;

        outputLines.append(line);
    }

    if (!sourcePresent) {
        if (!outputLines.isEmpty() && !outputLines.last().trimmed().isEmpty())
            outputLines.append(QString());
        outputLines.append(QStringLiteral("# Tide Island shortcut bindings"));
        outputLines.append(QStringLiteral("# Generated binds are stored in ~/.config/tide-island/hyprland-shortcuts.conf."));
        outputLines.append(QStringLiteral("# They call Quickshell IPC and can also be reused from your own scripts."));
        outputLines.append(sourceLine);
    }

    QString output = outputLines.join(u'\n');
    if (!output.endsWith(u'\n'))
        output.append(u'\n');

    QSaveFile file(configInfo.absoluteFilePath());
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        setErrorString(QStringLiteral("Could not write %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    file.write(output.toUtf8());
    if (!file.commit()) {
        setErrorString(QStringLiteral("Could not save %1: %2").arg(configInfo.absoluteFilePath(), file.errorString()));
        return false;
    }

    return true;
}

bool Backend::reloadHyprland(){
    QProcess process;
    process.setProgram(QStringLiteral("hyprctl"));
    process.setArguments({QStringLiteral("reload")});
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
    process.start();
    return process.waitForFinished(5000)
        && process.exitStatus() == QProcess::NormalExit
        && process.exitCode() == 0;
}

bool Backend::validateNiriConfig(const QString &configText){
    const QString configDirectory = QFileInfo(niriConfigPath()).absolutePath();
    QTemporaryFile tempFile(configDirectory + QStringLiteral("/.tide-island-niri-validate-XXXXXX.kdl"));
    tempFile.setAutoRemove(true);
    if (!tempFile.open()) {
        setErrorString(QStringLiteral("Could not create a temporary niri config for validation."));
        return false;
    }

    tempFile.write(configText.toUtf8());
    tempFile.flush();

    QProcess process;
    process.setProgram(QStringLiteral("niri"));
    process.setArguments({QStringLiteral("validate"), QStringLiteral("-c"), tempFile.fileName()});
    process.start();
    if (!process.waitForStarted(3000)) {
        setErrorString(QStringLiteral("Could not run niri validate. Install niri or check PATH."));
        return false;
    }

    if (!process.waitForFinished(5000)) {
        process.kill();
        process.waitForFinished(1000);
        setErrorString(QStringLiteral("niri validate timed out."));
        return false;
    }

    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
        QString output = QString::fromUtf8(process.readAllStandardError()).trimmed();
        if (output.isEmpty())
            output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        if (output.isEmpty())
            output = QStringLiteral("niri validate failed.");
        setErrorString(output);
        return false;
    }

    return true;
}

void Backend::load(){
    QFile file(m_userConfigPath);
    if (!file.exists()) {
        setUserConfig({});
        setErrorString(QString());
        return;
    }

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setUserConfig({});
        setErrorString(QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, file.errorString()));
        return;
    }

    const QByteArray contents = file.readAll();
    if (contents.trimmed().isEmpty()) {
        setUserConfig({});
        setErrorString(QString());
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(stripJsonComments(contents), &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        setUserConfig({});
        setErrorString(QStringLiteral("Invalid JSON in %1 at offset %2: %3")
            .arg(m_userConfigPath)
            .arg(parseError.offset)
            .arg(parseError.errorString()));
        return;
    }

    if (!document.isObject()) {
        setUserConfig({});
        setErrorString(QStringLiteral("Invalid JSON in %1: root value must be an object.").arg(m_userConfigPath));
        return;
    }

    setUserConfig(document.object().toVariantMap());
    setErrorString(QString());
}

void Backend::setErrorString(const QString &errorString){
    if (m_errorString == errorString)
        return;

    m_errorString = errorString;
    emit errorStringChanged();
}

QVariantMap Backend::toVariantMap() const{
    QVariantMap result;
    for (const auto &[key, value] : m_userConfig)
        result.insert(key, value);
    return result;
}

void Backend::setUserConfig(const QVariantMap &userConfig){
    m_userConfig = toUserConfigMap(userConfig);
}
