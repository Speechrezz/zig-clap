const std = @import("std");
const framework = @import("framework");
const audio = framework.audio;
const dsp = framework.dsp;
const NoteEvent = framework.midi.NoteEvent;

pub const Osc = struct {
    phase: f32 = 0.0,
    radians_coeff: f32 = 0.0,

    pub const init: @This() = .{};

    pub fn reset(self: *@This()) void {
        self.phase = 0.0;
    }

    pub fn prepare(self: *@This(), spec: audio.ProcessSpec) void {
        self.phase = 0.0;

        const sample_rate: f32 = @floatCast(spec.sample_rate);
        self.radians_coeff = 2.0 * std.math.pi / sample_rate;
    }

    pub fn process(self: *@This(), audio_slice: audio.AudioSlice, frequency: f32, gain: f32) void {
        const phase_delta = frequency * self.radians_coeff;
        var current_phase: f32 = undefined;

        for (0..audio_slice.getNumChannels()) |ch| {
            current_phase = self.phase;
            const channel = audio_slice.getChannel(ch);

            for (channel) |*sample| {
                sample.* = @sin(current_phase) * gain;
                current_phase += phase_delta;
            }
        }

        self.phase = @mod(current_phase, 2.0 * std.math.pi);
    }
};

buffer: audio.AudioBuffer = .empty,
osc: Osc = .init,
adsr: dsp.AdsrProcessor = .init,
frequency: f32 = 0.0,
velocity: f32 = 1.0,
is_note_on: bool = false,

pub fn init(self: *@This()) void {
    self.* = .{};
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.buffer.deinit(allocator);
}

pub fn prepare(self: *@This(), allocator: std.mem.Allocator, spec: audio.ProcessSpec) !void {
    try self.buffer.resize(allocator, spec.num_channels, spec.block_size);
    self.buffer.clear();

    self.osc.prepare(spec);
    self.adsr.prepare(spec);
}

pub fn renderNextBlock(self: *@This(), output_slice: audio.AudioSlice) void {
    if (!self.isCurrentlyPlaying() or output_slice.getNumSamples() == 0) return;

    const voice_view = self.buffer.createSliceWithLength(output_slice.getNumSamples());

    self.osc.process(voice_view, self.frequency, self.velocity);
    self.adsr.applyGain(voice_view);

    output_slice.addFrom(voice_view);
}

pub fn noteStart(self: *@This(), note_number: f32, velocity: f32) void {
    self.frequency = framework.midi.frequencyFromKey(note_number, 440.0);
    self.velocity = velocity;

    self.osc.reset();
    self.adsr.noteOn();

    self.is_note_on = true;
}

pub fn noteStop(self: *@This(), _: f32, allow_tail_off: bool) void {
    if (allow_tail_off) {
        self.adsr.noteOff();
    } else {
        self.adsr.reset();
    }

    self.is_note_on = false;
}

pub fn isCurrentlyPlaying(self: @This()) bool {
    return self.adsr.isCurrentlyPlaying();
}

pub fn updateAdsr(self: *@This(), parameters: dsp.AdsrProcessor.Parameters) void {
    self.adsr.updateParameters(parameters);
}
