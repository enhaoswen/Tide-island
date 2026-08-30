#include "API.hpp"
#include "log.hpp"

using namespace std;

int main() {
    println("");

    frame_logger(Log::Debug,
        "This build was compiled in debug mode.",
        "Performance may be reduced and additional debug output may appear."
    );

    API::init();

    RectDesc rect_desc{
        .frame = { 0, 0, 140, 38},

        .radius = 19,

        .color = { 0.0F, 0.0F, 0.0F, 1.0F },

        .click_callback_left = []() {
            Log::logger(Log::Debug, "Left click callback triggered");
        },
        .click_callback_right = []() {
            Log::logger(Log::Debug, "Right click callback triggered");
        },
    };

    API::draw_rectangle(rect_desc);

    API::run();
    return 0;
}