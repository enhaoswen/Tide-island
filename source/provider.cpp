#include "provider.hpp"

#include <chrono>
#include <format>


using namespace std;
using namespace std::chrono;

string Provider::style_clock() {
    const auto now = floor<minutes>(system_clock::now());
    const auto local_now = current_zone()->to_local(now);
    return std::format("{:%H:%M}", local_now);
}