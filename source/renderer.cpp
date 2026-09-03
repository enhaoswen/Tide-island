#define SOKOL_IMPL
#define STB_IMAGE_IMPLEMENTATION

#include "stb_image.h"
#include "renderer.hpp"
#include "wayland.hpp"
#include "sokol_gfx.h"
#include "basic.glsl.h"
#include "sokol_log.h"
#include "log.hpp"

#include <GLES3/gl3.h>
#include <algorithm>

#if defined(__GLIBC__)
#include <malloc.h>
#endif

using namespace std;

namespace {

sg_shader rectangle_shader{};
sg_pipeline rectangle_pipeline{};
sg_buffer rect_vertex_buffer{};

sg_shader image_shader{};
sg_pipeline image_pipeline{};
sg_buffer image_vertex_buffer{};

array<float, 24> rectangle_vertices(
    Frame frame,
    array<float, 4> color
) {
    return {
        // x, y, r, g, b, a
        frame.x,                  frame.y,                 color[0], color[1], color[2], color[3],
        frame.x + frame.width,    frame.y,                 color[0], color[1], color[2], color[3],
        frame.x,                frame.y + frame.height,  color[0], color[1], color[2], color[3],
        frame.x + frame.width,  frame.y + frame.height,  color[0], color[1], color[2], color[3],
    };
}

array<float, 16> image_vertices(Frame frame) {
    return {
        // x, y, u, v
        frame.x,                frame.y,                 0.0f, 0.0f,
        frame.x + frame.width,  frame.y,                 1.0f, 0.0f,
        frame.x,                frame.y + frame.height,  0.0f, 1.0f,
        frame.x + frame.width,  frame.y + frame.height,  1.0f, 1.0f,
    };
}

rect_proj_uniform_t projection() {
    auto surface_size = Wayland::get_surface_size();

    rect_proj_uniform_t result{};
    result.proj[0] = 2.0F / static_cast<float>(surface_size[0]);
    result.proj[5] = -2.0F / static_cast<float>(surface_size[1]);
    result.proj[10] = 1.0F;
    result.proj[12] = -1.0F;
    result.proj[13] = 1.0F;
    result.proj[15] = 1.0F;
    return result;
}

rect_radius_uniform_t radius_uniform(Frame frame, float radius) {
    rect_radius_uniform_t result{};
    result.center[0] = frame.x + frame.width / 2.0F;
    result.center[1] = frame.y + frame.height / 2.0F;
    result.half_size[0] = frame.width / 2.0F;
    result.half_size[1] = frame.height / 2.0F;
    result.radius = radius;
    return result;
}

img_radius_uniform_t img_radius_uniform(Frame frame, float radius) {
    img_radius_uniform_t result{};
    result.center[0] = frame.x + frame.width / 2.0f;
    result.center[1] = frame.y + frame.height / 2.0f;
    result.half_size[0] = frame.width / 2.0f;
    result.half_size[1] = frame.height / 2.0f;
    result.radius = radius;
    return result;
}

void enable_blending(sg_pipeline_desc& descriptor) {
    auto& blend = descriptor.colors[0].blend;
    blend.enabled = true;
    blend.src_factor_rgb = SG_BLENDFACTOR_SRC_ALPHA;
    blend.dst_factor_rgb = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    blend.src_factor_alpha = SG_BLENDFACTOR_ONE;
    blend.dst_factor_alpha = SG_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
}

sg_swapchain swapchain() {
    auto surface_size= Wayland::get_surface_size();

    sg_swapchain result{};
    result.width = surface_size[0];
    result.height = surface_size[1];
    result.sample_count = 1;
    result.color_format = SG_PIXELFORMAT_RGBA8;
    result.depth_format = SG_PIXELFORMAT_NONE;
    result.gl.framebuffer = 0;
    return result;
}

Frame calcuate_image_frame(
    Frame frame,
    Align horizontal_align,
    Align vertical_align,
    int image_width,
    int image_height) {

    Frame result{};

    float scale_x = frame.width / static_cast<float>(image_width);
    float scale_y = frame.height / static_cast<float>(image_height);
    float scale = min(scale_x, scale_y);

    float scaled_width = image_width * scale;
    float scaled_height = image_height * scale;

    if (horizontal_align == Align::Left) {
        result.x = frame.x;
    } else if (horizontal_align == Align::Center) {
        result.x = frame.x + (frame.width - scaled_width) / 2.0f;
    } else if (horizontal_align == Align::Right) {
        result.x = frame.x + frame.width - scaled_width;
    }

    if (vertical_align == Align::Left) {
        result.y = frame.y;
    } else if (vertical_align == Align::Center) {
        result.y = frame.y + (frame.height - scaled_height) / 2.0f;
    } else if (vertical_align == Align::Right) {
        result.y = frame.y + frame.height - scaled_height;
    }

    result.width = scaled_width;
    result.height = scaled_height;

    return result;
}

} // namespace

