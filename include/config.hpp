#pragma once

#include <expected>

#include "json.hpp"

namespace Config {

std::expected<nlohmann::json, const char*> read();
std::expected<nlohmann::json, const char*> get_config();
std::expected<void, const char*> write(nlohmann::json& config);
std::expected<void, const char*> init();
}
