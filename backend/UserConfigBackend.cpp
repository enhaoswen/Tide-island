#include "UserConfigBackend.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QSet>
#include <QVariant>
#include <Qt>

#include <cmath>

namespace {
QVariantList defaultDynamicIslandLeftSwipeItems()
{
    return {QStringLiteral("cava"), QStringLiteral("battery")};
}

QByteArray stripJsonComments(const QByteArray &input)
{
    QString text = QString::fromUtf8(input);

    // Remove /* ... */ block comments
    static const QRegularExpression blockRe(QStringLiteral("/\\*.*?\\*/"), QRegularExpression::DotMatchesEverythingOption);
    text.replace(blockRe, QString());

    // Remove // line comments
    const QStringList lines = text.split(u'\n');
    QStringList stripped;
    bool inString = false;
    for (const QString &line : lines) {
        QString result;
        for (int i = 0; i < line.size(); ++i) {
            const QChar ch = line.at(i);
            if (ch == u'"' && (i == 0 || line.at(i - 1) != u'\\'))
                inString = !inString;
            if (!inString && ch == u'/' && i + 1 < line.size() && line.at(i + 1) == u'/')
                break;
            result.append(ch);
        }
        stripped.append(result);
    }
    return stripped.join(u'\n').toUtf8();
}

QString jsonString(const QJsonObject &object, QLatin1String key, const QString &fallback)
{
    const QJsonValue value = object.value(key);
    return value.isString() && !value.toString().isEmpty() ? value.toString() : fallback;
}

int jsonInt(const QJsonObject &object, QLatin1String key, int fallback)
{
    const QJsonValue value = object.value(key);
    if (!value.isDouble())
        return fallback;

    const double number = value.toDouble();
    return std::isfinite(number) ? qRound(number) : fallback;
}

QVariantList jsonArray(const QJsonObject &object, QLatin1String key, const QVariantList &fallback)
{
    const QJsonValue value = object.value(key);
    return value.isArray() ? value.toArray().toVariantList() : fallback;
}

bool jsonBool(const QJsonObject &object, QLatin1String key, bool fallback)
{
    const QJsonValue value = object.value(key);
    return value.isBool() ? value.toBool() : fallback;
}

template<typename Owner, typename T, typename Signal>
void updateField(Owner *owner, T &field, T nextValue, Signal signal)
{
    if (field == nextValue)
        return;

    field = std::move(nextValue);
    emit(owner->*signal)();
}
}

UserConfigBackend::UserConfigBackend(QObject *parent)
    : QObject(parent)
    , m_userConfigPath(configHome() + QStringLiteral("/tide-island/userconfig.json"))
    , m_dynamicIslandLeftSwipeItems(defaultDynamicIslandLeftSwipeItems())
{
    m_reloadTimer.setSingleShot(true);
    m_reloadTimer.setInterval(50);

    connect(&m_reloadTimer, &QTimer::timeout, this, &UserConfigBackend::loadConfig);
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, &UserConfigBackend::scheduleReload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, &UserConfigBackend::scheduleReload);

    loadConfig();
}

QString UserConfigBackend::userConfigPath() const
{
    return m_userConfigPath;
}

QString UserConfigBackend::configError() const
{
    return m_configError;
}

QString UserConfigBackend::defaultWallpaperPath() const
{
    return m_defaultWallpaperPath;
}

QString UserConfigBackend::defaultTlpSudoPassword() const
{
    return m_defaultTlpSudoPassword;
}

QString UserConfigBackend::wallpaperPath() const
{
    return m_wallpaperPath;
}

QString UserConfigBackend::wallpaperLibraryPath() const
{
    return m_wallpaperLibraryPath;
}

QString UserConfigBackend::iconFontFamily() const
{
    return m_iconFontFamily;
}

QString UserConfigBackend::textFontFamily() const
{
    return m_textFontFamily;
}

QString UserConfigBackend::heroFontFamily() const
{
    return m_heroFontFamily;
}

