// ============================================================================
// Tide Island application entry point
// ============================================================================
//
// This file wires the shared island state, Wayland platform backend, renderer,
// and graphics-backend diagnostics into the application lifecycle.
//
#define SOKOL_IMPL

#include "island.hpp"
#include "renderer.hpp"
#include "environment.hpp"
#include "log.hpp"
#include "backend.hpp"

#include "sokol_gfx.h"
#include "sokol_log.h"
#include "wayland.hpp"

#include <print>

using namespace std;

// ============================================================================
// [Application Lifecycle]
// ============================================================================

int main() {
    println("");

#if defined(_DEBUG) || !defined(NDEBUG)

    frame_logger(Log::Warning,
        "This build was compiled in debug mode.",
        "Performance may be reduced and additional debug output may appear.");

#endif

    GraphicBackend::prepare_graphics_backend();

    // Island dimensions must be known before the Wayland layer surface exists.

    Island::Island arg_island {
        .color = {0,0,0,1},
        .window_width = 140,
        .window_height = 40,
        .island_width = 140,
        .island_height = 38,
        .zone = 40,
        .anchor_top = 2,
        .radius = 19,
        .is_running = true,
        .state = Island::State::Clock
    };
    Island::init(arg_island);

    Log::check(Wayland::init());
    logger(Log::Debug, "Initialize Wayland successfully");

    Log::check(Backend::init());
    logger(Log::Debug, "Initialize backend successfully");

    Log::check(Renderer::init());
    logger(Log::Debug, "Initialize render successfully");

    GraphicBackend::inspect_graphics_backend_after_context();

    Log::check(Backend::run());

    logger(Log::Debug, "Quit because island.is_running is set as false");

    Wayland::shutdown();
    Renderer::shutdown();
}
