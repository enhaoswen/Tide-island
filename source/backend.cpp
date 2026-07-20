#include "backend.hpp"
#include "wayland.hpp"
#include "log.hpp"
#include "renderer.hpp"
#include "island.hpp"

#include <cerrno>
#include <chrono>
#include <ctime>
#include <queue>
#include <poll.h>
#include <sys/timerfd.h>
#include <unistd.h>

using namespace std;
using namespace std::chrono;

namespace {

int timer_fd{-1};

struct LaterDeadline {
    bool operator()(
        const Backend::Timer& left,
        const Backend::Timer& right
    ) const noexcept {
        return left.deadline > right.deadline;
    }
};

expected<void, const char*> set_timer_at(steady_clock::time_point deadline) {
    const duration since_epoch = deadline.time_since_epoch();
    const duration seconds_part = duration_cast<seconds>(since_epoch);
    const auto nanoseconds_part = duration_cast<nanoseconds>(since_epoch - seconds_part);
    itimerspec spec{};

    spec.it_value.tv_sec = static_cast<time_t>(seconds_part.count());

    spec.it_value.tv_nsec =
        static_cast<long>(nanoseconds_part.count());

    if (timerfd_settime(
        timer_fd,
        TFD_TIMER_ABSTIME,
        &spec,
        nullptr
    ) == -1) {
        return unexpected("timerfd_settime failed");
    }
    return {};
}

priority_queue<Backend::Timer, vector<Backend::Timer>, LaterDeadline> timer_queue;

expected<void, const char*> handle_err(pollfd* fds) {
    const short wayland_events = fds[0].revents;

    if (wayland_events & POLLNVAL) {
        return std::unexpected("Wayland fd is invalid");
    }

    if (wayland_events & POLLHUP) {
        return std::unexpected("Wayland compositor disconnected");
    }

    if (wayland_events & POLLERR) {
        return std::unexpected("Wayland fd reported an I/O error");
    }

    const short timer_events = fds[1].revents;

    if (timer_events & POLLNVAL) {
        return std::unexpected("timerfd is invalid");
    }

    if (timer_events & POLLHUP) {
        return std::unexpected("timerfd was closed");
    }

    if (timer_events & POLLERR) {
        return std::unexpected("timerfd reported an I/O error");
    }

    return {};
}

void clock_callback() {
    const auto now = system_clock::now();
    const auto next_minute = floor<minutes>(now) + minutes{1};

    const auto duration = duration_cast<milliseconds>(next_minute - now);
    Log::check(Backend::push(duration, clock_callback));
    Log::check(Renderer::frame());
}

} // namespace

expected<void, const char*> Backend::push(
    milliseconds duration,
    void (*callback)()
) {
    if (timer_fd == -1) {
        return unexpected("Backend is not initialized");
    }
    if (!callback) {
        return unexpected("Timer callback is null");
    }

    const steady_clock::time_point next_deadline = steady_clock::now() + duration;
    const bool becomes_earliest = timer_queue.empty() || next_deadline < timer_queue.top().deadline;

    if (becomes_earliest) {
        auto result = set_timer_at(next_deadline);
        if (!result) {
            return unexpected(result.error());
        }
    }

    timer_queue.push({next_deadline, callback});
    return {};
}

void Backend::pop() {
    if (!timer_queue.empty()) {
        Timer timer = timer_queue.top();
        timer_queue.pop();
        if (timer.callback) {
            timer.callback();
        }
    }
}

expected<Backend::Timer, const char*> Backend::top() {
    if (!timer_queue.empty()) {
        return timer_queue.top();
    }
    return unexpected("Timer queue is empty");
}

expected<void, const char*> Backend::init() {
    timer_fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC);

    if (timer_fd == -1) {
        return unexpected("timerfd_create failed\n");
    }

    auto result = push(milliseconds{0}, clock_callback);
    if (!result) {
        close(timer_fd);
        timer_fd = -1;
        return unexpected(result.error());
    }

    return {};
}

std::expected<void, const char*> Backend::run() {
    if (timer_fd == -1) {
        return std::unexpected("Backend is not initialized");
    }

    int wayland_fd = Log::check(Wayland::get_fd());

    pollfd fds[] = {
        {
            .fd = wayland_fd,
            .events = POLLIN,
            .revents = 0,
        },
        {
            .fd = timer_fd,
            .events = POLLIN,
            .revents = 0,
        },
    };

    while (Island::state().is_running) {
        const int ready_count = poll(fds, 2, -1);

        if (ready_count == -1) {
            if (errno == EINTR) {
                continue;
            }
            return std::unexpected("poll failed");
        }

        expected<void, const char*> err_result = handle_err(fds);

        if (!err_result) {
            return unexpected(err_result.error());
        }

        if (fds[0].revents & POLLIN) {
            auto result = Wayland::dispatch_events();

            if (!result) {
                return std::unexpected(result.error());
            }
        }

        if (fds[1].revents & POLLIN) {
            auto result = Backend::handle_timerfd();
            if (!result) {
                return unexpected(result.error());
            }
        }
    }

    return {};
}

expected<void, const char*> Backend::handle_timerfd() {

    uint64_t expiration_count{};

    const ssize_t result = read(
        timer_fd,
        &expiration_count,
        sizeof(expiration_count)
    );

    if (result != sizeof(expiration_count)) {
        return unexpected("timerfd read failed");
    }

    const auto now = steady_clock::now();

    while (!timer_queue.empty() && timer_queue.top().deadline <= now) {
        pop();
    }

    if (!timer_queue.empty()) {
        auto arm_result = set_timer_at(timer_queue.top().deadline);
        if (!arm_result) {
            return unexpected(arm_result.error());
        }
    }

    return {};
}
