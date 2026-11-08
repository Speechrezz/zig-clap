const std = @import("std");

channels: [][*]f32,
start_sample: usize = 0,
num_samples: usize,

pub fn getChannel(self: @This(), channel_index: usize) []f32 {
    std.debug.assert(channel_index < self.channels.len);
    return self.channels[channel_index][self.start_sample .. self.start_sample + self.num_samples];
}

pub fn getNumChannels(self: @This()) usize {
    return self.channels.len;
}

pub fn getNumSamples(self: @This()) usize {
    return self.num_samples;
}

pub fn createSubSlice(self: @This(), start_sample: usize, num_samples: usize) @This() {
    return .{
        .channels = self.channels,
        .start_sample = start_sample,
        .num_samples = num_samples,
    };
}

pub fn clear(self: @This()) void {
    self.fill(0.0);
}

pub fn fill(self: @This(), value: f32) void {
    for (0..self.getNumChannels()) |channel_index| {
        const channel = self.getChannel(channel_index);
        for (channel) |*sample| {
            sample.* = value;
        }
    }
}

pub fn multiplyBy(self: @This(), value: f32) void {
    for (0..self.getNumChannels()) |channel_index| {
        const channel = self.getChannel(channel_index);
        for (channel) |*sample| {
            sample.* *= value;
        }
    }
}

pub fn multiplyByArray(self: @This(), array: []const f32) void {
    for (0..self.getNumChannels()) |channel_index| {
        const channel = self.getChannel(channel_index);
        for (channel, array) |*sample, other| {
            sample.* *= other;
        }
    }
}

pub fn addFrom(self: @This(), other: @This()) void {
    std.debug.assert(self.getNumSamples() == other.getNumSamples());
    std.debug.assert(self.getNumChannels() == other.getNumChannels());

    for (0..self.getNumChannels()) |channel_index| {
        const channel_self = self.getChannel(channel_index);
        const channel_other = other.getChannel(channel_index);

        for (0..self.getNumSamples()) |i| {
            channel_self[i] += channel_other[i];
        }
    }
}

test "AudioSlice tests" {
    const AudioBuffer = @import("AudioBuffer.zig");
    const allocator = std.testing.allocator;

    const num_channels = 2;
    const block_size = 128;

    var buffer1: AudioBuffer = .empty;
    defer buffer1.deinit(allocator);
    try buffer1.resize(allocator, num_channels, block_size);

    var buffer2: AudioBuffer = .empty;
    defer buffer2.deinit(allocator);
    try buffer2.resize(allocator, num_channels, block_size);

    const slice1 = buffer1.createSlice();
    slice1.fill(1.0);

    for (0..slice1.getNumChannels()) |ch| {
        const channel = slice1.getChannel(ch);
        for (channel) |sample| {
            try std.testing.expect(sample == 1.0);
        }
    }

    const slice2 = buffer2.createSlice();
    slice2.fill(2.0);

    slice1.addFrom(slice2);

    for (0..slice1.getNumChannels()) |ch| {
        const channel = slice1.getChannel(ch);
        for (channel) |sample| {
            try std.testing.expect(sample == 3.0);
        }
    }

    slice1.multiplyBy(2.0);

    for (0..slice1.getNumChannels()) |ch| {
        const channel = slice1.getChannel(ch);
        for (channel) |sample| {
            try std.testing.expect(sample == 6.0);
        }
    }
}
