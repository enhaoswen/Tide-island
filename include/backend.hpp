#pragma once
#include <chrono>

namespace Backend {

struct Timer {
    std::chrono::steady_clock::time_point deadline;
    void (*callback)();
};

void init();
void push(
    std::chrono::microseconds duration,
    void (*callback)()
);
Timer top();
void run();
void pop();
void handle_timerfd();

}
