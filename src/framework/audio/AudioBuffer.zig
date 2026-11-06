const std = @import("std");
const audio = @import("audio.zig");
const AudioSlice = @import("AudioSlice.zig");

buffer: std.ArrayList(f32) = .empty,
channels: std.ArrayList([*]f32) = .empty,
num_samples: usize = 0,

pub const empty: @This() = .{};

pub fn init(self: *@This()) void {
    self.* = .{};
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.buffer.deinit(allocator);
    self.channels.deinit(allocator);
}

pub fn resize(self: *@This(), allocator: std.mem.Allocator, num_channels: usize, num_samples: usize) !void {
    self.num_samples = num_samples;
    try self.buffer.resize(allocator, num_channels * num_samples);
    try self.channels.resize(allocator, num_channels);

    for (0..num_channels) |channel_index| {
        const index_start = channel_index * num_samples;
        self.channels.items[channel_index] = self.buffer.items[index_start..].ptr;
    }
}

pub fn getChannel(self: @This(), channel_index: usize) []f32 {
    return self.channels.items[channel_index][0..self.num_samples];
}

pub fn getNumSamples(self: @This()) usize {
    return self.num_samples;
}

pub fn getNumChannels(self: @This()) usize {
    return self.channels.items.len;
}

pub fn createSlice(self: @This()) AudioSlice {
    return .{
        .channels = self.channels.items,
        .num_samples = self.num_samples,
    };
}

pub fn createSliceWithLength(self: @This(), num_samples: usize) AudioSlice {
    std.debug.assert(num_samples <= self.num_samples);

    return .{
        .channels = self.channels.items,
        .num_samples = num_samples,
    };
}

pub fn fill(self: *@This(), value: f32) void {
    for (self.buffer.items) |*sample| {
        sample.* = value;
    }
}

pub fn clear(self: *@This()) void {
    self.fill(0.0);
}
