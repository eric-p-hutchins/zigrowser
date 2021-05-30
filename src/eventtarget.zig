const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const StringToListenerMap = std.StringHashMap(*ArrayList(*EventListener));

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const EventListener = @import("eventlistener.zig").EventListener;
const Event = @import("event.zig").Event;

const EventTarget = @This();

const AddEventListenerOptions = struct {
    capture: bool = false,
    once: bool = false,
    passive: bool = false,
};

pub fn init(allocator: *Allocator) !EventTarget {
    return EventTarget{
        .allocator = allocator,
        .listeners = StringToListenerMap.init(testing.allocator),
    };
}

pub fn addEventListener(self: *EventTarget, eventType: []const u8, listener: *EventListener, options: ?AddEventListenerOptions, useCapture: ?bool) !void {
    var possibleListeners: ?*ArrayList(*EventListener) = self.listeners.get("sample");
    if (possibleListeners == null) {
        const listenerList = try self.allocator.create(ArrayList(*EventListener));
        listenerList.* = ArrayList(*EventListener).init(self.allocator);
        try self.listeners.put(eventType, listenerList);
    }
    const listeners: *ArrayList(*EventListener) = self.listeners.get(eventType).?;
    try listeners.append(listener);
}

pub fn removeEventListener(self: *EventTarget, eventType: []const u8, listener: *EventListener, capture: bool) !void {}

pub fn dispatchEvent(self: *EventTarget, event: *const Event) !bool {
    if (self.listeners.get(event.type)) |listeners| {
        for (listeners.items) |listener| {
            try listener.handleEvent(listener, event);
        }
    }
    return !event.defaultPrevented;
}

pub fn deinit(self: *EventTarget) void {
    var iterator = self.listeners.iterator();
    var item = iterator.next();
    while (item != null) {
        item.?.value.deinit();
        self.allocator.destroy(item.?.value);
        item = iterator.next();
    }
    self.listeners.deinit();
}

allocator: *Allocator,
listeners: StringToListenerMap,

test "Event Listener Test" {
    var eventTarget: EventTarget = try EventTarget.init(testing.allocator);
    defer eventTarget.deinit();

    var value: i32 = 1;

    // Create an event listener that sets the value of the variable to 5
    const CustomEventListener = struct {
        valuePtr: *i32,
        eventListener: EventListener,

        const This = @This();

        pub fn init(valuePtr: *i32) This {
            return This{
                .valuePtr = valuePtr,
                .eventListener = EventListener{ .handleEvent = This.handleEvent },
            };
        }

        fn handleEvent(eventListener: *EventListener, event: *const Event) anyerror!void {
            const self: *This = @fieldParentPtr(This, "eventListener", eventListener);
            self.valuePtr.* = 5;
        }
    };

    // Initialize it
    var customEventListener = CustomEventListener.init(&value);

    // Add the event listener
    try eventTarget.addEventListener("sample", &customEventListener.eventListener, AddEventListenerOptions{}, false);

    // Dispatch an event of the correct type
    const mySampleEvent = Event{ .type = "sample" };
    const dispatchResult = try eventTarget.dispatchEvent(&mySampleEvent);

    // The value is now 5
    expectEqual(@intCast(i32, 5), value);
}
