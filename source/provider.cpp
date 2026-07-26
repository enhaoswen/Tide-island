#include "provider.hpp"
#include "log.hpp"

#include <chrono>
#include <exception>
#include <format>


using namespace std;
using namespace std::chrono;

string Provider::style_clock() {
    try {
        const auto now = floor<minutes>(system_clock::now());
        const auto local_now = current_zone()->to_local(now);
        return std::format("{:%H:%M}", local_now);
    } catch (const exception& error) {
        Log::fatal(error.what());
    }
}
