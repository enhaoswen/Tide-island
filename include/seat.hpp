#pragma once

#include "renderer.hpp"

struct wl_pointer_listener;

namespace Seat {

const wl_pointer_listener& pointer_listener();

void add_mouse_area(Renderer::ObjFrame frame, bool left, float radius, void (*callback) ());

void init();

void click(int x, int y, bool left);

}