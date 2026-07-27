// ============================================================================
// Tide Island Wayland backend
// ============================================================================
//
// This translation unit owns the native Wayland, layer-shell, EGL window, and
// swapchain-facing platform state used by the renderer.

#include "wayland.hpp"
#include "island.hpp"
#include "log.hpp"
#include "seat.hpp"

#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include <GLES3/gl3.h>
#include <EGL/egl.h>
#include <wayland-client-core.h>
#include <wayland-client-protocol.h>
#include <wayland-client.h>
#include <wayland-egl-core.h>
#include <wayland-egl.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <memory>
#include <string_view>


using namespace std;

// ============================================================================
// [Internal Details]
// ============================================================================

namespace {

template <auto delete_func>
struct DeleteWayland {
    void operator()(auto* ptr) const noexcept {
        if (ptr) delete_func(ptr);
    }
};

unique_ptr<wl_display, DeleteWayland<wl_display_disconnect>> display{nullptr};
unique_ptr<wl_registry, DeleteWayland<wl_registry_destroy>> registry{nullptr};
unique_ptr<wl_compositor, DeleteWayland<wl_compositor_destroy>> compositor{nullptr};
unique_ptr<zwlr_layer_shell_v1, DeleteWayland<zwlr_layer_shell_v1_destroy>> layer_shell{nullptr};
unique_ptr<wl_surface, DeleteWayland<wl_surface_destroy>> surface{nullptr};
unique_ptr<zwlr_layer_surface_v1, DeleteWayland<zwlr_layer_surface_v1_destroy>> layer_surface{nullptr};
unique_ptr<wl_egl_window, DeleteWayland<wl_egl_window_destroy>> egl_window{nullptr};
unique_ptr<wl_seat, DeleteWayland<wl_seat_release>> seat{nullptr};
unique_ptr<wl_pointer, DeleteWayland<wl_pointer_release>> pointer{nullptr};

EGLDisplay egl_display{EGL_NO_DISPLAY};
EGLConfig  egl_config{};
EGLContext egl_context{EGL_NO_CONTEXT};
EGLSurface egl_surface{EGL_NO_SURFACE};
bool display_read_prepared{};

bool frame_ready{};

void dispatch_pending_events() {
    if (wl_display_dispatch_pending(display.get()) == -1) {
        Log::fatal("Failed to dispatch pending Wayland events");
    }
}

bool flush_display() {
    if (wl_display_flush(display.get()) != -1) {
        return false;
    }

    if (errno == EAGAIN) {
        return true;
    }

    Log::fatal("Failed to flush Wayland requests");
}

// --- Wayland Registry Listeners ---

void frame_done(
    void*,
    wl_callback* callback,
    uint32_t
) {
    wl_callback_destroy(callback);
    callback = nullptr;
    frame_ready = true;
}

void seat_capabilities(
    void*,
    wl_seat* current_seat,
    uint32_t capabilities
) {
    const bool has_pointer =
        capabilities & WL_SEAT_CAPABILITY_POINTER;

    if (has_pointer && !pointer) {
        pointer.reset(wl_seat_get_pointer(current_seat));

        if (!pointer) {
            Log::logger(
                Log::Error,
                "wl_seat_get_pointer failed"
            );
            return;
        }

        if (wl_pointer_add_listener(
            pointer.get(),
            &Seat::pointer_listener(),
            nullptr
        ) == -1) {
            Log::fatal("Failed to add wl_pointer listener");
        }

    } else if (!has_pointer && pointer) {
        pointer.reset();
    }
}

void seat_name(
    void*,
    wl_seat*,
    const char* name
) {
    Log::logger(Log::Debug, "Seat name:{}", name);
}

const wl_seat_listener seat_listener{
    .capabilities = seat_capabilities,
    .name = seat_name,
};



void registry_global(
    void*,
    wl_registry* registry,
    uint32_t name,
    const char* interface,
    uint32_t version
) {
    const string_view interface_name{interface};

    if (interface_name == wl_compositor_interface.name) {
        compositor.reset(static_cast<wl_compositor*>(
            wl_registry_bind(
                registry,
                name,
                &wl_compositor_interface,
                min(version, 4u)
            )
        ));
    }
    else if (interface_name == zwlr_layer_shell_v1_interface.name) {
        layer_shell.reset(static_cast<zwlr_layer_shell_v1*>(
            wl_registry_bind(
                registry,
                name,
                &zwlr_layer_shell_v1_interface,
                min(version, 4u)
            )
        ));
    }

    else if (interface_name == wl_seat_interface.name) {
        if (seat) {
            return;
        }

        seat.reset(static_cast<wl_seat*>(
            wl_registry_bind(
                registry,
                name,
                &wl_seat_interface,
                min(version, 8u)
            )
        ));

        if (!seat) {
            Log::fatal("Failed to bind wl_seat");
        }

        if (wl_seat_add_listener(
            seat.get(),
            &seat_listener,
            nullptr
        ) == -1) {
            Log::fatal("Failed to add wl_seat listener");
        }
    }
}

void registry_remove(void*, wl_registry*, uint32_t id) {
    logger(Log::Error, "Wayland global resource removed (id: {})", id);
}

constexpr wl_registry_listener registry_listener = {
    .global        = registry_global,
    .global_remove = registry_remove,
};

// --- Layer Surface Listeners ---

wl_callback_listener frame_listener{
    .done = frame_done,
};

void layer_surface_configure(
    void*,
    zwlr_layer_surface_v1* surface,
    uint32_t serial,
    uint32_t width,
    uint32_t height
) {
    zwlr_layer_surface_v1_ack_configure(surface, serial);
    logger(Log::Debug, "Size: {}*{}", width, height);
    Island::set_window_size(static_cast<int>(width), static_cast<int>(height));
}

void layer_surface_closed(void*, zwlr_layer_surface_v1*) {
    logger(Log::Error, "Layer surface was closed by compositor. Exiting...");
    Island::set_is_running(false);
}

constexpr zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed    = layer_surface_closed,
};


} // namespace

