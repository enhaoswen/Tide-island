#pragma once

#include <array>
#include <chrono>

struct Frame {
    float x, y, width, height;
};

struct RectDesc {
    Frame frame{};
    float radius{};
    std::array<float, 4> color{};
    void (*click_callback_left) () = nullptr;
    void (*click_callback_right) () = nullptr;
};

struct ImageDesc {
    Frame frame{};
    float radius{};
    void (*click_callback_left) () = nullptr;
    void (*click_callback_right) () = nullptr;

};

struct Event {
    std::chrono::steady_clock::time_point deadline;
    void (*callback)();
};

struct Island_conf {
    float color[4] = {0, 0, 0, 1};
    float island_width{};
    float island_height{};
    int zone{-1};
    float anchor_top{};
    float radius{};

    bool is_running{true};
};

enum struct AnimationTarget : char {
    Width,
    Height,
    X,
    Y,
    Radius,
    ColorR,
    ColorG,
    ColorB,
    ColorA
};

struct Animation {
    std::chrono::steady_clock::time_point start_time;
    std::chrono::milliseconds duration;
    float from;
    float to;
    AnimationTarget target;
};

struct Font {
    std::string path;
    size_t size;
};