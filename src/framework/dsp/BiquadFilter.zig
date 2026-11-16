const std = @import("std");
const audio = @import("../audio/audio.zig");

const ChannelState = [2]f32;
state: std.ArrayList(ChannelState) = .empty,

pub const init: @This() = .{};

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.state.deinit(allocator);
}

pub fn reset(self: *@This()) void {
    for (self.state.items) |*channel| {
        channel.* = .{ 0.0, 0.0 };
    }
}

pub fn prepare(self: *@This(), allocator: std.mem.Allocator, spec: audio.ProcessSpec) !void {
    try self.state.resize(allocator, spec.num_channels);
    self.reset();
}

pub fn process(self: *@This(), audio_view: audio.AudioSlice, coefficients: *const Coefficients) void {
    std.debug.assert(audio_view.num_samples > 0);
    const coef = coefficients.data;

    for (0..audio_view.getNumChannels()) |channel_index| {
        const channel = audio_view.getChannel(channel_index);
        const state = &self.state.items[channel_index];

        for (channel) |*sample| {
            const input = sample.*;
            const output = coef[3] * ((input * coef[0]) + state[0]);
            sample.* = output;

            state[0] = (input * coef[1]) - (output * coef[4]) + state[1];
            state[1] = (input * coef[2]) - (output * coef[5]);
        }
    }
}

pub fn processSample(self: *@This(), channel_index: usize, input: f32, coefficients: *const Coefficients) f32 {
    const coef = coefficients.data;
    const state = &self.state.items[channel_index];

    const output = (input * coef[0]) + state[0];

    state[0] = (input * coef[1]) - (output * coef[4]) + state[1];
    state[1] = (input * coef[2]) - (output * coef[5]);

    return output;
}