void Renderer::init() {
    // sokol environment init

    sg_desc descriptor{};
    descriptor.logger.func = slog_func;
    descriptor.environment.defaults.color_format = SG_PIXELFORMAT_RGBA8;
    descriptor.environment.defaults.depth_format = SG_PIXELFORMAT_NONE;
    descriptor.environment.defaults.sample_count = 1;
    sg_setup(&descriptor);
    if (!sg_isvalid()) {
        Log::fatal("Failed to initialize Sokol");
    }

    // rectangle environment init

    rectangle_shader = sg_make_shader(rectangle_shader_desc(sg_query_backend()));

    sg_pipeline_desc rectangle_pipe_desc{};

    rectangle_pipe_desc.shader = rectangle_shader;
    rectangle_pipe_desc.layout.attrs[ATTR_rectangle_position].format = SG_VERTEXFORMAT_FLOAT2;
    rectangle_pipe_desc.layout.attrs[ATTR_rectangle_color].format = SG_VERTEXFORMAT_FLOAT4;
    rectangle_pipe_desc.primitive_type = SG_PRIMITIVETYPE_TRIANGLE_STRIP;
    enable_blending(rectangle_pipe_desc);
    rectangle_pipeline = sg_make_pipeline(&rectangle_pipe_desc);

    sg_buffer_desc rectangle_buffer_desc{};
    rectangle_buffer_desc.size = 16 * 1024;
    rectangle_buffer_desc.usage.dynamic_update = true;
    rectangle_buffer_desc.label = "rect_vertex_buffer";
    rect_vertex_buffer = sg_make_buffer(&rectangle_buffer_desc);

    // image environment init

    image_shader = sg_make_shader(image_shader_desc((sg_query_backend())));

    sg_pipeline_desc image_pipe_desc{};

    image_pipe_desc.shader = image_shader;
    image_pipe_desc.layout.attrs[ATTR_image_position].format = SG_VERTEXFORMAT_FLOAT2;
    image_pipe_desc.layout.attrs[ATTR_image_coord].format = SG_VERTEXFORMAT_FLOAT2;
    image_pipe_desc.primitive_type = SG_PRIMITIVETYPE_TRIANGLE_STRIP;
    enable_blending(image_pipe_desc);
    image_pipeline = sg_make_pipeline(image_pipe_desc);

    sg_buffer_desc image_buffer_desc{};
    image_buffer_desc.size = 1024 * 1024;
    image_buffer_desc.usage.dynamic_update = true;
    image_buffer_desc.label = "image_vertex_buffer";
    image_vertex_buffer = sg_make_buffer(&image_buffer_desc);

    // release mem

    glReleaseShaderCompiler();
    #if defined(__GLIBC__)
        static_cast<void>(malloc_trim(0));
    #endif
}

void Renderer::begin_frame() {
    sg_pass pass{};
    pass.action.colors[0].load_action = SG_LOADACTION_CLEAR;
    pass.action.colors[0].clear_value = {0.0F, 0.0F, 0.0F, 0.0F};
    pass.swapchain = swapchain();

    sg_begin_pass(&pass);
}

void Renderer::end_frame() {
    sg_end_pass();
    sg_commit();

    Wayland::swap_buffer();
}

