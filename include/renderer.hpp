#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <source_location>
#include <string_view>

#include "text_engine.hpp"

// ============================================================================
// Tide Island renderer API
// ============================================================================
//
// The renderer owns Sokol graphics resources and draws the current island state
// into the active Wayland/EGL swapchain.
//
namespace Renderer {

struct Vertex {
    float x, y;
    float r, g, b, a;
};

enum tex_pos : char {
    begin,
    middle,
    end
};

struct ObjFrame {
    float x, y;
    float width, height;
};

struct TextId {
    std::uint32_t index{};
    std::uint32_t generation{};

    bool operator==(const TextId&) const = default;
};

struct TextResourceInfo {
    float width{};
    float height{};
};

void init();

void draw_rectangle(
    ObjFrame obj_frame,
    float radius,
    bool enable_offset,
    std::array<float, 4> color);

void draw_text(
    ObjFrame frame,
    std::string_view text,
    DisplayWord::FontId font,
    std::size_t font_size,
    std::array<float, 4> color,
    tex_pos xpos = tex_pos::middle,
    tex_pos ypos = tex_pos::middle,
    DisplayWord::GlyphCachePolicy cache_policy =
        DisplayWord::GlyphCachePolicy::Ascii);

TextId create_text_resource(
    std::string_view text,
    DisplayWord::FontId font,
    std::size_t font_size,
    DisplayWord::GlyphCachePolicy cache_policy =
        DisplayWord::GlyphCachePolicy::Ascii,
    std::source_location location = std::source_location::current());

TextResourceInfo text_resource_info(TextId text);

void draw_text_resource(
    TextId text,
    float x,
    float y,
    std::array<float, 4> color);

void destroy_text_resource(TextId text);

void frame();

void shutdown();

} // namespace Renderer
