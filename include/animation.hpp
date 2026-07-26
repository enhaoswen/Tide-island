#pragma once

#include <chrono>

namespace Animation {

enum Target : char {
    X
};

void init();
int add_animation(std::chrono::milliseconds duration, float frome, float to);
float get_val(int index);
bool animation_over(int index);

}
