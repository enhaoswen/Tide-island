#include "backend.hpp"
#include "animation.hpp"
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

void set_timer_at(steady_clock::time_point deadline) {
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
        Log::fatal("timerfd_settime failed");
    }
}

priority_queue<Backend::Timer, vector<Backend::Timer>, LaterDeadline> timer_queue;

void handle_err(pollfd* fds) {
    short error_events = POLLNVAL | POLLHUP | POLLERR;

    bool has_error =
        ((fds[0].revents | fds[1].revents) & error_events) != 0;

    if (!has_error) {
        return;
    }

    Wayland::cancel_poll();

    const short wayland_events = fds[0].revents;

    if ((wayland_events & POLLNVAL) != 0) {
        Log::fatal("Wayland fd is invalid");
    }

    if ((wayland_events & POLLHUP) != 0) {
        Log::fatal("Wayland compositor disconnected");
    }

    if ((wayland_events & POLLERR) != 0) {
        Log::fatal("Wayland fd reported an I/O error");
    }

    short timer_events = fds[1].revents;

    if ((timer_events & POLLNVAL) != 0) {
        Log::fatal("timerfd is invalid");
    }

    if ((timer_events & POLLHUP) != 0) {
        Log::fatal("timerfd was closed");
    }

    if ((timer_events & POLLERR) != 0) {
        Log::fatal("timerfd reported an I/O error");
    }
}

void clock_callback() {
    const auto now = system_clock::now();
    const auto next_minute = floor<minutes>(now) + minutes{1};

    const auto duration = duration_cast<microseconds>(next_minute - now);
    Backend::push(duration, clock_callback);
    Renderer::frame();
}

} // namespace

void Backend::push(
    microseconds duration,
    void (*callback)()
) {
    if (timer_fd == -1) {
        Log::fatal("Backend is not initialized");
    }
    if (!callback) {
        Log::fatal("Timer callback is null");
    }

    const steady_clock::time_point next_deadline = steady_clock::now() + duration;
    const bool becomes_earliest = timer_queue.empty() || next_deadline < timer_queue.top().deadline;

    if (becomes_earliest) {
        set_timer_at(next_deadline);
    }

    timer_queue.push({next_deadline, callback});
}

void Backend::pop() {
    if (timer_queue.empty()) {
        Log::fatal("Timer queue is empty");
    }

    Timer timer = timer_queue.top();
    timer_queue.pop();
    if (timer.callback) {
        timer.callback();
    }
}

Backend::Timer Backend::top() {
    if (!timer_queue.empty()) {
        return timer_queue.top();
    }
    Log::fatal("Timer queue is empty");
}

void Backend::init() {
    timer_fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC);

    if (timer_fd == -1) {
        Log::fatal("timerfd_create failed");
    }

    push(microseconds{0}, clock_callback);
}

void Backend::run() {
    if (timer_fd == -1) {
        Log::fatal("Backend is not initialized");
    }

    const Island::Island* island = Island::state();
    int wayland_fd = Wayland::get_fd();

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

    while (island->is_running) {
        bool wayland_wants_write = Wayland::prepare_poll();
        fds[0].events = static_cast<short>(
            POLLIN | (wayland_wants_write ? POLLOUT : 0)
        );

        if (!island->is_running) {
            Wayland::cancel_poll();
            break;
        }

        int ready_count = poll(fds, 2, -1);

        if (ready_count == -1) {
            Wayland::cancel_poll();

            if (errno == EINTR) {
                continue;
            }
            Log::fatal("poll failed");
        }

        handle_err(fds);

        Wayland::finish_poll(
            (fds[0].revents & POLLIN) != 0,
            (fds[0].revents & POLLOUT) != 0
        );

        if (Wayland::take_frame_ready()) {
            request_redraw();
        }

        if (fds[1].revents & POLLIN) {
            Backend::handle_timerfd();
        }
    }
}

void Backend::request_redraw(){
    Animation::update();
    if (!Animation::no_more_animation()){
        Wayland::request_frame();
    }

    Renderer::frame();
}

void Backend::handle_timerfd() {

    uint64_t expiration_count{};

    const ssize_t result = read(
        timer_fd,
        &expiration_count,
        sizeof(expiration_count)
    );

    if (result != sizeof(expiration_count)) {
        Log::fatal("timerfd read failed");
    }

    const auto now = steady_clock::now();

    while (!timer_queue.empty() && timer_queue.top().deadline <= now) {
        pop();
    }

    if (!timer_queue.empty()) {
        set_timer_at(timer_queue.top().deadline);
    }
}
