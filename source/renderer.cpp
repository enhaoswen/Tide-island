// ============================================================================
// Tide Island renderer backend
// ============================================================================
#include "renderer.hpp"
#include "island.hpp"
#include "log.hpp"
#include "text_engine.hpp"
#include "provider.hpp"
#include "wayland.hpp"

#include "sokol_gfx.h"
#include "sokol_log.h"
#include "basic.glsl.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <expected>
#include <limits>
#include <source_location>
#include <string>
#include <string_view>
#include <vector>

using namespace std;

namespace {

const Island::Island& island = Island::state();
sg_shader rectangle_shader;
sg_shader text_shader;
sg_pipeline rectangle_pipeline;
sg_pipeline text_pipeline;
sg_buffer vertex_buffer;
sg_sampler text_sampler;

struct TextTexture {
    sg_image image{};
    sg_view view{};
    int width{};
    int height{};
};

struct TextResourceSlot {
    TextTexture texture;
    uint32_t generation{1};
    bool occupied{};
#if !defined(NDEBUG)
    string debug_text;
    source_location creation_location{};
#endif
};

vector<TextResourceSlot> text_resource_slots;
vector<uint32_t> free_text_resource_slots;
vector<TextTexture> transient_textures;
size_t active_text_resources{};
constexpr size_t text_resource_warning_threshold = 30;

sg_swapchain swapchain() {
    sg_swapchain result{};
    result.width = island.surface_width;
    result.height = island.surface_height;
    result.sample_count = 1;
    result.color_format = SG_PIXELFORMAT_RGBA8;
    result.depth_format = SG_PIXELFORMAT_NONE;
    result.gl.framebuffer = 0;
    return result;
}

project_uniform_t projection() {
    project_uniform_t result{};
    result.proj[0] = 2.0F / island.surface_width;
    result.proj[5] = -2.0F / island.surface_height;
    result.proj[10] = 1.0F;
    result.proj[12] = -1.0F;
    result.proj[13] = 1.0F;
    result.proj[15] = 1.0F;
    return result;
}

radius_uniform_t radius_uniform(Renderer::ObjFrame frame, float radius) {
    radius_uniform_t result{};
    result.center[0] = frame.x + frame.width / 2.0F;
    result.center[1] = frame.y + frame.height / 2.0F;
    result.half_size[0] = frame.width / 2.0F;
    result.half_size[1] = frame.height / 2.0F;
    result.radius = radius;
    return result;
}

array<float, 24> rectangle_vertices(
    Renderer::ObjFrame frame,
    array<float, 4> color) {
    return { frame.x, frame.y, color[0], color[1],
        color[2], color[3], frame.x + frame.width, frame.y,
        color[0], color[1], color[2], color[3],
        frame.x, frame.y + frame.height, color[0],
        color[1], color[2], color[3], frame.x + frame.width,
        frame.y + frame.height, color[0], color[1], color[2], color[3],
    };
}

array<float, 32> text_vertices(
    Renderer::ObjFrame frame,
    array<float, 4> color) {
    // clang-format off
    return {
        frame.x, frame.y, 0.0F, 0.0F,
        color[0], color[1], color[2], color[3],
        frame.x + frame.width, frame.y, 1.0F, 0.0F,
        color[0], color[1], color[2], color[3],
        frame.x, frame.y + frame.height, 0.0F, 1.0F,
        color[0], color[1], color[2], color[3],
        frame.x + frame.width, frame.y + frame.height, 1.0F, 1.0F,
        color[0], color[1], color[2], color[3],
    };
    // clang-format on
}

void enable_blending(sg_pipeline_desc& descriptor) {
    auto& blend = descriptor.colors[0].blend;
    blend.enabled = true;
    blend.src_factor_rgb = SG_BLENDFACTOR_SRC_ALPHA;
    blend.dst_factor_rgb = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    blend.src_factor_alpha = SG_BLENDFACTOR_ONE;
    blend.dst_factor_alpha = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
}

void destroy_text_texture(TextTexture texture) {
    if (texture.view.id != SG_INVALID_ID) {
        sg_destroy_view(texture.view);
    }
    if (texture.image.id != SG_INVALID_ID) {
        sg_destroy_image(texture.image);
    }
}

uint32_t next_generation(uint32_t generation) {
    ++generation;
    if (generation == 0) {
        ++generation;
    }
    return generation;
}

void destroy_transient_textures() {
    for (TextTexture texture : transient_textures) {
        destroy_text_texture(texture);
    }
    transient_textures.clear();
}

void destroy_resources() {
    destroy_transient_textures();

    for (size_t index = 0; index < text_resource_slots.size(); ++index) {
        TextResourceSlot& slot = text_resource_slots[index];
        if (!slot.occupied) {
            continue;
        }
#if !defined(NDEBUG)
        logger(
            Log::Warning,
            "Leaked text resource {}:{} created at {}:{} ({}) for text '{}'",
            index,
            slot.generation,
            slot.creation_location.file_name(),
            slot.creation_location.line(),
            slot.creation_location.function_name(),
            slot.debug_text);
#endif
        destroy_text_texture(slot.texture);
        slot = {};
    }
    text_resource_slots.clear();
    free_text_resource_slots.clear();
    active_text_resources = 0;

    if (text_sampler.id)
        sg_destroy_sampler(text_sampler);
    if (vertex_buffer.id)
        sg_destroy_buffer(vertex_buffer);
    if (text_pipeline.id)
        sg_destroy_pipeline(text_pipeline);
    if (rectangle_pipeline.id)
        sg_destroy_pipeline(rectangle_pipeline);
    if (text_shader.id)
        sg_destroy_shader(text_shader);
    if (rectangle_shader.id)
        sg_destroy_shader(rectangle_shader);
    text_sampler = {};
    vertex_buffer = {};
    text_pipeline = {};
    rectangle_pipeline = {};
    text_shader = {};
    rectangle_shader = {};
}

expected<void, const char*> fail_init(const char* error) {
    destroy_resources();
    DisplayWord::shutdown();
    sg_shutdown();
    return unexpected(error);
}

void draw_state_clock() {
    if (island.state == Island::State::Clock) {
        Renderer::ObjFrame frame{
            .x = 0,
            .y = island.anchor_top,
            .width = island.island_width,
            .height = island.island_height};
        Log::check(Renderer::draw_text(
            frame,
            Provider::style_clock(),
            DisplayWord::default_font(),
            18,
            {1, 1, 1, 1}));
    }
}

float alignment(Renderer::tex_pos position) {
    return static_cast<float>(position) * 0.5F;
}

expected<TextTexture, const char*> make_text_texture(
    const char* pixels,
    size_t byte_count,
    size_t width,
    size_t height,
    const char* label) {
    if (pixels == nullptr || width == 0 || height == 0 ||
        width > static_cast<size_t>(numeric_limits<int>::max()) ||
        height > static_cast<size_t>(numeric_limits<int>::max())) {
        return unexpected("Invalid text bitmap");
    }

    sg_image_desc image_descriptor{};
    image_descriptor.width = static_cast<int>(width);
    image_descriptor.height = static_cast<int>(height);
    image_descriptor.pixel_format = SG_PIXELFORMAT_R8;
    image_descriptor.data.mip_levels[0] = {
        .ptr = pixels,
        .size = byte_count,
    };
    image_descriptor.label = label;
    sg_image image = sg_make_image(&image_descriptor);
    if (sg_query_image_state(image) != SG_RESOURCESTATE_VALID) {
        if (image.id != SG_INVALID_ID) {
            sg_destroy_image(image);
        }
        return unexpected("Failed to create text texture");
    }

    sg_view_desc view_descriptor{};
    view_descriptor.texture.image = image;
    view_descriptor.label = label;
    sg_view view = sg_make_view(&view_descriptor);
    if (sg_query_view_state(view) != SG_RESOURCESTATE_VALID) {
        if (view.id != SG_INVALID_ID) {
            sg_destroy_view(view);
        }
        sg_destroy_image(image);
        return unexpected("Failed to create text texture view");
    }

    return TextTexture{
        .image = image,
        .view = view,
        .width = static_cast<int>(width),
        .height = static_cast<int>(height),
    };
}

expected<void, const char*> draw_text_texture(
    const TextTexture& texture,
    Renderer::ObjFrame frame,
    array<float, 4> color) {
    const auto vertices = text_vertices(frame, color);
    const int offset = sg_append_buffer(vertex_buffer, SG_RANGE(vertices));
    if (sg_query_buffer_overflow(vertex_buffer)) {
        return unexpected("Vertex buffer overflow");
    }

    sg_bindings bindings{};
    bindings.vertex_buffers[0] = vertex_buffer;
    bindings.vertex_buffer_offsets[0] = offset;
    bindings.views[VIEW_glyph_texture] = texture.view;
    bindings.samplers[SMP_glyph_sampler] = text_sampler;
    sg_apply_pipeline(text_pipeline);
    sg_apply_bindings(&bindings);
    auto project = projection();
    sg_apply_uniforms(UB_project_uniform, SG_RANGE(project));
    sg_draw(0, 4, 1);
    return {};
}

expected<TextResourceSlot*, const char*> text_resource_slot(Renderer::TextId id) {
    if (id.generation == 0 || id.index >= text_resource_slots.size()) {
        return unexpected("Invalid text resource ID");
    }

    TextResourceSlot& slot = text_resource_slots[id.index];
    if (!slot.occupied || slot.generation != id.generation) {
        return unexpected("Stale text resource ID");
    }
    return &slot;
}

} // namespace

