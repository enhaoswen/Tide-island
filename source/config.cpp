#include "config.hpp"
#include "log.hpp"

#include <filesystem>
#include <fstream>
#include <cstdlib>

using namespace std;
using namespace std::filesystem;
using namespace nlohmann;

namespace {

json template_config{
    {"surface_width", 140},
    {"surface_height", 40},
    {"island_width", 140},
    {"island_height", 38},
    {"anchor_top", 2},
    {"zone", -1},
    {"radius", 19},
};

path config_path;
json config{};

path get_config_path(){
    const char* home = std::getenv("HOME");

    if (home == nullptr) {
        Log::fatal("HOME is not set");
    }

    return path(home) / ".config" / "Tide Island" / "config.json";
}

} // namespace

json fix_config(json arg_config){

    if (arg_config.empty()){
        return template_config;
    }

    for (auto& [key, val] : template_config.items()){
        if (!arg_config.contains(key)){
            arg_config[key] = val;
        }
    }

    return arg_config;
}

void Config::init() {
    
    config_path = get_config_path();

    if (!exists(config_path)){
        create_directories(config_path.parent_path());
    }

    if (exists(config_path) && file_size(config_path) != 0){
        config = read();
    }

    config = fix_config(config);
    write(config);
}

void Config::write(json& arg_config){
    ofstream config_file(config_path.string());

    if (!config_file.is_open()) {
        Log::fatal("Failed to open config file");
    }

    config_file << arg_config.dump(4);

    if (config_file.fail()) {
        Log::fatal("Failed to write config file");
    }

    config_file.close();
}

json Config::read(){

    ifstream file(config_path);

    if (!file.is_open()) {
        Log::fatal("Failed to open config file");
    }

    json tmp_config;

    try {
        file >> tmp_config;
    } catch (const json::parse_error&) {
        Log::fatal("Invalid config file");
    }

    return tmp_config;
}

json Config::get_config() {
    
    if (config.empty()) {
        Log::fatal("Config is not initialized");
    }

    return config;
}
