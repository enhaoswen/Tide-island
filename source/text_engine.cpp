// ============================================================================
// Tide Island text shaping backend
// ============================================================================
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
#include <string>
#include <string_view>
#include <unordered_map>
#include <utility>
#include <vector>

using namespace std;

namespace {

struct ShapedGlyph {
    uint32_t id{};
    uint32_t cluster{};
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
        size_t result = hash<uint32_t>{}(key.id);
        result ^= hash<uint32_t>{}(key.size) + 0x9e3779b9U +
            (result << 6U) + (result >> 2U);
        return result;
    }
};

template <auto destroy>
struct Deleter {
    void operator()(auto* pointer) const noexcept {
        if (pointer != nullptr) {
            destroy(pointer);
        }
    }
};

struct FontResource {
    unique_ptr<FT_FaceRec_, Deleter<FT_Done_Face>> face;
    unique_ptr<hb_font_t, Deleter<hb_font_destroy>> hb_font;
    unordered_map<GlyphKey, Glyph, GlyphKeyHash> glyph_cache;
    size_t current_size{};
};

struct FontSlot {
    FontResource resource;
    uint32_t generation{1};
    bool occupied{};
};

struct TextLayout {
    vector<Glyph> temporary_glyphs;
    vector<PositionedGlyph> positioned;
    float min_x{};
    float max_x{};
    float min_y{};
    float max_y{};
};

unique_ptr<FT_LibraryRec_, Deleter<FT_Done_FreeType>> library;
unique_ptr<hb_buffer_t, Deleter<hb_buffer_destroy>> hb_buffer;
vector<FontSlot> font_slots;
vector<uint32_t> free_font_slots;
DisplayWord::FontId default_font_id{};

constexpr string_view default_font_path =
    "/usr/share/fonts/noto/NotoSans-Regular.ttf";

uint32_t next_generation(uint32_t generation) {
    ++generation;
    if (generation == 0) {
        ++generation;
    }
    return generation;
}

expected<FontResource*, const char*> font_for(DisplayWord::FontId id) {
    if (id.generation == 0 || id.index >= font_slots.size()) {
        return unexpected("Invalid font ID");
    }

    FontSlot& slot = font_slots[id.index];
    if (!slot.occupied || slot.generation != id.generation) {
        return unexpected("Stale font ID");
    }
    return &slot.resource;
}

expected<void, const char*> set_font_size(FontResource& font, size_t size) {
    if (size == 0 || size > numeric_limits<FT_UInt>::max()) {
        return unexpected("Invalid font size");
    }
    if (size == font.current_size) {
        return {};
    }
    if (FT_Set_Pixel_Sizes(font.face.get(), 0, static_cast<FT_UInt>(size)) != 0) {
        return unexpected("Failed to set font size");
    }

    hb_ft_font_changed(font.hb_font.get());
    font.current_size = size;
    return {};
}