pub const Coefficients = struct {
    data: [6]f32,

    pub const invRootTwo = 1.0 / @sqrt(2.0);

    pub fn makeLowPass(sample_rate: f32, frequency: f32, q: f32) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);

        const n = 1.0 / @tan(std.math.pi * frequency / sample_rate);
        const n2 = n * n;
        const inv_q = 1.0 / q;
        const c1 = 1.0 / (1.0 + inv_q * n + n2);

        return .{
            .data = .{
                c1,  c1 * 2.0,              c1,
                1.0, c1 * 2.0 * (1.0 - n2), c1 * (1.0 - inv_q * n + n2),
            },
        };
    }

    pub fn makeHighPass(sample_rate: f32, frequency: f32, q: f32) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);

        const n = @tan(std.math.pi * frequency / sample_rate);
        const n2 = n * n;
        const inv_q = 1.0 / q;
        const c1 = 1.0 / (1.0 + inv_q * n + n2);

        return .{
            .data = .{
                c1,  -2.0 * c1,             c1,
                1.0, 2.0 * c1 * (n2 - 1.0), c1 * (1.0 - inv_q * n + n2),
            },
        };
    }

    pub fn makeBandPass(sample_rate: f32, frequency: f32, q: f32) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);

        const n = 1.0 / @tan(std.math.pi * frequency / sample_rate);
        const n2 = n * n;
        const inv_q = 1.0 / q;
        const c1 = 1.0 / (1.0 + inv_q * n + n2);
        const b0 = c1 * n * inv_q;

        return .{
            .data = .{
                b0,  0.0,                   -b0,
                1.0, 2.0 * c1 * (1.0 - n2), c1 * (1.0 - inv_q * n + n2),
            },
        };
    }

    pub fn makeNotch(sample_rate: f32, frequency: f32, q: f32) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);

        const n = 1.0 / @tan(std.math.pi * frequency / sample_rate);
        const n2 = n * n;
        const inv_q = 1.0 / q;
        const c1 = 1.0 / (1.0 + n * inv_q + n2);
        const b0 = c1 * (1.0 + n2);
        const b1 = 2.0 * c1 * (1.0 - n2);

        return .{
            .data = .{
                b0,  b1, b0,
                1.0, b1, c1 * (1.0 - n * inv_q + n2),
            },
        };
    }

    pub fn makeAllPass(sample_rate: f32, frequency: f32, q: f32) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);

        const n = 1.0 / @tan(std.math.pi * frequency / sample_rate);
        const n2 = n * n;
        const inv_q = 1.0 / q;
        const c1 = 1.0 / (1.0 + inv_q * n + n2);
        const b0 = c1 * (1.0 - n * inv_q + n2);
        const b1 = 2.0 * c1 * (1.0 - n2);

        return .{
            .data = .{
                b0,  b1, 1.0,
                1.0, b1, b0,
            },
        };
    }
    pub fn makeLowShelf(
        sample_rate: f32,
        frequency: f32,
        q: f32,
        gain_factor: f32,
    ) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);
        std.debug.assert(gain_factor > 0.0);

        const a = @sqrt(gain_factor);
        const a_minus_1 = a - 1.0;
        const a_plus_1 = a + 1.0;

        const omega =
            2.0 * std.math.pi * @max(frequency, 2.0) / sample_rate;

        const cos_omega = @cos(omega);
        const beta = @sin(omega) * @sqrt(a) / q;
        const a_minus_1_cos = a_minus_1 * cos_omega;

        const inv_a0 = 1.0 / (a_plus_1 + a_minus_1_cos + beta);

        return .{
            .data = .{
                inv_a0 * a * (a_plus_1 - a_minus_1_cos + beta),
                inv_a0 * a * 2.0 * (a_minus_1 - a_plus_1 * cos_omega),
                inv_a0 * a * (a_plus_1 - a_minus_1_cos - beta),

                1.0,
                inv_a0 * -2.0 * (a_minus_1 + a_plus_1 * cos_omega),
                inv_a0 * (a_plus_1 + a_minus_1_cos - beta),
            },
        };
    }

    pub fn makeHighShelf(
        sample_rate: f32,
        frequency: f32,
        q: f32,
        gain_factor: f32,
    ) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);
        std.debug.assert(gain_factor > 0.0);

        const a = @sqrt(gain_factor);
        const a_minus_1 = a - 1.0;
        const a_plus_1 = a + 1.0;

        const omega =
            2.0 * std.math.pi * @max(frequency, 2.0) / sample_rate;

        const cos_omega = @cos(omega);
        const beta = @sin(omega) * @sqrt(a) / q;
        const a_minus_1_cos = a_minus_1 * cos_omega;

        const inv_a0 = 1.0 / (a_plus_1 - a_minus_1_cos + beta);

        return .{
            .data = .{
                inv_a0 * a * (a_plus_1 + a_minus_1_cos + beta),
                inv_a0 * -2.0 * a * (a_minus_1 + a_plus_1 * cos_omega),
                inv_a0 * a * (a_plus_1 + a_minus_1_cos - beta),

                1.0,
                inv_a0 * 2.0 * (a_minus_1 - a_plus_1 * cos_omega),
                inv_a0 * (a_plus_1 - a_minus_1_cos - beta),
            },
        };
    }

    pub fn makePeakFilter(
        sample_rate: f32,
        frequency: f32,
        q: f32,
        gain_factor: f32,
    ) Coefficients {
        std.debug.assert(sample_rate > 0.0);
        std.debug.assert(frequency > 0.0);
        std.debug.assert(frequency <= sample_rate * 0.5);
        std.debug.assert(q > 0.0);
        std.debug.assert(gain_factor > 0.0);

        const a = @sqrt(gain_factor);

        const omega =
            2.0 * std.math.pi * @max(frequency, 2.0) / sample_rate;

        const alpha = @sin(omega) / (q * 2.0);
        const c2 = -2.0 * @cos(omega);
        const alpha_times_a = alpha * a;
        const alpha_over_a = alpha / a;

        const inv_a0 = 1.0 / (1.0 + alpha_over_a);

        return .{
            .data = .{
                inv_a0 * (1.0 + alpha_times_a),
                inv_a0 * c2,
                inv_a0 * (1.0 - alpha_times_a),

                1.0,
                inv_a0 * c2,
                inv_a0 * (1.0 - alpha_over_a),
            },
        };
    }
};

test "BiquadFilter" {
    const allocator = std.testing.allocator;

    const spec: audio.ProcessSpec = .{
        .block_size = 4,
        .num_channels = 2,
        .sample_rate = 48000.0,
    };

    var filter: @This() = .init;
    defer filter.deinit(allocator);
    try filter.prepare(allocator, spec);

    const coef = Coefficients.makeLowPass(
        @floatCast(spec.sample_rate),
        1000.0,
        Coefficients.invRootTwo,
    );

    var buffer: audio.AudioBuffer = .empty;
    defer buffer.deinit(allocator);
    try buffer.resize(allocator, spec.num_channels, spec.block_size);

    const audio_slice = buffer.createSlice();
    audio_slice.fill(0.0);
    audio_slice.getChannel(0)[0] = 1.0;
    audio_slice.getChannel(0)[1] = 1.0;

    filter.process(audio_slice, &coef);
}
