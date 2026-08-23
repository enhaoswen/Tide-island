#pragma once

#include <array>
#include <cstdint>

// ============================================================================
// Tide Island Wayland API
// ============================================================================
//
// The Wayland backend owns the layer-shell surface and EGL context used by the
// renderer.

namespace Wayland {

void init();
void request_resize(uint32_t width, uint32_t height);
std::array<int,2> get_surface_size();
void swap_buffer();
void apply_config(uint32_t width, uint32_t height, int32_t exclusive_zone, int32_t margin_top);
void set_report_click(void (*callback)(float x, float y, bool left));
int get_wayland_fd();
void shutdown();
short prepare_events();
void handle_events(short revents);
void cancel_events();

} // namespace Wayland
