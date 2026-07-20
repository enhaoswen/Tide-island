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
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>

using namespace std;

namespace {

const Island::Island& island = Island::state();
sg_shader rectangle_shader;
sg_shader text_shader;
sg_pipeline rectangle_pipeline;
sg_pipeline text_pipeline;
sg_buffer vertex_buffer;
sg_sampler text_sampler;

struct TextKey {
    string text;
    size_t font_size{};
    int width{};
    int height{};
    Renderer::tex_pos horizontal{};
    Renderer::tex_pos vertical{};

    bool operator==(const TextKey&) const = default;
};

struct TextKeyHash {
    size_t operator()(const TextKey& key) const noexcept {
        size_t result = hash<string>{}(key.text);
        const auto combine = [&result](size_t value) {
            result ^= value + 0x9e3779b9U + (result << 6U) + (result >> 2U);
        };
        combine(key.font_size);
        combine(static_cast<size_t>(key.width));
        combine(static_cast<size_t>(key.height));
        combine(static_cast<size_t>(key.horizontal));
        combine(static_cast<size_t>(key.vertical));
        return result;
    }
};

struct TextTexture {
    sg_image image;
    sg_view view;
    uint64_t last_use{};
};

unordered_map<TextKey, TextTexture, TextKeyHash> text_cache;
uint64_t cache_clock{};
constexpr size_t max_cached_textures = 16;

sg_swapchain swapchain() {
    sg_swapchain result{};
    result.width = island.window_width;
    result.height = island.window_height;
    result.sample_count = 1;
    result.color_format = SG_PIXELFORMAT_RGBA8;
    result.depth_format = SG_PIXELFORMAT_NONE;
    result.gl.framebuffer = 0;
    return result;
}

project_uniform_t projection() {
    project_uniform_t result{};
    result.proj[0] = 2.0F / island.window_width;
    result.proj[5] = -2.0F / island.window_height;
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

void destroy_resources() {
    for (const auto& entry : text_cache) {
        destroy_text_texture(entry.second);
    }
    text_cache.clear();

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
    sg_shutdown();
    return unexpected(error);
}

void draw_state_clock(){
    if (island.state == Island::State::Clock){
        Renderer::ObjFrame frame {
            .x = 0,
            .y = island.anchor_top,
            .width = island.island_width,
            .height = island.island_height
        };
        Log::check(Renderer::draw_text(frame,Provider::style_clock() , 18, {1,1,1,1}));
    }
}

void evict_oldest_texture() {
    if (text_cache.size() < max_cached_textures) {
        return;
    }
    auto oldest = text_cache.begin();
    for (auto current = next(oldest); current != text_cache.end(); ++current) {
        if (current->second.last_use < oldest->second.last_use) {
            oldest = current;
        }
    }
    destroy_text_texture(oldest->second);
    text_cache.erase(oldest);
}

float alignment(Renderer::tex_pos position) {
    return static_cast<float>(position) * 0.5F;
}

expected<const TextTexture*, const char*> texture_for(TextKey key) {
    if (auto cached = text_cache.find(key); cached != text_cache.end()) {
        cached->second.last_use = ++cache_clock;
        return &cached->second;
    }

    auto pixels = DisplayWord::render_text(
        key.text,
        key.font_size,
        static_cast<size_t>(key.width),
        static_cast<size_t>(key.height),
        alignment(key.horizontal),
        alignment(key.vertical));
    if (!pixels) {
        return unexpected(pixels.error());
    }

    sg_image_desc image_descriptor{};
    image_descriptor.width = key.width;
    image_descriptor.height = key.height;
    image_descriptor.pixel_format = SG_PIXELFORMAT_R8;
    image_descriptor.data.mip_levels[0] = {
        .ptr = pixels->data(),
        .size = pixels->size(),
    };
    image_descriptor.label = "text_texture";
    sg_image image = sg_make_image(&image_descriptor);
    if (sg_query_image_state(image) != SG_RESOURCESTATE_VALID) {
        if (image.id)
            sg_destroy_image(image);
        return unexpected("Failed to create text texture");
    }

    sg_view_desc view_descriptor{};
    view_descriptor.texture.image = image;
    view_descriptor.label = "text_texture_view";
    sg_view view = sg_make_view(&view_descriptor);
    if (sg_query_view_state(view) != SG_RESOURCESTATE_VALID) {
        if (view.id)
            sg_destroy_view(view);
        sg_destroy_image(image);
        return unexpected("Failed to create text texture view");
    }

    evict_oldest_texture();
    auto inserted = text_cache.emplace(
        move(key),
        TextTexture{
            .image = image,
            .view = view,
            .last_use = ++cache_clock,
        });
    return &inserted.first->second;
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
    size_t font_size,
    array<float, 4> color,
    tex_pos horizontal,
    tex_pos vertical) {
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
    auto texture = texture_for({
        .text = string(text),
        .font_size = font_size,
        .width = width,
        .height = height,
        .horizontal = horizontal,
        .vertical = vertical,
    });
    if (!texture) {
        return unexpected(texture.error());
    }

    const auto vertices = text_vertices(pixel_aligned_frame, color);
    const int offset = sg_append_buffer(vertex_buffer, SG_RANGE(vertices));
    if (sg_query_buffer_overflow(vertex_buffer)) {
        return unexpected("Vertex buffer overflow");
    }

    sg_bindings bindings{};
    bindings.vertex_buffers[0] = vertex_buffer;
    bindings.vertex_buffer_offsets[0] = offset;
    bindings.views[VIEW_glyph_texture] = (*texture)->view;
    bindings.samplers[SMP_glyph_sampler] = text_sampler;
    sg_apply_pipeline(text_pipeline);
    sg_apply_bindings(&bindings);
    auto project = projection();
    sg_apply_uniforms(UB_project_uniform, SG_RANGE(project));
    sg_draw(0, 4, 1);
    return {};
}

expected<void, const char*> Renderer::frame() {
    if (island.window_width <= 0 || island.window_height <= 0) {
        return unexpected("Invalid window size");
    }

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

    if (island.state == Island::Clock){
        draw_state_clock();
    }

    sg_end_pass();
    sg_commit();

    Wayland::swap_buffer();

    return {};
}

void Renderer::shutdown() {
    destroy_resources();
    sg_shutdown();
    logger(Log::Debug, "Sokol graphics context destroyed.");
}
