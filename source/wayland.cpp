// ============================================================================
// Tide Island Wayland backend
// ============================================================================
//
// This translation unit owns the native Wayland, layer-shell, EGL window, and
// swapchain-facing platform state used by the renderer.

#include "wayland.hpp"
#include "log.hpp"

#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include <GLES3/gl3.h>
#include <EGL/egl.h>
#include <wayland-client-core.h>
#include <wayland-client-protocol.h>
#include <linux/input-event-codes.h>
#include <wayland-client.h>
#include <wayland-egl-core.h>
#include <wayland-egl.h>
#include <sys/timerfd.h>
#include <algorithm>
#include <cstring>
#include <array>
#include <poll.h>
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

uint32_t current_width{};
uint32_t current_height{};

float pointer_x{};
float pointer_y{};
bool pointer_inside{};

int wayland_fd{-1};

void (*report_click)(float x, float y, bool left){};

// --- Wayland Registry Listeners ---

void pointer_enter(
    void*,
    wl_pointer*,
    uint32_t,
    wl_surface* entered_surface,
    wl_fixed_t surface_x,
    wl_fixed_t surface_y
) {
    if (entered_surface != surface.get()) {
        return;
    }

    pointer_inside = true;
    pointer_x = static_cast<float>(wl_fixed_to_double(surface_x));
    pointer_y = static_cast<float>(wl_fixed_to_double(surface_y));

}

void pointer_leave(
    void*,
    wl_pointer*,
    uint32_t,
    wl_surface* left_surface
) {
    if (left_surface == surface.get()) {
        pointer_inside = false;
    }
}

void pointer_motion(
    void*,
    wl_pointer*,
    uint32_t,
    wl_fixed_t surface_x,
    wl_fixed_t surface_y
) {
    pointer_x = static_cast<float>(wl_fixed_to_double(surface_x));
    pointer_y = static_cast<float>(wl_fixed_to_double(surface_y));
}

void pointer_button(
    void*,
    wl_pointer*,
    uint32_t,
    uint32_t,
    uint32_t button,
    uint32_t state
) { 
    if (report_click == nullptr) Log::fatal("Func report_click is not initilized");
    if (state == WL_POINTER_BUTTON_STATE_PRESSED){
        if (button == BTN_LEFT && report_click) {
            report_click(pointer_x, pointer_y, true);
        }

        else if (button == BTN_RIGHT && report_click) {
            report_click(pointer_x, pointer_y, false);
        }
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

void pointer_frame(void*, wl_pointer*) {
}

void pointer_axis_source(void*, wl_pointer*, uint32_t) {
}

void pointer_axis_stop(void*, wl_pointer*, uint32_t, uint32_t) {
}

void pointer_axis_discrete(void*, wl_pointer*, uint32_t, int32_t) {
}

const wl_pointer_listener pointer_listener{
    .enter = pointer_enter,
    .leave = pointer_leave,
    .motion = pointer_motion,
    .button = pointer_button,
    .axis = pointer_axis,
    .frame = pointer_frame,
    .axis_source = pointer_axis_source,
    .axis_stop = pointer_axis_stop,
    .axis_discrete = pointer_axis_discrete,
    .axis_value120 = nullptr,
    .axis_relative_direction = nullptr,
};

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
            Log::fatal("Failed to create Wayland pointer");
        }

        if (wl_pointer_add_listener(
                pointer.get(),
                &pointer_listener,
                nullptr) == -1) {
            Log::fatal("Failed to add Wayland pointer listener");
        }
    } else if (!has_pointer && pointer) {
        pointer.reset();
        pointer_inside = false;
    }
}

void seat_name(
    void*,
    wl_seat*,
    const char*
) {
}

wl_seat_listener seat_listener = {
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
    string_view interface_name{interface};

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
        seat.reset(static_cast<wl_seat*>(
            wl_registry_bind(
                registry,
                name,
                &wl_seat_interface,
                min(version, 7u)
            )
        ));

        if (!seat) {
            Log::fatal("Failed to bind Wayland seat");
        }

        if (wl_seat_add_listener(
                seat.get(),
                &seat_listener,
                nullptr) == -1) {
            Log::fatal("Failed to add Wayland seat listener");
        }
    }
}

void registry_remove(void*, wl_registry*, uint32_t id) {
    logger(Log::Error, "Wayland global resource removed (id: {})", id);
}