QString UserConfigBackend::timeFontFamily() const
{
    return m_timeFontFamily;
}

QString UserConfigBackend::tlpSudoPassword() const
{
    return m_tlpSudoPassword;
}

QString UserConfigBackend::tlpPermissionMode() const
{
    return m_tlpPermissionMode;
}

QString UserConfigBackend::overviewGlobalShortcutAppid() const
{
    return m_overviewGlobalShortcutAppid;
}

QString UserConfigBackend::overviewGlobalShortcutName() const
{
    return m_overviewGlobalShortcutName;
}

int UserConfigBackend::workspaceOverviewWindowDragButton() const
{
    return m_workspaceOverviewWindowDragButton;
}

int UserConfigBackend::dynamicIslandPrimaryButton() const
{
    return m_dynamicIslandPrimaryButton;
}

QString UserConfigBackend::dynamicIslandPrimaryAction() const
{
    return m_dynamicIslandPrimaryAction;
}

int UserConfigBackend::dynamicIslandSecondaryButton() const
{
    return m_dynamicIslandSecondaryButton;
}

QString UserConfigBackend::dynamicIslandSecondaryAction() const
{
    return m_dynamicIslandSecondaryAction;
}

const QVariantList &UserConfigBackend::dynamicIslandLeftSwipeItems() const
{
    return m_dynamicIslandLeftSwipeItems;
}

bool UserConfigBackend::disableAutoExpandOnTrackChange() const
{
    return m_disableAutoExpandOnTrackChange;
}

bool UserConfigBackend::enableHoverExpand() const
{
    return m_enableHoverExpand;
}

int UserConfigBackend::hoverExpandAction() const
{
    return m_hoverExpandAction;
}

int UserConfigBackend::islandWidth() const
{
    return m_islandWidth;
}

int UserConfigBackend::islandHeight() const
{
    return m_islandHeight;
}

int UserConfigBackend::islandPositionX() const
{
    return m_islandPositionX;
}

int UserConfigBackend::bodyFontSize() const
{
    return m_bodyFontSize;
}

int UserConfigBackend::titleFontSize() const
{
    return m_titleFontSize;
}

int UserConfigBackend::iconFontSize() const
{
    return m_iconFontSize;
}

void UserConfigBackend::setDefaultWallpaperPath(const QString &path)
{
    if (m_defaultWallpaperPath == path)
        return;

    m_defaultWallpaperPath = path;
    emit defaultWallpaperPathChanged();
    loadConfig();
}

void UserConfigBackend::setDefaultTlpSudoPassword(const QString &password)
{
    if (m_defaultTlpSudoPassword == password)
        return;

    m_defaultTlpSudoPassword = password;
    emit defaultTlpSudoPasswordChanged();
    loadConfig();
}

int UserConfigBackend::mouseButton(const QVariant &button) const
{
    bool ok = false;
    const int numericButton = button.toInt(&ok);
    if (!ok)
        return Qt::NoButton;

    switch (numericButton) {
    case 1:
        return Qt::LeftButton;
    case 2:
        return Qt::MiddleButton;
    case 3:
        return Qt::RightButton;
    default:
        return numericButton;
    }
}

int UserConfigBackend::mouseButtonsMask(const QVariant &buttons) const
{
    if (!buttons.isValid() || buttons.isNull())
        return Qt::NoButton;

    if (buttons.canConvert<QVariantList>()) {
        int mask = Qt::NoButton;
        const QVariantList buttonList = buttons.toList();
        for (const QVariant &button : buttonList)
            mask |= mouseButton(button);
        return mask;
    }

    return mouseButton(buttons);
}

void UserConfigBackend::reload()
{
    loadConfig();
}

void UserConfigBackend::scheduleReload()
{
    if (!m_reloadTimer.isActive())
        m_reloadTimer.start();
}

