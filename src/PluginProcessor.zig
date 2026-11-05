const std = @import("std");
const AudioParameter = @import("AudioParameter.zig");

params: std.ArrayList(AudioParameter) = .empty,

pub fn init(allocator: std.mem.Allocator, _: std.Io) !@This() {
    var proc: @This() = .{};

    try proc.params.append(allocator, .init(
        0,
        "Volume",
        0.0,
        1.0,
        0.5,
    ));

    return proc;
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.params.deinit(allocator);
}
