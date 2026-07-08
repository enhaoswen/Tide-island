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
#include <QVariant>
#include <QVariantList>

namespace {
constexpr auto shortcutBindingsKey = "shortcutBindings";
constexpr auto hyprlandBindModeKey = "hyprlandBindMode";
constexpr auto tideShortcutPrefix = "/usr/bin/quickshell ipc --any-display -p /usr/share/tide-island call ";
constexpr auto legacyTideShortcutPrefix = "/usr/bin/quickshell ipc -p /usr/share/tide-island call ";

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

QVariantList defaultShortcutBindings()
{
    return {
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("TAB"), QStringLiteral("overview"), QStringLiteral("toggle")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("right"), QStringLiteral("tide"), QStringLiteral("showLyrics")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("left"), QStringLiteral("tide"), QStringLiteral("showCustom")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("down"), QStringLiteral("tide"), QStringLiteral("showClock")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("M"), QStringLiteral("tide"), QStringLiteral("togglePlayer")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("C"), QStringLiteral("tide"), QStringLiteral("toggleControlCenter")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("W"), QStringLiteral("tide"), QStringLiteral("toggleWallpaperPicker")),
        shortcutMap(QStringLiteral("SUPER"), QStringLiteral("I"), QStringLiteral("island"), QStringLiteral("toggle")),
        shortcutMap(QStringLiteral("SUPER SHIFT"), QStringLiteral("I"), QStringLiteral("island"), QStringLiteral("open")),
        shortcutMap(QStringLiteral("SUPER ALT"), QStringLiteral("I"), QStringLiteral("island"), QStringLiteral("hide")),
    };
}

QString configHome()
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    return QDir::homePath() + QStringLiteral("/.config");
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

QVariantList normalizedShortcutBindings(const QVariantList &shortcutBindings)
{
    QVariantList normalized;
    for (const QVariant &value : shortcutBindings) {
        const ShortcutBinding binding = bindingFromVariant(value);
        if (binding.key.isEmpty() || binding.target.isEmpty() || binding.method.isEmpty())
            continue;

        normalized.append(shortcutMap(binding.mods, binding.key, binding.target, binding.method));
    }
    return normalized;
}

QString shortcutCommand(const ShortcutBinding &binding)
{
    return QString::fromLatin1(tideShortcutPrefix) + binding.target + u' ' + binding.method;
}

QString hyprlandConfBindLine(const ShortcutBinding &binding)
{
    return QStringLiteral("bind = %1, %2, exec, %3")
        .arg(binding.mods, binding.key, shortcutCommand(binding));
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
    const auto it = m_userConfig.find(QString::fromLatin1(shortcutBindingsKey));
    if (it == m_userConfig.end())
        return defaultShortcutBindings();

    const QVariantList saved = it->second.toList();
    const QVariantList normalized = normalizedShortcutBindings(saved);
    return normalized.isEmpty() ? defaultShortcutBindings() : normalized;
}

bool Backend::applyShortcutBindings(const QVariantList &shortcutBindings){
    const QVariantList normalized = normalizedShortcutBindings(shortcutBindings);
    if (normalized.isEmpty()) {
        setErrorString(QStringLiteral("Shortcut bindings are empty."));
        return false;
    }

    QVariantMap data = toVariantMap();
    data.insert(QString::fromLatin1(shortcutBindingsKey), normalized);
    data.insert(QString::fromLatin1(hyprlandBindModeKey), QStringLiteral("configured"));

    if (!save(data))
        return false;

    if (!writeManagedShortcutConfig(normalized))
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
        return override.startsWith(QStringLiteral("~/")) ? QDir::homePath() + override.sliced(1) : override;

    return configHome() + QStringLiteral("/hypr/hyprland.conf");
}

QString Backend::managedShortcutConfigPath() const{
    return configHome() + QStringLiteral("/tide-island/hyprland-shortcuts.conf");
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
    lines.append(QStringLiteral("# Island commands: island toggle/open/hide."));
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
