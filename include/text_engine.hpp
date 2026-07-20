#pragma once

#include <cstddef>
#include <expected>
#include <vector>
#include <string_view>

// ============================================================================
// Tide Island text engine API
// ============================================================================
//
// The text engine initializes FreeType and HarfBuzz state for later shaping and
// glyph rasterization work.
//
namespace DisplayWord {

std::expected<void, const char*> init();
std::expected<std::vector<char>, const char*> render_text(
    std::string_view text,
    std::size_t font_size,
    std::size_t width,
    std::size_t height,
    float horizontal_alignment,
    float vertical_alignment);

std::size_t cache_size();

} // namespace DisplayWord
