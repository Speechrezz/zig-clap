const std = @import("std");
const interp = @import("interpolation.zig");

pub fn LinearRange(comptime T: type) type {
    return struct {
        lower: T,
        upper: T,

        pub fn toNormalized(self: *const @This(), value: T) T {
            return interp.invLerp(self.lower, self.upper, value);
        }

        pub fn fromNormalized(self: *const @This(), norm: T) T {
            return interp.lerp(self.lower, self.upper, norm);
        }
    };
}
