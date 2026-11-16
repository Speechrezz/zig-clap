const std = @import("std");
const audio = @import("../audio/audio.zig");

const State = enum { off, attack, decay, sustain, release };

// In seconds
pub const Parameters = struct {
    attack_time: f32 = 0.001,
    decay_time: f32 = 0.2,
    sustain_gain: f32 = 0.5,
    release_time: f32 = 0.1,
};

state: State = .off,
sample_rate: f32 = -1.0,
parameters: Parameters = .{},

offset: f32 = 0.0,
time_step: f32 = 0.0,

attack_step: f32 = 0.0,
decay_step: f32 = 0.0,
release_step: f32 = 0.0,

current_value: f32 = 0.0,
start_value: f32 = 0.0,
target_value: f32 = 0.0,

pub const init: @This() = .{};

pub fn reset(self: *@This()) void {
    self.setState(.off);
}

pub fn prepare(self: *@This(), spec: audio.ProcessSpec) void {
    self.sample_rate = @floatCast(spec.sample_rate);
    self.updateParametersImpl(self.parameters);
}

pub fn applyGain(self: *@This(), audio_slice: audio.AudioSlice) void {
    if (self.state == .off) {
        audio_slice.clear();
        return;
    }

    // Optimization which assumes that the audio block is split upon release
    if (self.state == .sustain) {
        audio_slice.multiplyBy(self.parameters.sustain_gain);
        self.current_value = self.parameters.sustain_gain;
        return;
    }

    for (0..audio_slice.getNumSamples()) |i| {
        const envelope = self.getNextSample();

        for (0..audio_slice.getNumChannels()) |ch| {
            audio_slice.getChannel(ch)[i] *= envelope;
        }
    }
}

pub fn fillBuffer(self: *@This(), buffer: []f32) void {
    if (self.state == .off) {
        @memset(buffer, 0.0);
        return;
    }

    // Optimization which assumes that the audio block is split upon release
    if (self.state == .sustain) {
        @memset(buffer, self.parameters.sustain_gain);
        self.current_value = self.parameters.sustain_gain;
        return;
    }

    for (buffer) |*v| {
        v.* = self.getNextSample();
    }
}

pub fn getNextSample(self: *@This()) f32 {
    self.offset += self.time_step;
    self.updateState();

    const tensioned_offset = @sqrt(self.offset);
    self.current_value = std.math.lerp(self.start_value, self.target_value, tensioned_offset);
    return self.current_value;
}

fn calculateStepSize(duration: f32, sample_rate: f32) f32 {
    return if (duration > 0.0) 1.0 / (duration * sample_rate) else 2.0;
}

pub fn updateParameters(self: *@This(), parameters: Parameters) void {
    if (std.meta.eql(self.parameters, parameters)) return;
    self.updateParametersImpl(parameters);
}

fn updateParametersImpl(self: *@This(), parameters: Parameters) void {
    self.parameters = parameters;

    self.attack_step = calculateStepSize(parameters.attack_time, self.sample_rate);
    self.decay_step = calculateStepSize(parameters.decay_time, self.sample_rate);
    self.release_step = calculateStepSize(parameters.release_time, self.sample_rate);
    self.updateCurrentStateParameters(false);
}

pub fn isCurrentlyPlaying(self: @This()) bool {
    return self.state != .off;
}

pub fn noteOn(self: *@This()) void {
    if (self.parameters.attack_time > 0.0) {
        self.setState(.attack);
    } else if (self.parameters.decay_time > 0.0) {
        self.setState(.decay);
    } else {
        self.setState(.sustain);
    }
}

pub fn noteOff(self: *@This()) void {
    self.setState(.release);
}

fn updateState(self: *@This()) void {
    switch (self.state) {
        .attack => if (self.offset > 1.0) self.setState(.decay),
        .decay => if (self.offset > 1.0) self.setState(.sustain),
        .release => if (self.offset > 1.0) self.setState(.off),
        else => {},
    }
}

fn setState(self: *@This(), state: State) void {
    self.state = state;
    self.offset = 0.0;

    self.updateCurrentStateParameters(true);
}

/// Set `beginning` to `true` if the beginning of a new state
/// (AKA `setState` was just called).
fn updateCurrentStateParameters(self: *@This(), comptime beginning: bool) void {
    switch (self.state) {
        .off => {
            self.time_step = 0.0;
            self.current_value = 0.0;
            self.start_value = 0.0;
            self.target_value = 0.0;
        },
        .attack => {
            self.time_step = self.attack_step;
            if (beginning) self.current_value = 0.0;
            if (beginning) self.start_value = 0.0;
            self.target_value = 1.0;
        },
        .decay => {
            self.time_step = self.decay_step;
            if (beginning) self.current_value = 1.0;
            if (beginning) self.start_value = 1.0;
            self.target_value = self.parameters.sustain_gain;
        },
        .sustain => {
            self.time_step = 0.0;
            self.current_value = self.parameters.sustain_gain;
            self.start_value = self.parameters.sustain_gain;
            self.target_value = self.parameters.sustain_gain;
        },
        .release => {
            self.time_step = self.release_step;
            if (beginning) self.start_value = self.current_value;
            self.target_value = 0.0;
        },
    }
}

test "AdsrProcessor" {
    var adsr: @This() = .init;
    adsr.prepare(.{ .block_size = 128, .num_channels = 2, .sample_rate = 48000.0 });
    adsr.updateParameters(.{
        .attack_time = 0.0,
        .decay_time = 1.0,
        .sustain_gain = 1.0,
        .release_time = 0.0,
    });

    adsr.noteOn();
    try std.testing.expectApproxEqRel(1.0, adsr.getNextSample(), 1e-5);
    try std.testing.expectApproxEqRel(1.0, adsr.getNextSample(), 1e-5);

    adsr.noteOff();
    try std.testing.expectApproxEqAbs(0.0, adsr.getNextSample(), 1e-5);
    try std.testing.expectApproxEqAbs(0.0, adsr.getNextSample(), 1e-5);
}
