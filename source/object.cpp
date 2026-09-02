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
            x,
            frame.x + radius,
            frame.x + frame.width - radius
        );

        float nearest_y = clamp(
            y,
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

        auto end_pos = remove_if(
        animations.begin(),
        animations.end(),
        [this, now](Animation& animation) -> bool {
            float* target{};
            switch (animation.target) {
                case AnimationTarget::Width:
                    target = &frame.width;
                    break;
                case AnimationTarget::Height:
                    target = &frame.height;
                    break;
                case AnimationTarget::X:
                    target = &frame.x;
                    break;
                case AnimationTarget::Y:
                    target = &frame.y;
                    break;
                case AnimationTarget::Radius:
                    target = &radius;
                    break;
                case AnimationTarget::ColorR:
                    target = &color[0];
                    break;
                case AnimationTarget::ColorG:
                    target = &color[1];
                    break;
                case AnimationTarget::ColorB:
                    target = &color[2];
                    break;
                case AnimationTarget::ColorA:
                    target = &color[3];
                    break;
                default:
                    Log::fatal("Unknown animation target");
                    return false;
            }

            if (animation.duration.count() <= 0 ||
                now >= animation.start_time + animation.duration) {
                *target = animation.to;
                return true;
            }

            if (now < animation.start_time) {
                return false;
            }

            float progress = static_cast<float>((now - animation.start_time).count())
                            / static_cast<float>(animation.duration.count());
            *target = animation.from + (animation.to - animation.from) * progress;
            return false;
        });

        animations.erase(end_pos, animations.end());
    }

    void draw() override {
        Renderer::draw_rectangle(frame, radius, color);
    }

}; // Rectangle

class Image : public Item {
private:
    string path;
    Align horizontal_align;
    Align vertical_align;

public:
    Image(ImageDesc &desc) {
        frame = desc.frame;
        radius = desc.radius;
        path = desc.path;
        click_callback_left = desc.click_callback_left;
        click_callback_right = desc.click_callback_right;
        horizontal_align = desc.horizontal_align;
        vertical_align = desc.vertical_align;
    }

    void update() override {
        auto now = steady_clock::now();

        auto end_pos = remove_if(
        animations.begin(),
        animations.end(),
        [this, now](Animation& animation) -> bool {
            float* target{};
            switch (animation.target) {
                case AnimationTarget::Width:
                    target = &frame.width;
                    break;
                case AnimationTarget::Height:
                    target = &frame.height;
                    break;
                case AnimationTarget::X:
                    target = &frame.x;
                    break;
                case AnimationTarget::Y:
                    target = &frame.y;
                    break;
                case AnimationTarget::Radius:
                    target = &radius;
                    break;
                default:
                    Log::fatal("Unknown animation target");
                    return false;
            }

            if (animation.duration.count() <= 0 ||
                now >= animation.start_time + animation.duration) {
                *target = animation.to;
                return true;
            }

            if (now < animation.start_time) {
                return false;
            }

            float progress = static_cast<float>((now - animation.start_time).count())
                            / static_cast<float>(animation.duration.count());
            *target = animation.from + (animation.to - animation.from) * progress;
            return false;
        });

        animations.erase(end_pos, animations.end());
    }

    void draw() override {

        Renderer::draw_image(frame, horizontal_align, vertical_align, radius, path);
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
        if (object->click(x, y, left)) {
            return;
        }
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