// ============================================================================
// [Public API Implementation]
// ============================================================================

void Wayland::init() {
    const Island::Island* island_state = Island::state();

    if (island_state->surface_width == 0 || island_state->surface_height == 0) {
        Log::fatal("Size of island is 0, call 'Island::set_window_size(int w, int h)'");
    }

    // 1. Establish Wayland Connection & Registry
    display.reset(wl_display_connect(nullptr));
    if (!display) {
        Log::fatal("Failed to connect Wayland");
    }

    registry.reset(wl_display_get_registry(display.get()));
    
    if (!registry.get()){
        Log::fatal("Failed to get registry");
    }

    if (wl_registry_add_listener(
            registry.get(),
            &registry_listener,
            nullptr) == -1) {
        Log::fatal("Failed to add Wayland registry listener");
    }
    if (wl_display_roundtrip(display.get()) == -1) {
        Log::fatal("Wayland roundtrip failed");
    }

    if (wl_display_roundtrip(display.get()) == -1) {
        Log::fatal("Wayland roundtrip failed");
    }

    if (!compositor) {
        Log::fatal("No compositor found");
    }

    if (!layer_shell) {
        Log::fatal("No layer shell found");
    }

    // 2. Setup Wayland Surface & Layer Shell
    surface.reset(wl_compositor_create_surface(compositor.get()));

    if (!surface.get()){
        Log::fatal("Failed to create surface");
    }

    layer_surface.reset(zwlr_layer_shell_v1_get_layer_surface(
        layer_shell.get(),
        surface.get(),
        nullptr,
        ZWLR_LAYER_SHELL_V1_LAYER_TOP,
        "tide-island"
    ));

    if (!layer_surface) {
        Log::fatal("Failed to create layer surface");
    }

    zwlr_layer_surface_v1_set_anchor(
        layer_surface.get(),
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
    );
    zwlr_layer_surface_v1_set_size(
        layer_surface.get(),
        island_state->surface_width,
        island_state->surface_height
    );
    Island::set_window_size(
        island_state->surface_width,
        island_state->surface_height
    );
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface.get(), island_state->zone);

    if (zwlr_layer_surface_v1_add_listener(
            layer_surface.get(),
            &layer_surface_listener,
            nullptr) == -1) {
        Log::fatal("Failed to add layer surface listener");
    }
    wl_surface_commit(surface.get());

    if (wl_display_roundtrip(display.get()) == -1) {
        Log::fatal("Wayland roundtrip failed");
    }

    // 3. Setup EGL Window & Display
    egl_window.reset(wl_egl_window_create(
        surface.get(),
        island_state->surface_width,
        island_state->surface_height
    ));
    if (!egl_window) {
        Log::fatal("Failed to create wl_egl_window");
    }

    egl_display = eglGetDisplay((EGLNativeDisplayType)display.get());
    if (egl_display == EGL_NO_DISPLAY) {
        Log::fatal("eglGetDisplay failed");
    }

    EGLint major{};
    EGLint minor{};
    if (!eglInitialize(egl_display, &major, &minor)) {
        Log::fatal("eglInitialize failed");
    }
    logger(Log::Debug, "Using EGL {}.{}", major, minor);

    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        Log::fatal("eglBindAPI failed");
    }
    
    // 4. Configure EGL Surface & Context
    constexpr array<EGLint, 13> attribs = {
        EGL_SURFACE_TYPE,    EGL_WINDOW_BIT,
        EGL_RED_SIZE,        8,
        EGL_GREEN_SIZE,      8,
        EGL_BLUE_SIZE,       8,
        EGL_ALPHA_SIZE,      8,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_NONE
    };

    EGLint count{};
    if (!eglChooseConfig(egl_display, attribs.data(), &egl_config, 1, &count)
        || count == 0) {
        Log::fatal("eglChooseConfig failed");
    }

    constexpr array<EGLint, 3> ctx_attribs = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };

    egl_context = eglCreateContext(
        egl_display,
        egl_config,
        EGL_NO_CONTEXT,
        ctx_attribs.data()
    );
    if (egl_context == EGL_NO_CONTEXT) {
        Log::fatal("eglCreateContext failed");
    }

    egl_surface = eglCreateWindowSurface(
        egl_display,
        egl_config,
        (EGLNativeWindowType)egl_window.get(),
        nullptr
    );

    if (egl_surface == EGL_NO_SURFACE) {
        Log::fatal("eglCreateWindowSurface failed");
    }

    if (!eglMakeCurrent(
        egl_display,
        egl_surface,
        egl_surface,
        egl_context
    )) {
        Log::fatal("eglMakeCurrent failed");
    }
}

