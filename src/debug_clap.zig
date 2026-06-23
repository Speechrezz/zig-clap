const std = @import("std");
const clap = @import("clap.zig").c;

fn dummyInputEventsSize(_: [*c]const clap.clap_input_events_t) callconv(.c) u32 {
    return 0;
}

pub fn initDummyInputEvents() [*c]const clap.clap_input_events_t {
    return &.{
        .size = dummyInputEventsSize,
    };
}
