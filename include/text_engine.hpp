#pragma once

#include <cstddef>
#include <cstdint>
#include <expected>
#include <string>
#include <string_view>
#include <vector>

// ============================================================================
// Tide Island text engine API
// ============================================================================
//
// The text engine initializes FreeType and HarfBuzz state for later shaping and
// glyph rasterization work.
//
namespace DisplayWord {

struct FontId {
    std::uint32_t index{};
    std::uint32_t generation{};

    bool operator==(const FontId&) const = default;
};

enum class GlyphCachePolicy : char {
    None,
    Ascii,
    All,
};

struct TextBitmap {
    std::vector<char> pixels;
    std::size_t width{};
    std::size_t height{};
};

std::expected<void, const char*> init();
void shutdown();

std::expected<FontId, const char*> load_font(std::string_view path);
std::expected<void, const char*> unload_font(FontId font);
FontId default_font();

std::expected<std::vector<char>, const char*> render_text(
    FontId font,
    std::string_view text,
    std::size_t font_size,
    std::size_t width,
    std::size_t height,
    float horizontal_alignment,
    float vertical_alignment,
    GlyphCachePolicy cache_policy = GlyphCachePolicy::Ascii);

std::expected<TextBitmap, const char*> render_text_tight(
    FontId font,
    std::string_view text,
    std::size_t font_size,
    GlyphCachePolicy cache_policy = GlyphCachePolicy::Ascii);

std::size_t cache_size();
std::size_t cache_size(FontId font);

} // namespace DisplayWord
