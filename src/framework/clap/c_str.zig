const std = @import("std");

// Returns `true` if the two C-Strings are equal
pub fn isEql(lhs: [*:0]const u8, rhs: [*:0]const u8) bool {
    return std.mem.orderZ(u8, lhs, rhs) == .eq;
}
