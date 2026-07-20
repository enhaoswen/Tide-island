// ============================================================================
// Tide Island text shaping backend
// ============================================================================
//
// HarfBuzz positions glyphs, FreeType rasterizes them, and this file composes
// the result into one tightly packed R8 bitmap supplied to the renderer.
//
#include "text_engine.hpp"

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <expected>
#include <ft2build.h>
#include FT_FREETYPE_H
#include <harfbuzz/hb-ft.h>
#include <harfbuzz/hb.h>
#include <limits>
#include <memory>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace std;

namespace {

struct ShapedGlyph {
    uint32_t id{};
    float advance_x{};
    float advance_y{};
    float offset_x{};
    float offset_y{};
};

struct Glyph {
    int width{};
    int height{};
    int left{};
    int top{};
    vector<char> pixels;
};

struct PositionedGlyph {
    const Glyph* glyph{};
    float left{};
    float top{};
};

struct GlyphKey {
    uint32_t id{};
    uint32_t size{};

    bool operator==(const GlyphKey&) const = default;
};

struct GlyphKeyHash {
    size_t operator()(GlyphKey key) const noexcept {
        return (static_cast<size_t>(key.size) << 32U) ^ key.id;
    }
};

template <auto destroy>
struct Deleter {
    void operator()(auto* pointer) const noexcept {
        if (pointer) {
            destroy(pointer);
        }
    }
};

unique_ptr<FT_LibraryRec_, Deleter<FT_Done_FreeType>> library;
unique_ptr<FT_FaceRec_, Deleter<FT_Done_Face>> face;
unique_ptr<hb_font_t, Deleter<hb_font_destroy>> hb_font;
unique_ptr<hb_buffer_t, Deleter<hb_buffer_destroy>> hb_buffer;
unordered_map<GlyphKey, Glyph, GlyphKeyHash> glyph_cache;
size_t current_size{};

constexpr string_view font_path =
    "/usr/share/fonts/noto/NotoSans-Regular.ttf";

expected<void, const char*> set_font_size(size_t size) {
    if (size == 0 || size > numeric_limits<FT_UInt>::max()) {
        return unexpected("Invalid font size");
    }
    if (size == current_size) {
        return {};
    }
    if (FT_Set_Pixel_Sizes(face.get(), 0, static_cast<FT_UInt>(size))) {
        return unexpected("Failed to set font size");
    }

    hb_ft_font_changed(hb_font.get());
    current_size = size;
    return {};
}

vector<ShapedGlyph> shape(string_view text) {
    hb_buffer_clear_contents(hb_buffer.get());
    hb_buffer_add_utf8(
        hb_buffer.get(),
        text.data(),
        static_cast<int>(text.size()),
        0,
        static_cast<int>(text.size()));
    hb_buffer_guess_segment_properties(hb_buffer.get());
    hb_shape(hb_font.get(), hb_buffer.get(), nullptr, 0);

    unsigned int count{};
    const hb_glyph_info_t* infos =
        hb_buffer_get_glyph_infos(hb_buffer.get(), &count);
    const hb_glyph_position_t* positions =
        hb_buffer_get_glyph_positions(hb_buffer.get(), &count);

    vector<ShapedGlyph> result;
    result.reserve(count);
    for (unsigned int index = 0; index < count; ++index) {
        result.push_back({
            .id = infos[index].codepoint,
            .advance_x = positions[index].x_advance / 64.0F,
            .advance_y = positions[index].y_advance / 64.0F,
            .offset_x = positions[index].x_offset / 64.0F,
            .offset_y = positions[index].y_offset / 64.0F,
        });
    }
    return result;
}

const unsigned char* bitmap_row(const FT_Bitmap& bitmap, unsigned int row) {
    if (bitmap.pitch >= 0) {
        return bitmap.buffer + static_cast<ptrdiff_t>(row) * bitmap.pitch;
    }
    return bitmap.buffer +
        static_cast<ptrdiff_t>(bitmap.rows - row - 1U) * -bitmap.pitch;
}

expected<vector<char>, const char*> copy_bitmap(const FT_Bitmap& bitmap) {
    vector<char> pixels(static_cast<size_t>(bitmap.width) * bitmap.rows);
    if (!bitmap.buffer) {
        return pixels;
    }

    for (unsigned int y = 0; y < bitmap.rows; ++y) {
        const unsigned char* source = bitmap_row(bitmap, y);
        char* target = pixels.data() + static_cast<size_t>(y) * bitmap.width;

        switch (bitmap.pixel_mode) {
        case FT_PIXEL_MODE_GRAY:
            if (bitmap.num_grays == 256) {
                memcpy(target, source, bitmap.width);
                break;
            }
            for (unsigned int x = 0; x < bitmap.width; ++x) {
                const unsigned int maximum =
                    bitmap.num_grays > 1 ? bitmap.num_grays - 1U : 1U;
                target[x] = static_cast<char>(source[x] * 255U / maximum);
            }
            break;

        case FT_PIXEL_MODE_MONO:
            for (unsigned int x = 0; x < bitmap.width; ++x) {
                const unsigned char mask =
                    static_cast<unsigned char>(0x80U >> (x & 7U));
                target[x] = static_cast<char>(
                    (source[x >> 3U] & mask) ? 255U : 0U);
            }
            break;

        case FT_PIXEL_MODE_BGRA:
            for (unsigned int x = 0; x < bitmap.width; ++x) {
                target[x] = static_cast<char>(source[x * 4U + 3U]);
            }
            break;

        default:
            return unexpected("Unsupported glyph bitmap format");
        }
    }
    return pixels;
}

expected<const Glyph*, const char*> rasterize(uint32_t id) {
    const GlyphKey key{
        .id = id,
        .size = static_cast<uint32_t>(current_size),
    };
    if (const auto cached = glyph_cache.find(key); cached != glyph_cache.end()) {
        return &cached->second;
    }

    if (FT_Load_Glyph(
            face.get(),
            static_cast<FT_UInt>(id),
            FT_LOAD_DEFAULT | FT_LOAD_TARGET_LIGHT |
                FT_LOAD_RENDER | FT_LOAD_COLOR)) {
        return unexpected("Failed to rasterize glyph");
    }

    const FT_Bitmap& bitmap = face->glyph->bitmap;
    auto pixels = copy_bitmap(bitmap);
    if (!pixels) {
        return unexpected(pixels.error());
    }

    auto inserted = glyph_cache.emplace(
        key,
        Glyph{
            .width = static_cast<int>(bitmap.width),
            .height = static_cast<int>(bitmap.rows),
            .left = face->glyph->bitmap_left,
            .top = face->glyph->bitmap_top,
            .pixels = move(*pixels),
        });
    return &inserted.first->second;
}

} // namespace

