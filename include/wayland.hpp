#pragma once

// ============================================================================
// Tide Island Wayland API
// ============================================================================
//
// The Wayland backend owns the layer-shell surface and EGL context used by the
// renderer.
//
namespace Wayland {

void init();
void request_resize(int width, int height);
void swap_buffer();
int get_fd();
void dispatch_events();
void shutdown();

} // namespace Wayland
