#include "API.hpp"
#include "wayland.hpp"
#include "renderer.hpp"
#include "object.hpp"
#include "timer.hpp"
#include "island.hpp"
#include "log.hpp"

namespace {

const auto config = Island::state();

}

void API::init() {
    Island::init();
    Log::logger(Log::Debug, "Load config successfully");

    Wayland::init();
    Log::logger(Log::Debug, "Wayland initialized successfully");

    Renderer::init();
    Log::logger(Log::Debug, "Renderer initialized successfully");

    Timer::init();
    Log::logger(Log::Debug, "Timer initialized successfully");

    Wayland::set_report_click(Object::click);

    Wayland::apply_config(
       config->island_width,
       config->island_height,
       config->zone,
       config->anchor_top
    );
}

void API::resize(uint32_t width, uint32_t height) {
    Wayland::request_resize(width, height);
}

void API::draw_rectangle(RectDesc& rect_desc){
    Object::add_rectangle(rect_desc);
}

void API::draw_image(ImageDesc& desc) {
    Object::add_image(desc);
}

void API::run(){
    while (config->is_running) {

        Log::logger(Log::Debug, "Start a new frame");

        Renderer::begin_frame();
        Object::draw();
        Renderer::end_frame();

        Timer::wait();
    }

}
