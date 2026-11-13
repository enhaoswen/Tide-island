#pragma once

#include <QJsonObject>
#include <QVariantMap>
#include <algorithm>
#include <cmath>

namespace LockScreenConfig {
// Shared by the settings preview and the shell. Never store authentication data here.
inline QVariantMap normalized(const QJsonObject &input = {})
{
    QVariantMap values {
        {"showAvatar", true}, {"showName", true}, {"showClock", true},
        {"showDate", true}, {"showMusic", true}, {"showWeather", true},
        {"showTrackInfo", true}, {"showAlbumArt", true},
        {"showBattery", true}, {"showSeconds", false}, {"use24Hour", true},
        {"showPowerActions", true}, {"idleDim", true},
        {"customLayoutEnabled", false},
        {"displayName", ""}, {"avatarPath", ""}, {"wallpaperPath", ""},
        {"message", ""}, {"layout", "dashboard"},
        {"blur", 48}, {"dim", 32}, {"cardOpacity", 82}, {"radius", 28}
    };
    for (auto it = values.begin(); it != values.end(); ++it) {
        const auto value = input.value(it.key());
        if (it->metaType().id() == QMetaType::Bool && value.isBool())
            it.value() = value.toBool();
        else if (it->metaType().id() == QMetaType::QString && value.isString())
            it.value() = value.toString().left(it.key() == "message" ? 180 : it.key() == "displayName" ? 80 : 4096);
        else if (it->metaType().id() == QMetaType::Int && value.isDouble() && std::isfinite(value.toDouble()))
            it.value() = qRound(std::clamp(value.toDouble(), 0.0, 100.0));
    }
    values["radius"] = std::clamp(values["radius"].toInt(), 12, 40);
    // Keep older configurations compatible with the sole built-in layout.
    values["layout"] = "dashboard";
    QVariantMap positions;
    const QJsonObject configuredPositions = input.value("positions").toObject();
    for (const char *key : {"profile", "clock", "password", "weather", "music"}) {
        const auto point = configuredPositions.value(QLatin1String(key)).toObject();
        const auto x = point.value("x");
        const auto y = point.value("y");
        if (x.isDouble() && y.isDouble() && std::isfinite(x.toDouble()) && std::isfinite(y.toDouble()))
            positions.insert(QLatin1String(key), QVariantMap {
                {"x", std::clamp(x.toDouble(), 0.0, 1.0)},
                {"y", std::clamp(y.toDouble(), 0.0, 1.0)}
            });
    }
    values.insert("positions", positions);
    return values;
}
}
