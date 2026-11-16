const std = @import("std");
const audio = @import("../audio/audio.zig");
const math = @import("../math/math.zig");

const interpolation_padding = 4;

pub fn DelayLine(comptime T: type) type {
    if (@typeInfo(T) != .float) {
        @compileError("Expected a runtime float type");
    }

    return struct {
        buffer: audio.AudioBuffer = .empty,
        write_pos: std.ArrayList(usize) = .empty,

        pub const init: @This() = .{};

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.buffer.deinit(allocator);
            self.write_pos.deinit(allocator);
        }

        pub fn reset(self: *@This()) void {
            std.debug.assert(self.buffer.getNumSamples() > 0);
            std.debug.assert(self.write_pos.items.len > 0);

            self.buffer.fill(0.0);
            @memset(self.write_pos.items, 0);
        }

        pub fn prepare(
            self: *@This(),
            allocator: std.mem.Allocator,
            spec: audio.ProcessSpec,
            max_delay_sec: T,
        ) !void {
            const sample_rate: T = @floatCast(spec.sample_rate);
            var max_delay_samples: usize = @ceil(max_delay_sec * sample_rate);
            max_delay_samples += interpolation_padding;

            try self.buffer.resize(allocator, spec.num_channels, max_delay_samples);
            try self.write_pos.resize(allocator, spec.num_channels);
            self.reset();
        }

        pub fn processSample(self: *@This(), channel_index: usize, sample: T, delay_samples: T) T {
            self.pushBackSample(channel_index, sample);
            return self.readSample(channel_index, delay_samples);
        }

        pub fn readSample(self: *const @This(), channel_index: usize, delay_samples: T) T {
            const buffer_size = self.buffer.getNumSamples();

            std.debug.assert(buffer_size > 0);
            std.debug.assert(delay_samples >= 1.0);
            std.debug.assert(@as(usize, @ceil(delay_samples)) < buffer_size - interpolation_padding);

            const offset = delay_samples - @floor(delay_samples) + 1.0;
            const delay_floor: usize = @floor(delay_samples);

            const latest_index = self.write_pos.items[channel_index] + buffer_size - delay_floor;

            const index1 = (latest_index - 0) % buffer_size;
            const index2 = (latest_index - 1) % buffer_size;
            const index3 = (latest_index - 2) % buffer_size;
            const index4 = (latest_index - 3) % buffer_size;

            return math.interpolation.lagrange(
                self.getSample(channel_index, index1),
                self.getSample(channel_index, index2),
                self.getSample(channel_index, index3),
                self.getSample(channel_index, index4),
                offset,
            );
        }

        pub fn pushBackSample(self: *@This(), channel_index: usize, sample: T) void {
            const write_pos = &self.write_pos.items[channel_index];
            const channel = self.buffer.getChannel(channel_index);

            channel[write_pos.*] = sample;
            write_pos.* = (write_pos.* + 1) % self.buffer.getNumSamples();
        }

        fn getSample(self: *const @This(), channel_index: usize, sample_index: usize) T {
            const channel = self.buffer.getChannel(channel_index);
            return channel[sample_index];
        }
    };
}

test "DelayLine f32" {
    const tolerance = 1e-5;
    const allocator = std.testing.allocator;

    const spec: audio.ProcessSpec = .{
        .block_size = 4,
        .num_channels = 2,
        .sample_rate = 48000.0,
    };

    var delay: DelayLine(f32) = .init;
    defer delay.deinit(allocator);
    try delay.prepare(allocator, spec, 0.002);

    const delay_samples = 1.0;

    {
        const out1 = delay.processSample(0, 1.0, delay_samples);
        try std.testing.expectApproxEqAbs(0.0, out1, tolerance);
        const out2 = delay.processSample(0, 2.0, delay_samples);
        try std.testing.expectApproxEqRel(1.0, out2, tolerance);
        const out3 = delay.processSample(0, 3.0, delay_samples);
        try std.testing.expectApproxEqRel(2.0, out3, tolerance);
        const out4 = delay.processSample(0, 4.0, delay_samples);
        try std.testing.expectApproxEqRel(3.0, out4, tolerance);
    }

    delay.reset();

    {
        const out1 = delay.readSample(0, delay_samples);
        delay.pushBackSample(0, 1.0);
        try std.testing.expectApproxEqAbs(0.0, out1, tolerance);

        const out2 = delay.readSample(0, delay_samples);
        delay.pushBackSample(0, 2.0);
        try std.testing.expectApproxEqAbs(0.0, out2, tolerance);

        const out3 = delay.readSample(0, delay_samples);
        delay.pushBackSample(0, 3.0);
        try std.testing.expectApproxEqRel(1.0, out3, tolerance);
    }
}
