// ============================================================================
// Tide Island shared state
// ============================================================================
//
// This translation unit owns the process-wide island configuration used by the
// Wayland backend and renderer.
//
#include "island.hpp"
#include "log.hpp"

using namespace std;

// ============================================================================
// [Internal Details]
// ============================================================================

namespace {

Island::Island island{};

} // namespace

// ============================================================================
// [Public API Implementation]
// ============================================================================

const Island::Island& Island::state() {
    return island;
}

void Island::init(Island& arg_island){
    island = arg_island;
}

void Island::set_island_size(float width, float height) {
    if (width <= 0 || height <= 0) {
        logger(Log::Error, "Island size should not be less than or equal to 0");
        return;
    }

    island.island_width = width;
    island.island_height = height;
}

void Island::set_window_size(int width, int height) {
    if (width <= 0 || height <= 0) {
        logger(Log::Error, "Window size should not be less than or equal to 0");
        return;
    }

    island.window_width = width;
    island.window_height = height;
}

void Island::set_anchor_top(float distance) {
    island.anchor_top = distance;
}

void Island::set_is_running(bool state) {
    island.is_running = state;
}

void Island::set_radius(float radius) {
    if (radius < 0) {
        logger(Log::Error, "Radius have to be positive");
        return;
    }

    island.radius = radius;
}

void Island::set_zone(int zone) {
    island.zone = zone;
}

void Island::set_state(State state) {
    island.state = state;
}