expected<void, const char*> Renderer::init() {
    sg_desc descriptor{};
    descriptor.logger.func = slog_func;
    descriptor.environment.defaults.color_format = SG_PIXELFORMAT_RGBA8;
    descriptor.environment.defaults.depth_format = SG_PIXELFORMAT_NONE;
    descriptor.environment.defaults.sample_count = 1;
    sg_setup(&descriptor);
    if (!sg_isvalid()) {
        return unexpected("Failed to initialize Sokol");
    }

    if (auto result = DisplayWord::init(); !result) {
        return fail_init(result.error());
    }

    rectangle_shader =
        sg_make_shader(rectangle_shader_desc(sg_query_backend()));
    text_shader = sg_make_shader(text_shader_desc(sg_query_backend()));
    if (sg_query_shader_state(rectangle_shader) != SG_RESOURCESTATE_VALID ||
        sg_query_shader_state(text_shader) != SG_RESOURCESTATE_VALID) {
        return fail_init("Failed to create shaders");
    }

    sg_pipeline_desc rectangle_descriptor{};
    rectangle_descriptor.shader = rectangle_shader;
    rectangle_descriptor.layout.attrs[ATTR_rectangle_position].format =
        SG_VERTEXFORMAT_FLOAT2;
    rectangle_descriptor.layout.attrs[ATTR_rectangle_color].format =
        SG_VERTEXFORMAT_FLOAT4;
    rectangle_descriptor.primitive_type = SG_PRIMITIVETYPE_TRIANGLE_STRIP;
    enable_blending(rectangle_descriptor);
    rectangle_pipeline = sg_make_pipeline(&rectangle_descriptor);

    sg_pipeline_desc text_descriptor{};
    text_descriptor.shader = text_shader;
    text_descriptor.layout.attrs[ATTR_text_pos].format =
        SG_VERTEXFORMAT_FLOAT2;
    text_descriptor.layout.attrs[ATTR_text_uv].format =
        SG_VERTEXFORMAT_FLOAT2;
    text_descriptor.layout.attrs[ATTR_text_color].format =
        SG_VERTEXFORMAT_FLOAT4;
    text_descriptor.primitive_type = SG_PRIMITIVETYPE_TRIANGLE_STRIP;
    enable_blending(text_descriptor);
    text_pipeline = sg_make_pipeline(&text_descriptor);
    if (sg_query_pipeline_state(rectangle_pipeline) != SG_RESOURCESTATE_VALID ||
        sg_query_pipeline_state(text_pipeline) != SG_RESOURCESTATE_VALID) {
        return fail_init("Failed to create pipelines");
    }

    sg_buffer_desc buffer_descriptor{};
    buffer_descriptor.size = 16 * 1024;
    buffer_descriptor.usage.dynamic_update = true;
    buffer_descriptor.label = "ui_vertex_buffer";
    vertex_buffer = sg_make_buffer(&buffer_descriptor);

    sg_sampler_desc sampler_descriptor{};
    sampler_descriptor.min_filter = SG_FILTER_NEAREST;
    sampler_descriptor.mag_filter = SG_FILTER_NEAREST;
    sampler_descriptor.wrap_u = SG_WRAP_CLAMP_TO_EDGE;
    sampler_descriptor.wrap_v = SG_WRAP_CLAMP_TO_EDGE;
    sampler_descriptor.label = "text_sampler";
    text_sampler = sg_make_sampler(&sampler_descriptor);
    if (sg_query_buffer_state(vertex_buffer) != SG_RESOURCESTATE_VALID ||
        sg_query_sampler_state(text_sampler) != SG_RESOURCESTATE_VALID) {
        return fail_init("Failed to create renderer resources");
    }
    return {};
}