expected<vector<ShapedGlyph>, const char*> shape(
    FontResource& font,
    string_view text) {
    if (text.size() > static_cast<size_t>(numeric_limits<int>::max())) {
        return unexpected("Text is too long");
    }

    hb_buffer_clear_contents(hb_buffer.get());
    hb_buffer_add_utf8(
        hb_buffer.get(),
        text.data(),
        static_cast<int>(text.size()),
        0,
        static_cast<int>(text.size()));
    hb_buffer_guess_segment_properties(hb_buffer.get());
    hb_shape(font.hb_font.get(), hb_buffer.get(), nullptr, 0);

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
            .cluster = infos[index].cluster,
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
    if (bitmap.rows != 0 &&
        bitmap.width > numeric_limits<size_t>::max() / bitmap.rows) {
        return unexpected("Glyph bitmap is too large");
    }

    vector<char> pixels(static_cast<size_t>(bitmap.width) * bitmap.rows);
    if (bitmap.buffer == nullptr) {
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
                    (source[x >> 3U] & mask) != 0 ? 255U : 0U);
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

expected<Glyph, const char*> make_glyph(FontResource& font, uint32_t id) {
    if (FT_Load_Glyph(
            font.face.get(),
            static_cast<FT_UInt>(id),
            FT_LOAD_DEFAULT | FT_LOAD_TARGET_LIGHT |
                FT_LOAD_RENDER | FT_LOAD_COLOR) != 0) {
        return unexpected("Failed to rasterize glyph");
    }

    const FT_Bitmap& bitmap = font.face->glyph->bitmap;
    auto pixels = copy_bitmap(bitmap);
    if (!pixels) {
        return unexpected(pixels.error());
    }

    return Glyph{
        .width = static_cast<int>(bitmap.width),
        .height = static_cast<int>(bitmap.rows),
        .left = font.face->glyph->bitmap_left,
        .top = font.face->glyph->bitmap_top,
        .pixels = move(*pixels),
    };
}

expected<const Glyph*, const char*> rasterize(
    FontResource& font,
    uint32_t id,
    bool cache,
    vector<Glyph>& temporary_glyphs) {
    const GlyphKey key{
        .id = id,
        .size = static_cast<uint32_t>(font.current_size),
    };

    if (const auto cached = font.glyph_cache.find(key);
        cached != font.glyph_cache.end()) {
        return &cached->second;
    }

    auto glyph = make_glyph(font, id);
    if (!glyph) {
        return unexpected(glyph.error());
    }

    if (cache) {
        auto inserted = font.glyph_cache.emplace(key, move(*glyph));
        return &inserted.first->second;
    }

    temporary_glyphs.push_back(move(*glyph));
    return &temporary_glyphs.back();
}

bool should_cache(
    DisplayWord::GlyphCachePolicy policy,
    string_view text,
    uint32_t cluster) {
    if (policy == DisplayWord::GlyphCachePolicy::All) {
        return true;
    }
    if (policy == DisplayWord::GlyphCachePolicy::None ||
        cluster >= text.size()) {
        return false;
    }
    return static_cast<unsigned char>(text[cluster]) < 0x80U;
}

expected<TextLayout, const char*> layout_text(
    FontResource& font,
    string_view text,
    size_t font_size,
    DisplayWord::GlyphCachePolicy cache_policy) {
    auto size_result = set_font_size(font, font_size);
    if (!size_result) {
        return unexpected(size_result.error());
    }

    auto shaped_result = shape(font, text);
    if (!shaped_result) {
        return unexpected(shaped_result.error());
    }

    TextLayout result;
    result.temporary_glyphs.reserve(shaped_result->size());
    result.positioned.reserve(shaped_result->size());
    result.min_y = font.face->size->metrics.descender / 64.0F;
    result.max_y = font.face->size->metrics.ascender / 64.0F;

    float pen_x{};
    float pen_y{};
    for (const ShapedGlyph& shaped_glyph : *shaped_result) {
        auto glyph_result = rasterize(
            font,
            shaped_glyph.id,
            should_cache(cache_policy, text, shaped_glyph.cluster),
            result.temporary_glyphs);
        if (!glyph_result) {
            return unexpected(glyph_result.error());
        }

        const Glyph* glyph = *glyph_result;
        const float left =
            pen_x + shaped_glyph.offset_x + glyph->left;
        const float top =
            pen_y + shaped_glyph.offset_y + glyph->top;
        result.positioned.push_back({glyph, left, top});

        result.min_x = min(result.min_x, left);
        result.max_x = max(result.max_x, left + glyph->width);
        result.min_y = min(result.min_y, top - glyph->height);
        result.max_y = max(result.max_y, top);
        pen_x += shaped_glyph.advance_x;
        pen_y += shaped_glyph.advance_y;
    }

    result.min_x = min(result.min_x, pen_x);
    result.max_x = max(result.max_x, pen_x);
    return result;
}

void blit_layout(
    const TextLayout& layout,
    vector<char>& output,
    size_t width,
    size_t height,
    float origin_x,
    float top_reference) {
    for (const PositionedGlyph& item : layout.positioned) {
        const int destination_x =
            static_cast<int>(lround(origin_x + item.left));
        const int destination_y =
            static_cast<int>(lround(top_reference - item.top));

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
}

bool valid_texture_size(size_t width, size_t height) {
    return width != 0 && height != 0 &&
        width <= static_cast<size_t>(numeric_limits<int>::max()) &&
        height <= static_cast<size_t>(numeric_limits<int>::max()) &&
        width <= numeric_limits<size_t>::max() / height;
}

} // namespace

expected<void, const char*> DisplayWord::init() {
    shutdown();

    FT_Library raw_library{};
    if (FT_Init_FreeType(&raw_library) != 0) {
        return unexpected("Failed to initialize FreeType");
    }
    library.reset(raw_library);

    hb_buffer_t* raw_buffer = hb_buffer_create();
    if (raw_buffer == nullptr || !hb_buffer_allocation_successful(raw_buffer)) {
        if (raw_buffer != nullptr) {
            hb_buffer_destroy(raw_buffer);
        }
        shutdown();
        return unexpected("Failed to create HarfBuzz buffer");
    }
    hb_buffer.reset(raw_buffer);

    auto font = load_font(default_font_path);
    if (!font) {
        shutdown();
        return unexpected(font.error());
    }
    default_font_id = *font;
    return {};
}

void DisplayWord::shutdown() {
    default_font_id = {};
    free_font_slots.clear();
    font_slots.clear();
    hb_buffer.reset();
    library.reset();
}

expected<DisplayWord::FontId, const char*> DisplayWord::load_font(
    string_view path) {
    if (!library || path.empty()) {
        return unexpected("Text engine is not ready");
    }

    const string owned_path(path);
    FT_Face raw_face{};
    if (FT_New_Face(library.get(), owned_path.c_str(), 0, &raw_face) != 0) {
        return unexpected("Failed to load font");
    }

    FontResource resource;
    resource.face.reset(raw_face);
    hb_font_t* raw_font = hb_ft_font_create_referenced(raw_face);
    if (raw_font == nullptr) {
        return unexpected("Failed to create HarfBuzz font");
    }
    resource.hb_font.reset(raw_font);

    uint32_t index{};
    if (!free_font_slots.empty()) {
        index = free_font_slots.back();
        free_font_slots.pop_back();
    }
    else {
        if (font_slots.size() >= numeric_limits<uint32_t>::max()) {
            return unexpected("Too many loaded fonts");
        }
        index = static_cast<uint32_t>(font_slots.size());
        font_slots.emplace_back();
    }

    FontSlot& slot = font_slots[index];
    slot.resource = move(resource);
    slot.occupied = true;
    return FontId{index, slot.generation};
}

expected<void, const char*> DisplayWord::unload_font(FontId font) {
    if (font == default_font_id) {
        return unexpected("The default font cannot be unloaded");
    }

    auto resource = font_for(font);
    if (!resource) {
        return unexpected(resource.error());
    }

    FontSlot& slot = font_slots[font.index];
    slot.resource = {};
    slot.occupied = false;
    slot.generation = next_generation(slot.generation);
    free_font_slots.push_back(font.index);
    return {};
}

DisplayWord::FontId DisplayWord::default_font() {
    return default_font_id;
}

expected<vector<char>, const char*> DisplayWord::render_text(
    FontId font_id,
    string_view text,
    size_t font_size,
    size_t width,
    size_t height,
    float horizontal_alignment,
    float vertical_alignment,
    GlyphCachePolicy cache_policy) {
    if (text.empty() || !library || !hb_buffer) {
        return unexpected("Text engine is not ready");
    }
    if (!valid_texture_size(width, height)) {
        return unexpected("Invalid text texture size");
    }

    auto font_result = font_for(font_id);
    if (!font_result) {
        return unexpected(font_result.error());
    }
    auto layout = layout_text(**font_result, text, font_size, cache_policy);
    if (!layout) {
        return unexpected(layout.error());
    }

    vector<char> output(width * height);
    horizontal_alignment = clamp(horizontal_alignment, 0.0F, 1.0F);
    vertical_alignment = clamp(vertical_alignment, 0.0F, 1.0F);
    const float content_width = layout->max_x - layout->min_x;
    const float content_height = layout->max_y - layout->min_y;
    const float origin_x =
        (static_cast<float>(width) - content_width) * horizontal_alignment -
        layout->min_x;
    const float top_reference =
        (static_cast<float>(height) - content_height) * vertical_alignment +
        layout->max_y;
    blit_layout(*layout, output, width, height, origin_x, top_reference);
    return output;
}

expected<DisplayWord::TextBitmap, const char*>
DisplayWord::render_text_tight(
    FontId font_id,
    string_view text,
    size_t font_size,
    GlyphCachePolicy cache_policy) {
    if (text.empty() || !library || !hb_buffer) {
        return unexpected("Text engine is not ready");
    }

    auto font_result = font_for(font_id);
    if (!font_result) {
        return unexpected(font_result.error());
    }
    auto layout = layout_text(**font_result, text, font_size, cache_policy);
    if (!layout) {
        return unexpected(layout.error());
    }

    const double left = floor(static_cast<double>(layout->min_x));
    const double right = ceil(static_cast<double>(layout->max_x));
    const double bottom = floor(static_cast<double>(layout->min_y));
    const double top = ceil(static_cast<double>(layout->max_y));
    const double width_value = max(1.0, right - left);
    const double height_value = max(1.0, top - bottom);
    if (!isfinite(width_value) || !isfinite(height_value) ||
        width_value > static_cast<double>(numeric_limits<int>::max()) ||
        height_value > static_cast<double>(numeric_limits<int>::max())) {
        return unexpected("Text bounds are too large");
    }

    TextBitmap result{
        .pixels = {},
        .width = static_cast<size_t>(width_value),
        .height = static_cast<size_t>(height_value),
    };
    if (!valid_texture_size(result.width, result.height)) {
        return unexpected("Invalid text texture size");
    }
    result.pixels.resize(result.width * result.height);
    blit_layout(
        *layout,
        result.pixels,
        result.width,
        result.height,
        static_cast<float>(-left),
        static_cast<float>(top));
    return result;
}

size_t DisplayWord::cache_size() {
    size_t result{};
    for (const FontSlot& slot : font_slots) {
        if (slot.occupied) {
            result += slot.resource.glyph_cache.size();
        }
    }
    return result;
}

size_t DisplayWord::cache_size(FontId font) {
    auto resource = font_for(font);
    if (!resource) {
        return 0;
    }
    return (*resource)->glyph_cache.size();
}