wl_registry_listener registry_listener = {
    .global        = registry_global,
    .global_remove = registry_remove,
};

// --- Layer Surface Listeners ---

void layer_surface_configure(
    void*,
    zwlr_layer_surface_v1* surface,
    uint32_t serial,
    uint32_t width,
    uint32_t height
) {
    zwlr_layer_surface_v1_ack_configure(surface, serial);

    if (width != 0){
        current_width = width;
    }

    if (height != 0){
        current_height = height;
    }

    if (egl_window) {
        wl_egl_window_resize(
            egl_window.get(),
            current_width,
            current_height,
            0,
            0
        );
    }
}

void layer_surface_closed(void*, zwlr_layer_surface_v1*) {
    Log::fatal("Layer surface was closed by compositor. Exiting...");
}

zwlr_layer_surface_v1_listener layer_surface_listener = {
    .configure = layer_surface_configure,
    .closed    = layer_surface_closed,
};

} // namespace

// ============================================================================
// [Public API Implementation]
// ============================================================================

void Wayland::init() {

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
        // default size, always set size before start doing anything else
        10,
        10
        
    );
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface.get(), 10); // default size again

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
        // default size
        10,
        10
        
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

    wayland_fd = wl_display_get_fd(display.get());
}

void Wayland::swap_buffer() {
    if (!eglSwapBuffers(egl_display, egl_surface)) {
        Log::fatal("eglSwapBuffers failed");
    }
}

void Wayland::request_resize(
    uint32_t width,
    uint32_t height
) {
    if (!layer_surface) {
        Log::fatal("request_resize called before layer_surface creation");
    }

    if (width <= 0 || height <= 0){
        Log::fatal("Island size should not be neagative");
    }

    if (!egl_window.get()){
        Log::fatal("EGL_window is not initialized");
    }

    zwlr_layer_surface_v1_set_size(layer_surface.get(), width, height);
    wl_surface_commit(surface.get());

}

array<int,2> Wayland::get_surface_size() {
    return {static_cast<int>(current_width), static_cast<int>(current_height)};
}

void Wayland::apply_config(
    uint32_t width, 
    uint32_t height, 
    int32_t exclusive_zone, 
    int32_t margin_top
) {
    zwlr_layer_surface_v1_set_size(
        layer_surface.get(),
        width,
        height
    );

    zwlr_layer_surface_v1_set_exclusive_zone(
        layer_surface.get(),
        exclusive_zone
    );

    zwlr_layer_surface_v1_set_margin(
        layer_surface.get(),
        margin_top,
        0, 0, 0
    );

    wl_surface_commit(surface.get());

    logger(Log::Debug, "Applyed config: {}*{}", width, height);
}

void Wayland::set_report_click(void (*callback)(float x, float y, bool left)) {
    report_click = callback;
}

void Wayland::handle_events(short revents) {
    if (revents & (POLLERR | POLLHUP | POLLNVAL)) {
        wl_display_cancel_read(display.get());
        Log::fatal(
            "Wayland fd poll error: {}",
            revents
        );
    }

    if (revents & POLLIN) {
        if (wl_display_read_events(display.get()) == -1) {
            Log::fatal(
                "wl_display_read_events failed: {}",
                strerror(errno)
            );
        }
    } else {
        wl_display_cancel_read(display.get());
    }

    if (revents & POLLOUT) {
        if (wl_display_flush(display.get()) == -1 &&
            errno != EAGAIN) {
            Log::fatal(
                "wl_display_flush failed: {}",
                strerror(errno)
            );
        }
    }

    if (wl_display_dispatch_pending(display.get()) == -1) {
        Log::fatal("wl_display_dispatch_pending failed");
    }
}

short Wayland::prepare_events() {
    while (wl_display_prepare_read(display.get()) == -1) {
        if (wl_display_dispatch_pending(display.get()) == -1) {
            Log::fatal("wl_display_dispatch_pending failed");
        }
    }
    short events = POLLIN;

    if (wl_display_flush(display.get()) == -1) {
        if (errno == EAGAIN) {
            events |= POLLOUT;
        } else {
            wl_display_cancel_read(display.get());
            Log::fatal(
                "wl_display_flush failed: {}",
                strerror(errno)
            );
        }
    }

    return events;
}

int Wayland::get_wayland_fd() {
    return wayland_fd;
}

void Wayland::cancel_events() {
    wl_display_cancel_read(display.get());
}

void Wayland::shutdown() {
    if (!display) return;

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