bool Wayland::prepare_poll() {
    if (!display) {
        Log::fatal("Wayland display is not initialized");
    }

    if (display_read_prepared) {
        Log::fatal("Wayland display is already prepared for reading");
    }

    while (wl_display_prepare_read(display.get()) == -1) {
        dispatch_pending_events();
    }

    display_read_prepared = true;
    return flush_display();
}

void Wayland::finish_poll(bool readable, bool writable) {
    if (!display_read_prepared) {
        Log::fatal("Wayland display was not prepared before finishing poll");
    }

    if (readable) {
        const int result = wl_display_read_events(display.get());
        display_read_prepared = false;

        if (result == -1) {
            Log::fatal("Failed to read Wayland events");
        }
    } else {
        wl_display_cancel_read(display.get());
        display_read_prepared = false;
    }

    if (writable) {
        flush_display();
    }

    dispatch_pending_events();
}

void Wayland::cancel_poll() {
    if (!display_read_prepared) {
        return;
    }

    wl_display_cancel_read(display.get());
    display_read_prepared = false;
}


void Wayland::swap_buffer() {
    if (!eglSwapBuffers(egl_display, egl_surface)) {
        Log::fatal("eglSwapBuffers failed");
    }
}

void Wayland::request_resize(int width, int height) {
    if (!layer_surface) {
        Log::fatal("request_resize called before layer_surface creation");
    }

    if (width <= 0 || height <= 0){
        Log::fatal("Island size should not be neagative");
    }

    if (! egl_window.get()){
        Log::fatal("EGL_window is not initialized");
    }

    zwlr_layer_surface_v1_set_size(layer_surface.get(), width, height);
    Island::set_window_size(width, height);
    
    wl_egl_window_resize(egl_window.get(), width, height, 0, 0);

}

int Wayland::get_fd() {
    if (!display) {
        Log::fatal("Wayland display is not initialized");
    }

    int fd = wl_display_get_fd(display.get());
    if (fd == -1) {
        Log::fatal("Failed to get Wayland file descriptor");
    }

    return fd;
}

void Wayland::shutdown() {
    if (!display) return;

    cancel_poll();

    // 1. Terminate EGL Environment
    if (egl_display != EGL_NO_DISPLAY) {
        eglMakeCurrent(
            egl_display,
            EGL_NO_SURFACE,
            EGL_NO_SURFACE,
            EGL_NO_CONTEXT
        );

        if (egl_surface != EGL_NO_SURFACE) {
            eglDestroySurface(egl_display, egl_surface);
            egl_surface = EGL_NO_SURFACE;
        }

        if (egl_context != EGL_NO_CONTEXT) {
            eglDestroyContext(egl_display, egl_context);
            egl_context = EGL_NO_CONTEXT;
        }

        eglTerminate(egl_display);
        egl_display = EGL_NO_DISPLAY;
        egl_config  = nullptr;
    }
}

void Wayland::request_frame() {
    wl_callback* callback = wl_surface_frame(surface.get());

    if (!callback ||
        wl_callback_add_listener(callback, &frame_listener, nullptr) == -1) {
        Log::fatal("Failed to request Wayland frame callback");
    }
}

bool Wayland::take_frame_ready() {
    return exchange(frame_ready, false);
}