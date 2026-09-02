#pragma once

#include "struct.hpp"


namespace Object {

void add_rectangle(RectDesc& desc);
void add_image(ImageDesc& desc);
void click(float x, float y, bool left);
void draw();
void clear();
}

