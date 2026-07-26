#include "animation.hpp"
#include "island.hpp"
#include "log.hpp"

#include <chrono>
#include <unordered_map>

using namespace std;
using namespace std::chrono;

namespace {

struct AnimationArg{
    steady_clock::time_point now;
    float from;
    float to;
    milliseconds duration;
};

const Island::Island* island{};

unordered_map<int, AnimationArg> animation_lib;

int get_new_index(){
    int index{0};

    while (animation_lib.contains(index)){
        ++index;
    }

    return index;
}

}

void Animation::init(){
    island = Island::state();

}

int Animation::add_animation(milliseconds duration, float from, float to){
    int index = get_new_index();

    AnimationArg animation_arg{
        .now = steady_clock::now(),
        .from = from,
        .to = to,
        .duration = duration,
    };

    animation_lib[index] = animation_arg;

    return index;
}

float Animation::get_val(int index) {
    auto it = animation_lib.find(index);

    if (it == animation_lib.end()) {
        Log::fatal("Empty animation index");
    }

    const AnimationArg& animation = it->second;
    auto now = steady_clock::now();

    if (now >= animation.now + animation.duration) {
        animation_lib.erase(index);
        return animation.to;
    }

    float progress = duration<float>(now - animation.now).count() /
        duration<float>(animation.duration).count();

    return animation.from + progress * (animation.to - animation.from);
}

bool Animation::animation_over(int index){
    return animation_lib.contains(index);
}