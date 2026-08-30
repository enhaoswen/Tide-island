//    #define STB_RECT_PACK_IMPLEMENTATION

#include "text.hpp"
#include "log.hpp"

#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb.h>
#include <hb-ft.h>
#include <string_view>

using namespace std;

/*
============ cheat sheet ============
struct hb_glyph_info_t:
    hb_codepoint_t code_point
    uint32_t cluster


struct hb_glyph_position_t:
    hb_pos_t x&y_advance
    hb_pos_t x&y_offset


struct ft_face->glyph->bitmap:
    uint rows
    uint width
    int pitch
    uchar* buffer
    short num_gray
    char pixel_mode
*/

namespace {

FT_Library ft_library{};
FT_Face ft_face{};
hb_font_t* hb_font{};

hb_buffer_t* shape(string_view text) {
    hb_buffer_t* buffer = hb_buffer_create();

    hb_buffer_add_utf8(
        buffer,
        text.data(),
        static_cast<int>(text.size()),
        0,
        static_cast<int>(text.size())
    );

    hb_buffer_guess_segment_properties(buffer);
    hb_shape(hb_font, buffer, nullptr, 0);

    return buffer;
}

void load_glyph(hb_buffer_t* buffer){
    unsigned glyph_count = 0;

    hb_glyph_info_t* infos = hb_buffer_get_glyph_infos(buffer, &glyph_count);


    hb_glyph_position_t* positions = hb_buffer_get_glyph_positions(buffer, &glyph_count);


    for (unsigned i = 0; i < glyph_count; ++i) {
        FT_Load_Glyph(ft_face, infos[i].codepoint ,FT_LOAD_DEFAULT);
        FT_Render_Glyph(ft_face->glyph, FT_RENDER_MODE_NORMAL);

        FT_Bitmap& bitmap = ft_face->glyph->bitmap;
    }

}

void destroy_buffer(hb_buffer_t* buffer) {
    hb_buffer_destroy(buffer);
}

}// namespace

void Text::init() {
    if (FT_Init_FreeType(&ft_library)) {
        Log::fatal("Failed to initialize FreeType");
    }

    if (FT_New_Face(
        ft_library,
        "/usr/share/fonts/inter/Inter.ttc",
        0,
        &ft_face
    )) {
        Log::fatal("Failed to load font");
    }

    if (FT_Set_Pixel_Sizes(ft_face, 0, 18)) {
        Log::fatal("Failed to set font size");
    }

    hb_font = hb_ft_font_create_referenced(ft_face);

    if (!hb_font) {
        Log::fatal("Failed to initialize HarfBuzz font");
    }

    Log::logger(
        Log::Debug,
        "Loaded font: {} {}",
        ft_face->family_name,
        ft_face->style_name
    );
}

void Text::draw(string_view text){
    hb_buffer_t* buffer = shape(text);

    destroy_buffer(buffer);
}