expected<void, const char*> Renderer::draw_rectangle(
    ObjFrame frame,
    float radius,
    array<float, 4> color) {
    if (frame.width <= 0.0F || frame.height <= 0.0F) {
        return unexpected("Invalid rectangle size");
    }

    if (radius <= 0){
        return unexpected("Radius should not be neagative");
    }

    const auto vertices = rectangle_vertices(frame, color);
    const int offset = sg_append_buffer(vertex_buffer, SG_RANGE(vertices));
    if (sg_query_buffer_overflow(vertex_buffer)) {
        return unexpected("Vertex buffer overflow");
    }

    sg_bindings bindings{};
    bindings.vertex_buffers[0] = vertex_buffer;
    bindings.vertex_buffer_offsets[0] = offset;
    sg_apply_pipeline(rectangle_pipeline);
    sg_apply_bindings(&bindings);
    auto project = projection();
    auto radius_data = radius_uniform(frame, radius);
    sg_apply_uniforms(UB_project_uniform, SG_RANGE(project));
    sg_apply_uniforms(UB_radius_uniform, SG_RANGE(radius_data));
    sg_draw(0, 4, 1);
    return {};
}

expected<void, const char*> Renderer::draw_text(
    ObjFrame frame,
    string_view text,
    DisplayWord::FontId font,
    size_t font_size,
    array<float, 4> color,
    tex_pos horizontal,
    tex_pos vertical,
    DisplayWord::GlyphCachePolicy cache_policy) {
    if (font_size == 0 ||
        frame.width <= 0.0F || frame.height <= 0.0F) {
        return unexpected("Invalid text arguments");
    }
    if (text.empty()) {
        return {};
    }

    const int width = max(1, static_cast<int>(lround(frame.width)));
    const int height = max(1, static_cast<int>(lround(frame.height)));
    const ObjFrame pixel_aligned_frame{
        .x = round(frame.x),
        .y = round(frame.y),
        .width = static_cast<float>(width),
        .height = static_cast<float>(height),
    };

    auto pixels = DisplayWord::render_text(
        font,
        text,
        font_size,
        static_cast<size_t>(width),
        static_cast<size_t>(height),
        alignment(horizontal),
        alignment(vertical),
        cache_policy);
    if (!pixels) {
        return unexpected(pixels.error());
    }

    auto texture = make_text_texture(
        pixels->data(),
        pixels->size(),
        static_cast<size_t>(width),
        static_cast<size_t>(height),
        "transient_text_texture");
    if (!texture) {
        return unexpected(texture.error());
    }

    transient_textures.push_back(*texture);
    return draw_text_texture(transient_textures.back(), pixel_aligned_frame, color);
}

