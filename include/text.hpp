#pragma once

#include <string_view>

namespace Text {

void init();
void draw(std::string_view text);
void shutdown();

}