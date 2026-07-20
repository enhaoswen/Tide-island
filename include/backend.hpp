#pragma once
#include <chrono>
#include <expected>

namespace Backend {

struct Timer {
    std::chrono::steady_clock::time_point deadline;
    void (*callback)();
};

std::expected<void, const char*> init();
std::expected<void, const char*> push(
    std::chrono::milliseconds duration,
    void (*callback)()
);
std::expected<Timer, const char*> top();
std::expected<void, const char*> run();
void pop();
std::expected<void, const char*> handle_timerfd();

}