void UserConfigBackend::loadConfig()
{
    updateWatchedPaths();

    QJsonObject configObject;
    QString nextConfigError;

    QFile configFile(m_userConfigPath);
    if (configFile.exists()) {
        if (!configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            nextConfigError = QStringLiteral("Could not read %1: %2").arg(m_userConfigPath, configFile.errorString());
        } else {
            const QByteArray configBytes = configFile.readAll();
            if (!configBytes.trimmed().isEmpty()) {
                const QByteArray strippedBytes = stripJsonComments(configBytes);
                QJsonParseError parseError;
                const QJsonDocument document = QJsonDocument::fromJson(strippedBytes, &parseError);
                if (parseError.error != QJsonParseError::NoError) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1 at offset %2: %3")
                        .arg(m_userConfigPath)
                        .arg(parseError.offset)
                        .arg(parseError.errorString());
                } else if (!document.isObject()) {
                    nextConfigError = QStringLiteral("Invalid JSON in %1: root value must be an object").arg(m_userConfigPath);
                } else {
                    configObject = document.object();
                }
            }
        }
    }

    updateField(this, m_configError, nextConfigError, &UserConfigBackend::configErrorChanged);

    updateField(this, m_wallpaperPath, jsonString(configObject, QLatin1String("wallpaperPath"), m_defaultWallpaperPath), &UserConfigBackend::wallpaperPathChanged);
    updateField(this, m_wallpaperLibraryPath, jsonString(configObject, QLatin1String("wallpaperLibraryPath"), QString()), &UserConfigBackend::wallpaperLibraryPathChanged);
    updateField(this, m_iconFontFamily, jsonString(configObject, QLatin1String("iconFontFamily"), QStringLiteral("JetBrainsMono Nerd Font")), &UserConfigBackend::iconFontFamilyChanged);
    updateField(this, m_textFontFamily, jsonString(configObject, QLatin1String("textFontFamily"), QStringLiteral("Inter Display")), &UserConfigBackend::textFontFamilyChanged);
    updateField(this, m_heroFontFamily, jsonString(configObject, QLatin1String("heroFontFamily"), QStringLiteral("Inter Display")), &UserConfigBackend::heroFontFamilyChanged);
    updateField(this, m_timeFontFamily, jsonString(configObject, QLatin1String("timeFontFamily"), QStringLiteral("Inter Display")), &UserConfigBackend::timeFontFamilyChanged);
    updateField(this, m_tlpSudoPassword, jsonString(configObject, QLatin1String("tlpSudoPassword"), m_defaultTlpSudoPassword), &UserConfigBackend::tlpSudoPasswordChanged);
    updateField(this, m_tlpPermissionMode, jsonString(configObject, QLatin1String("tlpPermissionMode"), QStringLiteral("ask")), &UserConfigBackend::tlpPermissionModeChanged);
    updateField(this, m_overviewGlobalShortcutAppid, jsonString(configObject, QLatin1String("overviewGlobalShortcutAppid"), QStringLiteral("quickshell")), &UserConfigBackend::overviewGlobalShortcutAppidChanged);
    updateField(this, m_overviewGlobalShortcutName, jsonString(configObject, QLatin1String("overviewGlobalShortcutName"), QStringLiteral("dynamic-island-overview")), &UserConfigBackend::overviewGlobalShortcutNameChanged);
    updateField(this, m_workspaceOverviewWindowDragButton, jsonInt(configObject, QLatin1String("workspaceOverviewWindowDragButton"), 1), &UserConfigBackend::workspaceOverviewWindowDragButtonChanged);
    updateField(this, m_dynamicIslandPrimaryButton, jsonInt(configObject, QLatin1String("dynamicIslandPrimaryButton"), 1), &UserConfigBackend::dynamicIslandPrimaryButtonChanged);
    updateField(this, m_dynamicIslandPrimaryAction, jsonString(configObject, QLatin1String("dynamicIslandPrimaryAction"), QStringLiteral("toggleExpandedPlayer")), &UserConfigBackend::dynamicIslandPrimaryActionChanged);
    updateField(this, m_dynamicIslandSecondaryButton, jsonInt(configObject, QLatin1String("dynamicIslandSecondaryButton"), 3), &UserConfigBackend::dynamicIslandSecondaryButtonChanged);
    updateField(this, m_dynamicIslandSecondaryAction, jsonString(configObject, QLatin1String("dynamicIslandSecondaryAction"), QStringLiteral("toggleControlCenter")), &UserConfigBackend::dynamicIslandSecondaryActionChanged);
    updateField(this, m_dynamicIslandLeftSwipeItems, jsonArray(configObject, QLatin1String("dynamicIslandLeftSwipeItems"), defaultDynamicIslandLeftSwipeItems()), &UserConfigBackend::dynamicIslandLeftSwipeItemsChanged);
    updateField(this, m_disableAutoExpandOnTrackChange, jsonBool(configObject, QLatin1String("disableAutoExpandOnTrackChange"), false), &UserConfigBackend::disableAutoExpandOnTrackChangeChanged);
    updateField(this, m_enableHoverExpand, jsonBool(configObject, QLatin1String("enableHoverExpand"), false), &UserConfigBackend::enableHoverExpandChanged);
    updateField(this, m_hoverExpandAction, jsonInt(configObject, QLatin1String("hoverExpandAction"), 1), &UserConfigBackend::hoverExpandActionChanged);
    updateField(this, m_islandWidth, jsonInt(configObject, QLatin1String("islandWidth"), 140), &UserConfigBackend::islandWidthChanged);
    updateField(this, m_islandHeight, jsonInt(configObject, QLatin1String("islandHeight"), 38), &UserConfigBackend::islandHeightChanged);
    updateField(this, m_islandPositionX, jsonInt(configObject, QLatin1String("islandPositionX"), 50), &UserConfigBackend::islandPositionXChanged);
    updateField(this, m_bodyFontSize, jsonInt(configObject, QLatin1String("bodyFontSize"), 16), &UserConfigBackend::bodyFontSizeChanged);
    updateField(this, m_titleFontSize, jsonInt(configObject, QLatin1String("titleFontSize"), 20), &UserConfigBackend::titleFontSizeChanged);
    updateField(this, m_iconFontSize, jsonInt(configObject, QLatin1String("iconFontSize"), 18), &UserConfigBackend::iconFontSizeChanged);

    updateWatchedPaths();
}