void Renderer::draw_rectangle(
    Frame frame,
    float radius,
    array<float, 4> color) {

    float max_r = min(frame.width, frame.height) * 0.5f;
    radius = clamp(radius, 0.0f, max_r);

    array<float,24> vertices = rectangle_vertices(frame, color);
    int offset = sg_append_buffer(rect_vertex_buffer, SG_RANGE(vertices));
    if (sg_query_buffer_overflow(rect_vertex_buffer)) {
        Log::fatal("Vertex bufer overflow");
    }

    sg_bindings bindings{};
    bindings.vertex_buffers[0] = rect_vertex_buffer;
    bindings.vertex_buffer_offsets[0] = offset;
    sg_apply_pipeline(rectangle_pipeline);
    sg_apply_bindings(&bindings);
    auto project = projection();
    auto radius_data = radius_uniform(frame, radius);
    sg_apply_uniforms(UB_rect_proj_uniform, SG_RANGE(project));
    sg_apply_uniforms(UB_rect_radius_uniform, SG_RANGE(radius_data));
    sg_draw(0, 4, 1);
}

void Renderer::draw_image(
    Frame frame,
    Align horizontal_align,
    Align vertical_align,
    float radius,
    string path) {

    int width, height, channels;

    unsigned char* pixels = stbi_load(path.c_str(), &width, &height, &channels, 4);

    if (!pixels) {
        Log::fatal("Failed to load picture {}",path);
    }

    sg_image_desc image_desc {
        .type = SG_IMAGETYPE_2D,
        .usage = {
            .immutable = true
        },
        .width = width,
        .height = height,
        .num_slices = 1,
        .num_mipmaps = 1,
        .pixel_format = SG_PIXELFORMAT_RGBA8,
        .sample_count = 1,
        .data = {
            .mip_levels = {
                {
                    .ptr = pixels,
                    .size = static_cast<size_t>(width * height * 4)
                }
            }
        }
    };
    sg_image image = sg_make_image(image_desc);

    if (sg_query_image_state(image) != SG_RESOURCESTATE_VALID) {
        Log::fatal("Failed to create image");
    }

    sg_sampler_desc sampler_desc {
        .min_filter = SG_FILTER_LINEAR,
        .mag_filter = SG_FILTER_LINEAR,
        .wrap_u = SG_WRAP_CLAMP_TO_EDGE,
        .wrap_v = SG_WRAP_CLAMP_TO_EDGE,
    };
    sg_sampler image_sampler = sg_make_sampler(sampler_desc);

    if (sg_query_sampler_state(image_sampler) != SG_RESOURCESTATE_VALID) {
        Log::fatal("Failed to create sampler");
    }

    array<float,16> vertices = image_vertices(
        calcuate_image_frame(
            frame, 
            horizontal_align, 
            vertical_align, 
            width, 
            height));

    int offset = sg_append_buffer(image_vertex_buffer, SG_RANGE(vertices));

    sg_view_desc tex_view_desc {
        .texture = {
            .image = image
        }
    };

    sg_view tex_view = sg_make_view(tex_view_desc);

    if (sg_query_view_state(tex_view) != SG_RESOURCESTATE_VALID) {
        Log::fatal("Failed to create texture view");
    }

    sg_bindings bindings{};
    bindings.vertex_buffers[0] = image_vertex_buffer;
    bindings.samplers[SMP_smp] = image_sampler;
    bindings.views[VIEW_tex] = tex_view;

    sg_apply_pipeline(image_pipeline);

    if (sg_query_pipeline_state(image_pipeline) != SG_RESOURCESTATE_VALID) {
        Log::fatal("Image pipeline is invalid (shader compile error?)");
    }

    sg_apply_bindings(&bindings);

    auto project = projection();
    sg_apply_uniforms(UB_img_proj, SG_RANGE(project));

    img_radius_uniform_t radius_data = img_radius_uniform(frame, radius);
    sg_apply_uniforms(UB_img_radius_uniform, SG_RANGE(radius_data));

    sg_draw(0, 4, 1);

    stbi_image_free(pixels);
    sg_destroy_image(image);
    sg_destroy_sampler(image_sampler);
    sg_destroy_view(tex_view);
}