expected<Renderer::TextId, const char*> Renderer::create_text_resource(
    string_view text,
    DisplayWord::FontId font,
    size_t font_size,
    DisplayWord::GlyphCachePolicy cache_policy,
    source_location location) {
    if (text.empty() || font_size == 0) {
        return unexpected("Invalid text resource arguments");
    }

    auto bitmap = DisplayWord::render_text_tight(
        font,
        text,
        font_size,
        cache_policy);
    if (!bitmap) {
        return unexpected(bitmap.error());
    }

    auto texture = make_text_texture(
        bitmap->pixels.data(),
        bitmap->pixels.size(),
        bitmap->width,
        bitmap->height,
        "retained_text_texture");
    if (!texture) {
        return unexpected(texture.error());
    }

    uint32_t index{};
    if (!free_text_resource_slots.empty()) {
        index = free_text_resource_slots.back();
        free_text_resource_slots.pop_back();
    }
    else {
        if (text_resource_slots.size() >= numeric_limits<uint32_t>::max()) {
            destroy_text_texture(*texture);
            return unexpected("Too many text resources");
        }
        index = static_cast<uint32_t>(text_resource_slots.size());
        text_resource_slots.emplace_back();
    }

    TextResourceSlot& slot = text_resource_slots[index];
    slot.texture = *texture;
    slot.occupied = true;
#if !defined(NDEBUG)
    constexpr size_t debug_text_limit = 80;
    slot.debug_text = string(text.substr(0, debug_text_limit));
    slot.creation_location = location;
#else
    static_cast<void>(location);
#endif
    ++active_text_resources;

#if !defined(NDEBUG)
    logger(
        Log::Debug,
        "Created text resource {}:{} at {}:{}; active resources: {}",
        index,
        slot.generation,
        location.file_name(),
        location.line(),
        active_text_resources);
    if (active_text_resources > text_resource_warning_threshold) {
        logger(
            Log::Warning,
            "Possible text resource leak: {} resources are active",
            active_text_resources);
    }
#endif

    return TextId{index, slot.generation};
}

