const std = @import("std");
const framework = @import("framework/framework.zig");
const AudioParameter = framework.audio.AudioParameter;
const AudioSlice = framework.audio.AudioSlice;

const max_voices = 8;
const Voice = struct {
    held: bool,
    note_id: i32,
    channel: i16,
    key: framework.midi.NoteNumber,
    phase: f32,
};

params: std.ArrayList(AudioParameter) = .empty,

sample_rate: f32 = -1.0,
voices: std.ArrayList(Voice) = .empty,
voices_buffer: [max_voices]Voice = undefined,

pub fn init(self: *@This(), allocator: std.mem.Allocator, _: std.Io) !void {
    self.* = .{};

    try self.params.append(allocator, .init(
        0,
        "Volume",
        0.0,
        1.0,
        0.5,
    ));

    self.voices = .initBuffer(&self.voices_buffer);
}

pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
    self.params.deinit(allocator);
}

pub fn prepare(self: *@This(), allocator: std.mem.Allocator, spec: framework.audio.ProcessSpec) !void {
    _ = allocator;
    // TODO

    self.sample_rate = @floatCast(spec.sample_rate);
}

pub fn process(self: *@This(), audio: AudioSlice, note_events: []framework.midi.NoteEvent) void {
    const volume: f32 = @floatCast(self.params.items[0].getValue());

    var prev_sample: u32 = 0;
    for (note_events) |note_event| {
        self.handleNoteEvent(note_event);

        const num_samples = note_event.sample - prev_sample;
        const slice = audio.createSubView(prev_sample, num_samples);
        self.renderBlock(slice, volume);

        prev_sample = note_event.sample;
    }

    const num_samples = audio.getNumSamples() - prev_sample;
    const slice = audio.createSubView(prev_sample, num_samples);
    self.renderBlock(slice, volume);
}

fn handleNoteEvent(self: *@This(), note_event: framework.midi.NoteEvent) void {
    var i = self.voices.items.len;
    while (i > 0) {
        i -= 1;
        const voice = &self.voices.items[i];

        const key_match = note_event.key == -1 or note_event.key == voice.key;
        const id_match = true; //note_event.note_id == -1 or note_event.note_id == voice.note_id;
        const channel_match = true; //note_event.channel == -1 or note_event.channel == voice.channel;
        if (key_match and id_match and channel_match) {
            _ = self.voices.orderedRemove(i);
        }
    }

    if (note_event.kind == .NoteOn and self.voices.items.len < self.voices.capacity) {
        self.voices.appendAssumeCapacity(.{
            .held = true,
            .note_id = 0, // note_event.note_id,
            .channel = 0, // note_event.channel,
            .key = note_event.key,
            .phase = 0.0,
        });
    }
}

fn renderBlock(self: *@This(), audio_slice: AudioSlice, volume: f32) void {
    for (0..audio_slice.num_samples) |i| {
        var sample: f32 = 0.0;

        for (self.voices.items) |*voice| {
            if (voice.held == false) continue;

            sample += @sin(voice.phase * 2.0 * std.math.pi) * 0.2 * volume;

            const key_float: f32 = @floatFromInt(voice.key);
            voice.phase += 440.0 * std.math.exp2((key_float - 57.0) / 12.0) / self.sample_rate;
            voice.phase -= @floor(voice.phase);
        }

        for (0..audio_slice.getNumChannels()) |ch| {
            audio_slice.getChannel(ch)[i] = sample;
        }
    }
}

pub fn saveState(self: *@This(), allocator: std.mem.Allocator, stream: *framework.state.BinaryStreamOut) !void {
    for (self.params.items) |*param| {
        try stream.appendValue(allocator, param.getValue());
    }
}

pub fn loadState(self: *@This(), _: std.mem.Allocator, stream: *framework.state.BinaryStreamIn) !void {
    for (self.params.items) |*param| {
        param.setValue(stream.readValue(f64));
    }
}
