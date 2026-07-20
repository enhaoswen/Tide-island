#pragma once

#include <algorithm>
#include <array>
#include <format>
#include <print>
#include <string>
#include <string_view>
#include <utility>
#include <expected>

// ============================================================================
// Tide Island logging helpers
// ============================================================================
//
// This header keeps logging lightweight: regular messages are one-line logs,
// while frame_logger prints a bordered block for user-facing diagnostics.
//

namespace Log {

enum LogLevel : char {
    Error,
    Warning,
    Debug
};

} // namespace Log

// ============================================================================
// [Internal Details]
// ============================================================================

namespace {

inline constexpr auto RESET  = "\033[0m";
inline constexpr auto GREEN  = "\033[32m";
inline constexpr auto RED    = "\033[31m";
inline constexpr auto GRAY   = "\033[90m";
inline constexpr auto YELLOW = "\033[33m";

#if defined(_DEBUG) || !defined(NDEBUG)
    inline constexpr bool is_debug_mode = true;
#else
    inline constexpr bool is_debug_mode = false;
#endif

} // namespace

// ============================================================================
// [Public API Implementation]
// ============================================================================

namespace Log {

inline void logger(LogLevel level, std::string_view msg) {
    if (level == LogLevel::Error) {
        std::println(stderr, "{}[ERROR]{} {}", RED, RESET, msg);
    }
    else if (level == LogLevel::Debug) {
        if constexpr (is_debug_mode) std::println("{}[DEBUG]{} {}", GRAY, RESET, msg);
    }
    else if (level == LogLevel::Warning) {
        std::println(stderr, "{}[WARNING]{} {}", YELLOW, RESET, msg);
    }
}

template<typename... Args>
inline void logger(LogLevel level, std::format_string<Args...> fmt, Args&&... args) {
    logger(level, std::format(fmt, std::forward<Args>(args)...));
}

template <typename... Args>
inline void frame_logger(LogLevel level, Args&&... args) {
    if (!is_debug_mode && (level == LogLevel::Debug)) return;
    if constexpr (sizeof...(Args) == 0) return;

    std::array<std::string_view, sizeof...(Args)> msgs{
        std::string_view{std::forward<Args>(args)}...
    };

    size_t msg_len = 0;
    size_t total_lines = 0;
    for (const auto& s : msgs) {
        if (s.size() > msg_len) msg_len = s.size();
        total_lines += s.empty() ? 1 : (s.size() + 79) / 80;
    }
    msg_len = std::min<size_t>(msg_len, 80);

    size_t border_bytes = 3 + (msg_len + 2) * 3 + 4;
    size_t content_bytes = total_lines * (4 + msg_len + 5);
    
    std::string out_msg;
    out_msg.reserve(border_bytes * 2 + content_bytes);

    out_msg += "┌";
    for (size_t i = 0; i < msg_len + 2; ++i) out_msg += "─";
    out_msg += "┐\n";

    for (std::string_view s : msgs) {
        size_t handled_char = 0;
        while (s.size() - handled_char > 80) {
            out_msg += std::format("│ {:<{}} │\n", s.substr(handled_char, 80), msg_len);
            handled_char += 80;
        }
        out_msg += std::format("│ {:<{}} │\n", s.substr(handled_char), msg_len);
    }

    out_msg += "└";
    for (size_t i = 0; i < msg_len + 2; ++i) out_msg += "─";
    out_msg += "┘\n";

    print("{}", out_msg);
}

template <typename return_type>
return_type check(std::expected<return_type, const char*> result) {
    if (!result.has_value()) {
        logger(Log::Error, result.error());
        std::terminate();
    }
    return result.value();
}

} // namespace Log