expected<void, const char*> DisplayWord::init() {
    hb_buffer.reset();
    hb_font.reset();
    face.reset();
    library.reset();
    glyph_cache.clear();
    current_size = 0;

    FT_Library raw_library{};
    if (FT_Init_FreeType(&raw_library)) {
        return unexpected("Failed to initialize FreeType");
    }
    library.reset(raw_library);

    FT_Face raw_face{};
    if (FT_New_Face(
            raw_library,
            font_path.data(),
            0,
            &raw_face)) {
        return unexpected("Failed to load font");
    }
    face.reset(raw_face);

    hb_font_t* raw_font = hb_ft_font_create_referenced(raw_face);
    if (!raw_font) {
        return unexpected("Failed to create HarfBuzz font");
    }
    hb_font.reset(raw_font);

    hb_buffer_t* raw_buffer = hb_buffer_create();
    if (!raw_buffer || !hb_buffer_allocation_successful(raw_buffer)) {
        if (raw_buffer) {
            hb_buffer_destroy(raw_buffer);
        }
        return unexpected("Failed to create HarfBuzz buffer");
    }
    hb_buffer.reset(raw_buffer);
    return {};
}

expected<vector<char>, const char*> DisplayWord::render_text(
    string_view text,
    size_t font_size,
    size_t width,
    size_t height,
    float horizontal_alignment,
    float vertical_alignment) {
    if (text.empty() || !face || !hb_font || !hb_buffer) {
        return unexpected("Text engine is not ready");
    }
    if (width == 0 || height == 0 ||
        width > static_cast<size_t>(numeric_limits<int>::max()) ||
        height > static_cast<size_t>(numeric_limits<int>::max()) ||
        width > numeric_limits<size_t>::max() / height) {
        return unexpected("Invalid text texture size");
    }

    auto size_result = set_font_size(font_size);
    if (!size_result) {
        return unexpected(size_result.error());
    }

    vector<char> output(width * height);
    vector<ShapedGlyph> shaped = shape(text);
    if (shaped.empty()) {
        return output;
    }

    float min_x{};
    float max_x{};
    float min_y = face->size->metrics.descender / 64.0F;
    float max_y = face->size->metrics.ascender / 64.0F;
    float pen_x{};
    float pen_y{};
    vector<PositionedGlyph> positioned;
    positioned.reserve(shaped.size());

    for (const ShapedGlyph& shaped_glyph : shaped) {
        auto glyph_result = rasterize(shaped_glyph.id);
        if (!glyph_result) {
            return unexpected(glyph_result.error());
        }

        const Glyph* glyph = *glyph_result;
        const float left =
            pen_x + shaped_glyph.offset_x + glyph->left;
        const float top =
            pen_y + shaped_glyph.offset_y + glyph->top;
        positioned.push_back({glyph, left, top});

        min_x = min(min_x, left);
        max_x = max(max_x, left + glyph->width);
        min_y = min(min_y, top - glyph->height);
        max_y = max(max_y, top);
        pen_x += shaped_glyph.advance_x;
        pen_y += shaped_glyph.advance_y;
    }
    min_x = min(min_x, pen_x);
    max_x = max(max_x, pen_x);

    horizontal_alignment = clamp(horizontal_alignment, 0.0F, 1.0F);
    vertical_alignment = clamp(vertical_alignment, 0.0F, 1.0F);
    const float content_width = max_x - min_x;
    const float content_height = max_y - min_y;
    const float origin_x =
        (static_cast<float>(width) - content_width) * horizontal_alignment -
        min_x;
    const float origin_y =
        (static_cast<float>(height) - content_height) * vertical_alignment;

    for (const PositionedGlyph& item : positioned) {
        const int destination_x =
            static_cast<int>(lround(origin_x + item.left));
        const int destination_y =
            static_cast<int>(lround(origin_y + max_y - item.top));

        for (int source_y = 0; source_y < item.glyph->height; ++source_y) {
            const int target_y = destination_y + source_y;
            if (target_y < 0 || target_y >= static_cast<int>(height)) {
                continue;
            }
            for (int source_x = 0; source_x < item.glyph->width; ++source_x) {
                const int target_x = destination_x + source_x;
                if (target_x < 0 || target_x >= static_cast<int>(width)) {
                    continue;
                }

                const size_t source_index =
                    static_cast<size_t>(source_y) * item.glyph->width + source_x;
                const size_t target_index =
                    static_cast<size_t>(target_y) * width + target_x;
                const auto source =
                    static_cast<unsigned char>(item.glyph->pixels[source_index]);
                const auto destination =
                    static_cast<unsigned char>(output[target_index]);
                output[target_index] =
                    static_cast<char>(max(source, destination));
            }
        }
    }
    return output;
}

size_t DisplayWord::cache_size() {
    return glyph_cache.size();
}
