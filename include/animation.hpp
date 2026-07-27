#pragma once

#include <chrono>

namespace Animation {

enum Target : char {
    X
};

void init();
bool no_more_animation();
void start_animation(void (*setter)(float), std::chrono::milliseconds duration, float frome, float to);
void update();
}
