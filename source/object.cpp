#include "object.hpp"
#include "log.hpp"
#include "renderer.hpp"
#include "struct.hpp"

#include <vector>
#include <algorithm>
#include <chrono>
#include <memory>

using namespace std;
using namespace std::chrono;

namespace {

class Item {
protected:
    Frame frame{};
    float radius = 0;

    void (*click_callback_left) () = nullptr;
    void (*click_callback_right) () = nullptr;

    vector<Animation> animations;

public:
    virtual void draw() = 0;
    virtual void update() = 0;

    bool click(float x, float y, bool left)  {
        if (
            x < frame.x ||
            x > frame.x + frame.width ||
            y < frame.y ||
            y > frame.y + frame.height
        ) {
            return false;
        }

        float nearest_x = clamp(
            static_cast<float>(x),
            frame.x + radius,
            frame.x + frame.width - radius
        );

        float nearest_y = clamp(
            static_cast<float>(y),
            frame.y + radius,
            frame.y + frame.height - radius
        );

        float dx = x - nearest_x;
        float dy = y - nearest_y;

        if (dx * dx + dy * dy <= radius * radius) {

            if (left && click_callback_left) {
                click_callback_left();
            } else if (!left && click_callback_right) {
                click_callback_right();
            }
            return true;
        }

        return false;
    }

    virtual ~Item() = default;

}; // Item

class Rectangle : public Item {
private:
    array<float, 4> color{};

public:
    Rectangle(RectDesc desc) {
        frame = desc.frame;
        radius = desc.radius;
        color = desc.color;
        click_callback_left = desc.click_callback_left;
        click_callback_right = desc.click_callback_right;
    }

    void set_frame(Frame arg_frame) {
        frame = arg_frame;
    }

    void set_radius(float arg_radius) {
        radius = arg_radius;
    }

    void set_color(std::array<float, 4> arg_color) {
        color = arg_color;
    }

    void add_animation(Animation animation) {
        animations.push_back(animation);
    }

    void update() override {
        auto now = steady_clock::now();

        for (size_t i = 0; i < animations.size();) {
            float* tmp_target{};
            Animation& animation = animations[i];

            switch (animation.target) {
                case AnimationTarget::Width:
                    tmp_target = &frame.width;
                    break;
                case AnimationTarget::Height:
                    tmp_target = &frame.height;
                    break;
                case AnimationTarget::X:
                    tmp_target = &frame.x;
                    break;
                case AnimationTarget::Y:
                    tmp_target = &frame.y;
                    break;
                case AnimationTarget::Radius:
                    tmp_target = &radius;
                    break;
                case AnimationTarget::ColorR:
                    tmp_target = &color[0];
                    break;
                case AnimationTarget::ColorG:
                    tmp_target = &color[1];
                    break;
                case AnimationTarget::ColorB:
                    tmp_target = &color[2];
                    break;
                case AnimationTarget::ColorA:
                    tmp_target = &color[3];
                    break;
                default:
                    Log::fatal("Unknown animation target");
            }

            auto end_pos = remove_if(
                animations.begin(), 
                animations.end(), 
                [tmp_target, now, &i](Animation& animation) -> bool {

                    if (now >= animation.start_time + animation.duration) {
                        *tmp_target = animation.to;
                        return true;
                    }

                    float progress = static_cast<float>((now - animation.start_time).count()) / animation.duration.count();
                    *tmp_target = animation.from + (animation.to - animation.from) * progress;
                    ++i;
                    return false;
            });

            animations.resize(end_pos - animations.begin());
        }
    }

    void draw() override {
        Renderer::draw_rectangle(frame, radius, color);
    }

}; // Rectangle

class Image : public Item {
private:
    string path;

public:
    Image(ImageDesc desc) {
        frame = desc.frame;
        radius = desc.radius;
        path = desc.path;
        click_callback_left = desc.click_callback_left;
        click_callback_right = desc.click_callback_right;
    }

    void update() override {
        auto now = steady_clock::now();

        for (size_t i = 0; i < animations.size();) {
            float* tmp_target{};
            Animation& animation = animations[i];

            switch (animation.target) {
                case AnimationTarget::Width:
                    tmp_target = &frame.width;
                    break;
                case AnimationTarget::Height:
                    tmp_target = &frame.height;
                    break;
                case AnimationTarget::X:
                    tmp_target = &frame.x;
                    break;
                case AnimationTarget::Y:
                    tmp_target = &frame.y;
                    break;
                case AnimationTarget::Radius:
                    tmp_target = &radius;
                    break;
                default:
                    Log::fatal("Unknown animation target");
            }

            auto end_pos = remove_if(
                animations.begin(), 
                animations.end(), 
                [tmp_target, now, &i](Animation& animation) -> bool {

                    if (now >= animation.start_time + animation.duration) {
                        *tmp_target = animation.to;
                        return true;
                    }

                    float progress = static_cast<float>((now - animation.start_time).count()) / animation.duration.count();
                    *tmp_target = animation.from + (animation.to - animation.from) * progress;
                    ++i;
                    return false;
            });

            animations.resize(end_pos - animations.begin());
        }
    }

    void draw() override {
        Renderer::draw_image(frame, radius, path);
    }

}; // Image

vector<unique_ptr<Item>> objects;

} // namespace

void Object::add_rectangle(RectDesc& desc) {
    objects.emplace_back(make_unique<Rectangle>(desc));
}

void Object::add_image(ImageDesc &desc) {
    objects.emplace_back(make_unique<Image>(desc));
}

void Object::click(float x, float y, bool left) {
    for (auto& object : objects) {
        if (object->click(x, y, left)) return;
    }
}

void Object::draw() {
    for (auto& obj : objects) {
        obj->update();
        obj->draw();
    }
}

void Object::clear() {
    objects.clear();
}

