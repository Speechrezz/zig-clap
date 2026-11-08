const std = @import("std");
const AudioParameter = @import("AudioParameter.zig");
const state = @import("../state/state.zig");

params: std.ArrayList(AudioParameter) = .empty,
ordered: std.ArrayList(u32) = .empty,

pub fn init() @This() {
    return .{};
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.params.deinit(allocator);
    self.ordered.deinit(allocator);
}

/// Add a parameter
pub fn add(self: *@This(), allocator: std.mem.Allocator, param: AudioParameter) !*AudioParameter {
    try self.params.append(allocator, param);
    return self.params.lastPtr().?;
}

/// Call after all parameters have been added
pub fn finalize(self: *@This(), allocator: std.mem.Allocator) !void {
    // TODO: Order based on version number

    try self.ordered.resize(allocator, self.params.items.len);
    for (0..self.params.items.len) |i| {
        const id: u32 = @intCast(i);
        self.params.items[i].id = id;
        self.ordered.items[i] = id;
    }
}

pub fn getCount(self: *const @This()) u64 {
    return self.params.items.len;
}

pub fn get(self: *const @This(), id: u32) *AudioParameter {
    std.debug.assert(self.ordered.items.len > 0); // Call `finalize`
    std.debug.assert(id < self.ordered.items.len); // Invalid ID

    const index = self.ordered.items[id];
    return &self.params.items[index];
}

pub fn getChecked(self: *const @This(), id: u32) ?*AudioParameter {
    std.debug.assert(self.ordered.items.len > 0); // Call `finalize`

    if (id >= self.ordered.items.len) return null;

    const index = self.ordered.items[id];
    return &self.params.items[index];
}

pub fn saveState(self: *const @This(), allocator: std.mem.Allocator, stream: *state.BinaryStreamOut) !void {
    for (self.ordered.items) |index| {
        const param = &self.params.items[index];
        try stream.appendValue(allocator, param.getValue());
    }
}

pub fn loadState(self: *@This(), stream: *state.BinaryStreamIn) void {
    for (self.ordered.items) |index| {
        const param = &self.params.items[index];
        param.setValue(stream.readValue(f64));
    }
}

test {
    const allocator = std.testing.allocator;

    var params: @This() = .init();
    defer params.deinit(allocator);

    const param = try params.add(allocator, .init(
        0,
        "Volume",
        0.0,
        1.0,
        0.5,
    ));

    try params.finalize(allocator);

    try std.testing.expectEqual(1, params.getCount());
    try std.testing.expectEqual(param, params.get(0));
    try std.testing.expectEqual(null, params.getChecked(1));
}
