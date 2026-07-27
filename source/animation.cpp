#include "animation.hpp"
#include "island.hpp"
#include "log.hpp"

#include <chrono>
#include <vector>

using namespace std;
using namespace std::chrono;

namespace {

struct AnimationArg{
    void (*setter)(float);
    float from;
    float to;
    milliseconds duration;
    steady_clock::time_point now;
};

vector<AnimationArg> animation_lib{};

}

void Animation::init(){

}

bool Animation::no_more_animation(){
    return animation_lib.empty();
}

void Animation::start_animation(void (*setter)(float), milliseconds duration, float from, float to){

    AnimationArg animation_arg{
        .setter = setter,
        .from = from,
        .to = to,
        .duration = duration,
        .now = steady_clock::now(),
    };

    animation_lib.push_back(animation_arg);
}

void Animation::update(){
    for (size_t i = 0; i < animation_lib.size(); ++i){
        AnimationArg& animation_arg = animation_lib[i];
        auto now = steady_clock::now();

        if (now >= animation_arg.now + animation_arg.duration){
            animation_arg.setter(animation_arg.to);
            animation_lib.erase(animation_lib.begin() + i);
            return;
        }

        float progress = duration<float>(now - animation_arg.now).count() /
        duration<float>(animation_arg.duration).count();

        animation_arg.setter(animation_arg.from + progress * (animation_arg.to - animation_arg.from));

    }
}