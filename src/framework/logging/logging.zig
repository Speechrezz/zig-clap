const std = @import("std");
const builtin = @import("builtin");

const windows = if (builtin.target.os.tag == .windows) struct {
    extern "kernel32" fn OutputDebugStringA(
        str: [*:0]const u8,
    ) callconv(.winapi) void;
} else struct {};

pub fn debugPrint(comptime fmt: []const u8, args: anytype) void {
    if (builtin.optimize == .fast or builtin.optimize == .small) return;

    if (builtin.target.os.tag == .windows and builtin.output_mode == .Lib) {
        var buffer: [4096]u8 = undefined;

        const message = std.fmt.bufPrintSentinel(&buffer, fmt, args, 0) catch return;
        windows.OutputDebugStringA(message.ptr);
    } else {
        std.debug.print(fmt, args);
    }
}
