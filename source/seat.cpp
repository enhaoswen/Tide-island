#include "log.hpp"
#include "seat.hpp"
#include "island.hpp"
#include "renderer.hpp"
#include "wlr-layer-shell-unstable-v1-client-protocol.h"

#include <cstdint>
#include <vector>
#include <algorithm>
#include <wayland-client.h>
#include <linux/input-event-codes.h>

using namespace std;

namespace {

struct MouseArea {
    Renderer::ObjFrame frame;
    float radius;
    void (*callback)();
};

void tmp_island_callback(){
    Log::logger(Log::Debug, "Clicked");
}

bool inside_area(Renderer::ObjFrame frame, float radius, float x, float y){

    if (
        x < frame.x ||
        x > frame.x + frame.width ||
        y < frame.y ||
        y > frame.y + frame.height
    ) {
        return false;
    }

    float nearest_x = clamp(
        x,
        frame.x + radius,
        frame.x + frame.width - radius
    );

    float nearest_y = clamp(
        y,
        frame.y + radius,
        frame.y + frame.height - radius
    );

    const float dx = x - nearest_x;
    const float dy = y - nearest_y;

    return dx * dx + dy * dy <= radius * radius;
}

bool ontop_island = {false};
float x{};
float y{};

vector<MouseArea> mouse_area_list_l;
vector<MouseArea> mouse_area_list_r;

void pointer_enter(
    void*,
    wl_pointer*,
    uint32_t,
    wl_surface*,
    wl_fixed_t surface_x,
    wl_fixed_t surface_y
) {
    ontop_island = true;
    x = static_cast<float>(wl_fixed_to_double(surface_x));
    y = static_cast<float>(wl_fixed_to_double(surface_y));
}

void pointer_leave(
    void*,
    wl_pointer*,
    uint32_t,
    wl_surface*
) {
    ontop_island = false;
}

void pointer_motion(
    void*,
    wl_pointer*,
    uint32_t,
    wl_fixed_t surface_x,
    wl_fixed_t surface_y
) {
    if (!ontop_island){
        return;
    }
    x = static_cast<float>(wl_fixed_to_double(surface_x));
    y = static_cast<float>(wl_fixed_to_double(surface_y));
}

void pointer_button(
    void*,
    wl_pointer*,
    uint32_t,
    uint32_t,
    uint32_t button,
    uint32_t state
) {
    if (state != WL_POINTER_BUTTON_STATE_PRESSED) {
        return;
    }

    switch (button) {
    case BTN_LEFT:
        
        Seat::click(x, y, true);
        break;

    case BTN_RIGHT:
        Seat::click(x, y, false);
        break;

    case BTN_MIDDLE:
        break;

    default:
        break;
    }
}

void pointer_axis(
    void*,
    wl_pointer*,
    uint32_t,
    uint32_t,
    wl_fixed_t
) {

}

void pointer_frame(void*, wl_pointer*) {}

void pointer_axis_source(
    void*,
    wl_pointer*,
    uint32_t
) {}

void pointer_axis_stop(
    void*,
    wl_pointer*,
    uint32_t,
    uint32_t
) {}

void pointer_axis_discrete(
    void*,
    wl_pointer*,
    uint32_t,
    int32_t
) {}

void pointer_axis_value120(
    void*,
    wl_pointer*,
    uint32_t,
    int32_t
) {}

const wl_pointer_listener listener{
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
    .frame = pointer_frame,
    .axis_source = pointer_axis_source,
    .axis_stop = pointer_axis_stop,
    .axis_discrete = pointer_axis_discrete,
    .axis_value120 = pointer_axis_value120,
    .axis_relative_direction = nullptr,
};

} // namespace

const wl_pointer_listener& Seat::pointer_listener() {
    return listener;
}

void Seat::add_mouse_area(Renderer::ObjFrame frame,bool left , float radius, void (*callback)()){
    MouseArea mouseArea{
        .frame = frame,
        .radius = radius,
        .callback = callback
    };
    if (left){
        mouse_area_list_l.push_back(mouseArea);
    }
    else {
        mouse_area_list_r.push_back(mouseArea);
    }
}

void Seat::click(int x, int y, bool left){
    const vector<MouseArea>& mouse_areas =
        left ? mouse_area_list_l : mouse_area_list_r;

    for (auto area = mouse_areas.rbegin(); area != mouse_areas.rend(); ++area) {
        if (inside_area(area->frame, area->radius, x, y)) {
            if (area->callback) {
                area->callback();
            }
            return;
        }
    }
}

void Seat::init(){
    Island::Island island = Island::state();
    Renderer::ObjFrame frame{
        .x = 0,
        .y = island.anchor_top,
        .width = island.island_width,
        .height = island.island_height
    };

    add_mouse_area(frame, true, island.radius, tmp_island_callback);

}
