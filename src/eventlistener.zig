const Event = @import("event.zig").Event;

pub const EventListener = struct {
    handleEvent: fn (self: *EventListener, event: *const Event) anyerror!void,
};
