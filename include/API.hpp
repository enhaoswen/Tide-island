#pragma once

#include "cstdint"

#include "struct.hpp"

namespace API {

void init();
void resize(uint32_t width, uint32_t height);
void draw_rectangle(RectDesc&);
void draw_image(ImageDesc&);

void to_clock_status();
void clear_status();
void run();

}