expected<Renderer::TextResourceInfo, const char*>
Renderer::text_resource_info(TextId text) {
    auto slot = text_resource_slot(text);
    if (!slot) {
        return unexpected(slot.error());
    }
    return TextResourceInfo{
        .width = static_cast<float>((*slot)->texture.width),
        .height = static_cast<float>((*slot)->texture.height),
    };
}

expected<void, const char*> Renderer::draw_text_resource(
    TextId text,
    float x,
    float y,
    array<float, 4> color) {
    if (!isfinite(x) || !isfinite(y)) {
        return unexpected("Invalid text resource position");
    }

    auto slot = text_resource_slot(text);
    if (!slot) {
        return unexpected(slot.error());
    }
    const TextTexture& texture = (*slot)->texture;
    return draw_text_texture(
        texture,
        {
            .x = x,
            .y = y,
            .width = static_cast<float>(texture.width),
            .height = static_cast<float>(texture.height),
        },
        color);
}

expected<void, const char*> Renderer::destroy_text_resource(TextId text) {
    auto slot_result = text_resource_slot(text);
    if (!slot_result) {
        return unexpected(slot_result.error());
    }

    TextResourceSlot& slot = **slot_result;
    destroy_text_texture(slot.texture);
    slot.texture = {};
    slot.occupied = false;
    slot.generation = next_generation(slot.generation);
#if !defined(NDEBUG)
    slot.debug_text.clear();
    slot.creation_location = {};
    logger(
        Log::Debug,
        "Destroyed text resource {}:{}; active resources: {}",
        text.index,
        text.generation,
        active_text_resources - 1);
#endif
    --active_text_resources;
    free_text_resource_slots.push_back(text.index);
    return {};
}

expected<void, const char*> Renderer::frame() {
    if (island.surface_width <= 0 || island.surface_height <= 0) {
        return unexpected("Invalid window size");
    }

    destroy_transient_textures();

    sg_pass pass{};
    pass.action.colors[0].load_action = SG_LOADACTION_CLEAR;
    pass.action.colors[0].clear_value = {0.0F, 0.0F, 0.0F, 0.0F};
    pass.swapchain = swapchain();
    sg_begin_pass(&pass);

    expected<void, const char*> result = draw_rectangle(
        {
            .x = 0.0F,
            .y = island.anchor_top,
            .width = island.island_width,
            .height = island.island_height,
        },
        island.radius,
        island.color);
    if (!result) {
        sg_end_pass();
        return result;
    }

    if (island.state == Island::Clock) {
        draw_state_clock();
    }

    sg_end_pass();
    sg_commit();

    Wayland::swap_buffer();

    return {};
}

void Renderer::shutdown() {
    destroy_resources();
    DisplayWord::shutdown();
    sg_shutdown();
    logger(Log::Debug, "Sokol graphics context destroyed.");
}
