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

// Integrate the Wayland display with an external poll loop. Every successful
// prepare_poll() must be paired with either finish_poll() or cancel_poll().
// prepare_poll() returns true when poll should also wait for POLLOUT.
bool prepare_poll();
void finish_poll(bool readable, bool writable);
void cancel_poll();
void request_frame();
bool take_frame_ready();

void shutdown();

} // namespace Wayland
