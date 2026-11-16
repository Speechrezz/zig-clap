const std = @import("std");
const framework = @import("framework/framework.zig");
const AudioSlice = framework.audio.AudioSlice;

const AudioParam = framework.audio.AudioParam;
const normalizable = framework.math.normalizable;
const formatting = framework.fmt.value;

const SynthProcessor = @import("synth/synth_processor.zig").SynthProcessor;
const SineVoice = @import("synth/SineVoice.zig");

const Params = framework.audio.AudioParamContainer(struct {
    volume: AudioParam.Float(.{
        .version = 1,
        .name = "Volume",
        .Range = normalizable.Linear(f64, 0.0, 1.0),
        .default_value = 0.5,
        .Formatter = formatting.Percent(f64),
    }),

    attack: AudioParam.Float(.{
        .version = 1,
        .name = "Attack",
        .Range = normalizable.SkewedCenter(f64, 0.0, 1.0, 0.1),
        .default_value = 0.002,
        .Formatter = formatting.Seconds(f64),
    }),
    decay: AudioParam.Float(.{
        .version = 1,
        .name = "Decay",
        .Range = normalizable.SkewedCenter(f64, 0.0, 1.0, 0.1),
        .default_value = 0.1,
        .Formatter = formatting.Seconds(f64),
    }),
    sustain: AudioParam.Float(.{
        .version = 1,
        .name = "Sustain",
        .Range = normalizable.Linear(f64, 0.0, 1.0),
        .default_value = 0.5,
        .Formatter = formatting.Percent(f64),
    }),
    release: AudioParam.Float(.{
        .version = 1,
        .name = "Release",
        .Range = normalizable.SkewedCenter(f64, 0.0, 1.0, 0.1),
        .default_value = 0.01,
        .Formatter = formatting.Seconds(f64),
    }),
    // TEST PARAM
    frequency: AudioParam.Float(.{
        .version = 1,
        .name = "Frequency",
        .Range = normalizable.Log10(f64, 20.0, 20_000.0),
        .default_value = 1000.0,
        .Formatter = formatting.Hertz(f64),
    }),
});

params: Params = undefined,
synth: SynthProcessor(SineVoice, .{}) = undefined,

pub fn init(self: *@This(), allocator: std.mem.Allocator, _: std.Io) !void {
    _ = allocator;

    self.* = .{};

    self.params.init();
    self.synth.init(.{});
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.synth.deinit(allocator);
}

pub fn prepare(self: *@This(), allocator: std.mem.Allocator, spec: framework.audio.ProcessSpec) !void {
    try self.synth.prepare(allocator, spec);
}

pub fn process(self: *@This(), audio: AudioSlice, note_events: []framework.midi.NoteEvent) void {
    const volume: f32 = @floatCast(self.params.values.volume.getValue());

    const adsr_params: framework.dsp.AdsrProcessor.Parameters = .{
        .attack_time = @floatCast(self.params.values.attack.getValue()),
        .decay_time = @floatCast(self.params.values.decay.getValue()),
        .sustain_gain = @floatCast(self.params.values.sustain.getValue()),
        .release_time = @floatCast(self.params.values.release.getValue()),
    };

    for (&self.synth.synth_voices) |*voice| {
        voice.adsr.updateParameters(adsr_params);
    }

    self.synth.process(audio, note_events);
    audio.multiplyBy(volume);
}

pub fn saveState(self: *@This(), allocator: std.mem.Allocator, stream: *framework.state.BinaryStreamOut) !void {
    try self.params.saveState(allocator, stream);
}

pub fn loadState(self: *@This(), _: std.mem.Allocator, stream: *framework.state.BinaryStreamIn) !void {
    self.params.loadState(stream);
}

test {
    _ = SynthProcessor;
}
