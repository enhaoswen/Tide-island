#include "timer.hpp"
#include "wayland.hpp"
#include "log.hpp"
#include "struct.hpp"

#include <chrono>
#include <cstring>
#include <queue>
#include <poll.h>
#include <sys/timerfd.h>
#include <unistd.h>

using namespace std;
using namespace std::chrono;

namespace {

int timer_fd{-1};
int wayland_fd{-1};

struct LaterDeadline {
    bool operator()(
        const Event& left,
        const Event& right
    ) const noexcept {
        return left.deadline > right.deadline;
    }
};

priority_queue<Event, vector<Event>, LaterDeadline> timer_queue;

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

void pop() {
    if (timer_queue.empty()) {
        Log::fatal("Timer queue is empty");
    }

    Event timer = timer_queue.top();

    if (timer.callback) {
        timer.callback();
    }
    timer_queue.pop();
}

} // namespace

void Timer::push(
    microseconds duration,
    void (*callback)()
) {
    if (timer_fd == -1) {
        Log::fatal("Timer is not initialized");
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

void Timer::init() {
    timer_fd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC);

    if (timer_fd == -1) {
        Log::fatal("timerfd_create failed");
    }

    wayland_fd = Wayland::get_wayland_fd();

    if (wayland_fd == -1) {
        Log::fatal("Failed to get Wayland file descriptor");
    }
}

int Timer::get_timer_fd() {
    return timer_fd;
}

void Timer::handle_events() {

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

void Timer::wait() {
    short wayland_events = Wayland::prepare_events();

    pollfd fds[] = {
        {
            .fd = wayland_fd,
            .events = wayland_events,
            .revents = 0,
        },
        {
            .fd = timer_fd,
            .events = POLLIN,
            .revents = 0,
        },
    };

    int result{};

    do {
        result = poll(fds, 2, -1);
    } while (result == -1 && errno == EINTR);

    if (result == -1) {
        Wayland::cancel_events();
        Log::fatal("poll failed: {}", strerror(errno));
    }

    Wayland::handle_events(fds[0].revents);

    if (fds[1].revents & (POLLERR | POLLHUP | POLLNVAL)) {
        Log::fatal(
            "Timer fd poll error: {}",
            fds[1].revents
        );
    }

    if (fds[1].revents & POLLIN) {
        handle_events();
    }
}