void UserConfigBackend::updateWatchedPaths()
{
    const QString configDirectory = QFileInfo(m_userConfigPath).absolutePath();
    const QString configParentDirectory = QFileInfo(configDirectory).absolutePath();
    const QSet<QString> wantedFiles = QFileInfo::exists(m_userConfigPath)
        ? QSet<QString>{m_userConfigPath}
        : QSet<QString>{};
    QSet<QString> wantedDirectories;
    if (QFileInfo::exists(configParentDirectory))
        wantedDirectories.insert(configParentDirectory);
    if (QFileInfo::exists(configDirectory))
        wantedDirectories.insert(configDirectory);

    const QStringList currentFiles = m_watcher.files();
    for (const QString &path : currentFiles) {
        if (!wantedFiles.contains(path))
            m_watcher.removePath(path);
    }

    const QStringList currentDirectories = m_watcher.directories();
    for (const QString &path : currentDirectories) {
        if (!wantedDirectories.contains(path))
            m_watcher.removePath(path);
    }

    for (const QString &path : wantedFiles) {
        if (!m_watcher.files().contains(path))
            m_watcher.addPath(path);
    }

    for (const QString &path : wantedDirectories) {
        if (!m_watcher.directories().contains(path))
            m_watcher.addPath(path);
    }
}

QString UserConfigBackend::configHome() const
{
    const QByteArray xdgConfigHome = qgetenv("XDG_CONFIG_HOME");
    if (!xdgConfigHome.isEmpty())
        return QString::fromLocal8Bit(xdgConfigHome);

    const QByteArray home = qgetenv("HOME");
    return home.isEmpty()
        ? QStringLiteral(".")
        : QString::fromLocal8Bit(home) + QStringLiteral("/.config");
}
