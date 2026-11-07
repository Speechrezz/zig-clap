const std = @import("std");
const c = @import("c");

fn dummyInputEventsSize(_: [*c]const c.clap_input_events_t) callconv(.c) u32 {
    return 0;
}

pub fn initDummyInputEvents() [*c]const c.clap_input_events_t {
    return &.{
        .ctx = null,
        .size = dummyInputEventsSize,
        .get = null,
    };
}
