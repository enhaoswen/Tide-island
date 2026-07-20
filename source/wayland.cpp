// ============================================================================
// Tide Island Wayland backend
// ============================================================================
//
// This translation unit owns the native Wayland, layer-shell, EGL window, and
// swapchain-facing platform state used by the renderer.

#include "wayland.hpp"
#include "island.hpp"
#include "log.hpp"

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
#include <memory>
#include <expected>
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
unique_ptr<zwlr_layer_shell_v1, DeleteWayland<zwlr_layer_shell_v1_destroy>>
    layer_shell{nullptr};
unique_ptr<wl_surface, DeleteWayland<wl_surface_destroy>> surface{nullptr};
unique_ptr<zwlr_layer_surface_v1, DeleteWayland<zwlr_layer_surface_v1_destroy>>
    layer_surface{nullptr};
unique_ptr<wl_egl_window, DeleteWayland<wl_egl_window_destroy>> egl_window{nullptr};

EGLDisplay egl_display{EGL_NO_DISPLAY};
EGLConfig  egl_config{};
EGLContext egl_context{EGL_NO_CONTEXT};
EGLSurface egl_surface{EGL_NO_SURFACE};

// --- Wayland Registry Listeners ---

void registry_global(
    void*,
    wl_registry* registry,
    uint32_t name,
    const char* interface,
    uint32_t version
) {
    if (string_view(interface) == wl_compositor_interface.name) {
        compositor.reset(static_cast<wl_compositor*>(
            wl_registry_bind(registry, name, &wl_compositor_interface, min(version, 4u))
        ));
    }
    else if (string_view(interface) == zwlr_layer_shell_v1_interface.name) {
        layer_shell.reset(static_cast<zwlr_layer_shell_v1*>(
            wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, min(version, 4u))
        ));
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

expected<void, const char*> Wayland::init() {
    Island::Island island_state = Island::state();

    if (island_state.window_width == 0 || island_state.window_height == 0) {
        return unexpected("Size of island is 0, call 'Island::set_window_size(int w, int h)'");
    }

    // 1. Establish Wayland Connection & Registry
    display.reset(wl_display_connect(nullptr));
    if (!display) {
        return unexpected("Failed to connect Wayland");
    }

    registry.reset(wl_display_get_registry(display.get()));
    
    if (!registry.get()){
        return unexpected("Failed to get registry");
    }

    wl_registry_add_listener(registry.get(), &registry_listener, nullptr);
    wl_display_roundtrip(display.get());

    if (wl_display_roundtrip(display.get()) == -1) {
        return unexpected("roundtrip failed");
    }

    if (!compositor) {
        return unexpected("No compositor found");
    }

    if (!layer_shell) {
        return unexpected("No layer shell found");
    }

    // 2. Setup Wayland Surface & Layer Shell
    surface.reset(wl_compositor_create_surface(compositor.get()));

    if (!surface.get()){
        return unexpected("Failed to create surface");
    }

    layer_surface.reset(zwlr_layer_shell_v1_get_layer_surface(
        layer_shell.get(),
        surface.get(),
        nullptr,
        ZWLR_LAYER_SHELL_V1_LAYER_TOP,
        "tide-island"
    ));

    if (!layer_surface) {
        return unexpected("Failed to create layer surface");
    }

    zwlr_layer_surface_v1_set_anchor(
        layer_surface.get(),
        ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP
    );
    Wayland::request_resize(island_state.window_width, island_state.window_height);
    zwlr_layer_surface_v1_set_exclusive_zone(layer_surface.get(), island_state.zone);

    zwlr_layer_surface_v1_add_listener(
        layer_surface.get(),
        &layer_surface_listener,
        nullptr
    );
    wl_surface_commit(surface.get());

    if (wl_display_roundtrip(display.get()) == -1) {
        return unexpected("Wayland roundtrip failed");
    }

    // 3. Setup EGL Window & Display
    egl_window.reset(wl_egl_window_create(
        surface.get(),
        island_state.window_width,
        island_state.window_height
    ));
    if (!egl_window) {
        return unexpected("Failed to create wl_egl_window");
    }

    egl_display = eglGetDisplay((EGLNativeDisplayType)display.get());
    if (egl_display == EGL_NO_DISPLAY) {
        return unexpected("eglGetDisplay failed");
    }

    EGLint major{};
    EGLint minor{};
    if (!eglInitialize(egl_display, &major, &minor)) {
        return unexpected("eglInitialize failed");
    }
    logger(Log::Debug, "Using EGL {}.{}", major, minor);

    if (!eglBindAPI(EGL_OPENGL_ES_API)) {
        return unexpected("eglBindAPI failed");
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
        return unexpected("eglChooseConfig failed");
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
        return unexpected("eglCreateContext failed");
    }

    egl_surface = eglCreateWindowSurface(
        egl_display,
        egl_config,
        (EGLNativeWindowType)egl_window.get(),
        nullptr
    );

    if (egl_surface == EGL_NO_SURFACE) {
        return unexpected("eglCreateWindowSurface failed");
    }

    if (!eglMakeCurrent(
        egl_display,
        egl_surface,
        egl_surface,
        egl_context
    )) {
        return unexpected("eglMakeCurrent failed");
    }

    return {};
}

expected<void, const char*> Wayland::dispatch_events() {
    if (!display) {
        return unexpected("Wayland display is not initialized");
    }

    if (wl_display_dispatch(display.get()) == -1) {
        return unexpected("Wayland dispatch failed");
    }

    return {};
}


void Wayland::swap_buffer() {
    eglSwapBuffers(egl_display, egl_surface);
}

void Wayland::request_resize(int width, int height) {
    if (!layer_surface) {
        logger(Log::Error, "request_resize called before layer_surface creation");
        return;
    }
    zwlr_layer_surface_v1_set_size(layer_surface.get(), width, height);
    Island::set_window_size(width, height);
}

expected<int, const char*> Wayland::get_fd() {
    if (!display) {
        return unexpected("Wayland display is not initialized");
    }

    int fd = wl_display_get_fd(display.get());
    if (fd == -1) {
        return unexpected("Failed to get Wayland file descriptor");
    }

    return fd;
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
