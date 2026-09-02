#pragma once

#include <array>

#include "struct.hpp"

namespace Renderer {

void init();
void begin_frame();
void end_frame();

void draw_rectangle(Frame frame, float radius, std::array<float,4> color);
void draw_image(Frame frame, float radius, std::string path);

}
