const std = @import("std");
const framework = @import("../framework/framework.zig");
const audio = framework.audio;
const logging = framework.logging;
const NoteEvent = framework.midi.NoteEvent;
const NoteContext = @import("note_list.zig").NoteContext;
const NoteList = @import("note_list.zig").NoteList;
const PitchTransition = @import("types.zig").PitchTransition;

const max_voices = 16;

pub const Config = struct {
    can_do_note_restart: bool = false,
    can_do_legato: bool = false,
    can_do_porta: bool = false,

    debug_logging: bool = false,
};

fn checkForPitchTransitionArg(comptime fn_type: type) void {
    const fn_info = @typeInfo(fn_type).@"fn";

    if (fn_info.params.len <= 2 or fn_info.params[2].type.? != PitchTransition) {
        @compileError("Expected `" ++ @typeName(fn_type) ++ "` method to have `PitchTransition` argument");
    }
}

pub fn SynthProcessor(comptime SynthVoice: type, comptime config: Config) type {
    if (config.can_do_note_restart) {
        if (!std.meta.hasMethod(SynthVoice, "noteRestart")) {
            @compileError("Expected `noteRestart()` method in `" ++ @typeName(SynthVoice) ++ "`");
        }
    }
    if (config.can_do_legato) {
        if (!std.meta.hasMethod(SynthVoice, "noteLegato")) {
            @compileError("Expected `noteLegato()` method in `" ++ @typeName(SynthVoice) ++ "`");
        }
    }
    if (config.can_do_porta) {
        if (!std.meta.hasMethod(SynthVoice, "getCurrentPitch")) {
            @compileError("Expected `getCurrentPitch()` method in `" ++ @typeName(SynthVoice) ++ "`");
        }

        checkForPitchTransitionArg(@TypeOf(SynthVoice.noteStart));

        if (config.can_do_note_restart) {
            checkForPitchTransitionArg(@TypeOf(SynthVoice.noteRestart));
        }

        if (config.can_do_legato) {
            const fn_type = @TypeOf(SynthVoice.noteLegato);
            const fn_info = @typeInfo(fn_type).@"fn";
            if (fn_info.params.len <= 2 or fn_info.params[2].type.? != f32) {
                @compileError("Expected `" ++ @typeName(fn_type) ++ "` method to have `prev_note: f32` argument");
            }
        }
    }

    return struct {
        synth_voices: [max_voices]SynthVoice = undefined,

        // Notes that are playing/ringing out
        active_notes: NoteList(max_voices) = undefined,

        // Voices that are not playing/ringing out
        inactive_voices_buffer: [max_voices]usize = undefined,
        inactive_voices: std.ArrayList(usize) = .empty,

        // Notes that need to be played but are not assigned voices
        queued_notes_buffer: [max_voices]i32 = undefined,
        queued_notes: std.ArrayList(i32) = .empty,

        voice_limit: usize = max_voices,

        // Legato
        legato: if (config.can_do_legato) bool else void =
            if (config.can_do_legato) false else {},

        // Porta
        always_porta: if (config.can_do_porta) bool else void =
            if (config.can_do_porta) false else {},
        prev_note: if (config.can_do_porta) f32 else void =
            if (config.can_do_porta) 0.0 else {},

        pub fn init(self: *@This(), args: anytype) void {
            self.* = .{};

            for (&self.synth_voices) |*voice| {
                @call(.auto, SynthVoice.init, .{voice} ++ args);
            }

            self.active_notes.init();
            self.inactive_voices = .initBuffer(&self.inactive_voices_buffer);
            self.queued_notes = .initBuffer(&self.queued_notes_buffer);

            var i = self.inactive_voices_buffer.len;
            while (i > 0) : (i -= 1) {
                self.inactive_voices.appendAssumeCapacity(i - 1);
            }
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            for (&self.synth_voices) |*voice| {
                voice.deinit(allocator);
            }
        }

        pub fn prepare(self: *@This(), allocator: std.mem.Allocator, spec: audio.ProcessSpec) !void {
            for (&self.synth_voices) |*voice| {
                try voice.prepare(allocator, spec);
            }
        }

        pub fn process(self: *@This(), audio_slice: audio.AudioSlice, note_events: []NoteEvent) void {
            audio_slice.clear();
            var prev_sample_pos: u32 = 0;

            for (note_events) |note_event| {
                const samples_between_events = note_event.sample - prev_sample_pos;
                self.renderSynthVoices(
                    audio_slice,
                    @intCast(prev_sample_pos),
                    @intCast(samples_between_events),
                );

                prev_sample_pos = note_event.sample;
                self.handleMidiEvent(note_event);
            }

            // Finishes rendering the block of audio
            const samples_between_events = @as(u32, @intCast(audio_slice.getNumSamples())) - prev_sample_pos;
            self.renderSynthVoices(
                audio_slice,
                @intCast(prev_sample_pos),
                @intCast(samples_between_events),
            );
        }

        pub fn renderSynthVoices(
            self: *@This(),
            audio_slice: audio.AudioSlice,
            prev_sample_pos: usize,
            samples_between_events: usize,
        ) void {
            const sub_slice = audio_slice.createSubSlice(prev_sample_pos, samples_between_events);
            for (&self.synth_voices) |*voice| {
                voice.renderNextBlock(sub_slice);
            }
        }

        pub fn handleMidiEvent(self: *@This(), note_event: NoteEvent) void {
            switch (note_event.kind) {
                .NoteOn => self.noteOn(note_event),
                .NoteOff => self.noteOff(note_event),
                .NoteChoke => self.stopAllNotes(true),
            }
        }

        fn voiceNoteStart(self: *@This(), voice: *SynthVoice, note_number: f32, velocity: f32) void {
            if (config.debug_logging) logging.debugPrint("{s}({})", .{ @src().fn_name, note_number });

            if (config.can_do_porta) {
                var transition: PitchTransition = undefined;
                if (self.always_porta or self.numOnVoices() >= 2) {
                    transition = .{ .glide_from = self.getNthLatestPitch(1) };
                } else {
                    transition = .immediate;
                }

                voice.noteStart(note_number, transition, velocity);
            } else {
                voice.noteStart(note_number, velocity);
            }
        }

        fn voiceNoteRestart(
            self: *@This(),
            voice: *SynthVoice,
            note_number: f32,
            velocity: f32,
            was_note_on: bool,
        ) void {
            if (config.debug_logging) logging.debugPrint("{s}({})", .{ @src().fn_name, note_number });

            var transition: PitchTransition = undefined;
            if (config.can_do_porta) {
                if (self.always_porta or was_note_on or self.numOnVoices() >= 2) {
                    transition = .{ .glide_from = self.getNthLatestPitch(0) };
                } else {
                    transition = .immediate;
                }
            }

            if (config.can_do_note_restart) {
                if (config.can_do_porta) {
                    voice.noteRestart(note_number, transition, velocity);
                } else {
                    voice.noteRestart(note_number, velocity);
                }
            } else {
                voice.noteStop(1.0, false);
                if (config.can_do_porta) {
                    voice.noteStart(note_number, transition, velocity);
                } else {
                    voice.noteStart(note_number, velocity);
                }
            }
        }

        fn voiceNoteLegato(self: *@This(), voice: *SynthVoice, note_number: f32, velocity: f32) void {
            if (config.debug_logging) logging.logDebug("{s}({})", .{ @src().fn_name, note_number });

            if (config.can_do_porta) {
                voice.noteLegato(note_number, self.getNthLatestPitch(0), velocity);
            } else {
                voice.noteLegato(note_number, velocity);
            }
        }

        fn noteLegatoOrRestart(
            self: *@This(),
            voice: *SynthVoice,
            note_number: f32,
            velocity: f32,
            prev_note: NoteContext,
        ) void {
            if (config.can_do_legato and self.legato and prev_note.isOnOrSustain()) {
                self.voiceNoteLegato(voice, note_number, velocity);
            } else {
                self.voiceNoteRestart(
                    voice,
                    note_number,
                    velocity,
                    prev_note.isOnOrSustain(),
                );
            }
        }

        pub fn noteOn(self: *@This(), note_event: NoteEvent) void {
            const note_number = note_event.key;
            const channel: i32 = 0; // TODO
            const velocity = note_event.velocity;

            self.playNote(note_number, channel, velocity);
        }

        fn playNote(self: *@This(), note_number: i32, channel: i32, velocity: f32) void {
            self.reclaimVoices();
            const note_number_float: f32 = @floatFromInt(note_number);

            if (self.active_notes.isFull(self.voice_limit)) {
                // Steal voice
                const oldest_note = self.active_notes.popFront();
                self.active_notes.append(note_number, oldest_note.voice_index, channel);

                const voice = &self.synth_voices[oldest_note.voice_index];

                if (oldest_note.isOnOrSustain()) {
                    self.appendToQueuedNotes(oldest_note.note_number);
                }

                self.noteLegatoOrRestart(
                    voice,
                    note_number_float,
                    velocity,
                    oldest_note,
                );
            } else {
                // Use not-active voice
                const voice_index = self.inactive_voices.pop().?;
                self.active_notes.append(note_number, voice_index, channel);

                const voice = &self.synth_voices[voice_index];
                self.voiceNoteStart(voice, note_number_float, velocity);
            }

            if (config.can_do_porta) {
                self.prev_note = note_number_float;
            }
        }

        pub fn noteOff(self: *@This(), note_event: NoteEvent) void {
            const note_number = note_event.key;
            const velocity = note_event.velocity;
            const is_sustain_pedal_on = false; // TODO

            if (!is_sustain_pedal_on) {
                // TODO: When sustain pedal is let go, remove notes from queue that are
                // in the 'sustain' state.
                self.removeNoteFromQueuedNotes(note_number);
            }

            for (self.active_notes.notes.items, 0..) |*note, i| {
                const is_correct_note = note_number == note.note_number;
                if (note.isOn() and is_correct_note) {
                    self.stopNote(i, velocity);
                }
            }
        }

        fn stopNote(self: *@This(), active_index: usize, velocity: f32) void {
            const is_sustain_pedal_on = false; // TODO

            if (is_sustain_pedal_on) {
                self.active_notes.notes.items[active_index].state = .sustain;
                return;
            }

            if (self.getNextQueuedNote()) |queued_note| {
                // Start playing a queued note

                const prev_note = self.active_notes.notes.orderedRemove(active_index);
                self.active_notes.append(queued_note, prev_note.voice_index, prev_note.channel);

                const voice = &self.synth_voices[prev_note.voice_index];
                self.noteLegatoOrRestart(
                    voice,
                    @floatFromInt(queued_note),
                    velocity,
                    prev_note,
                );
            } else {
                const note = self.active_notes.get(active_index);
                note.state = .off;
                self.synth_voices[note.voice_index].noteStop(velocity, true);
            }

            if (config.can_do_porta) {
                self.setPrevNoteToNewestPlayingVoice();
            }
        }

        pub fn stopAllNotes(self: *@This(), allow_tail_off: bool) void {
            self.queued_notes.clearRetainingCapacity();

            for (self.active_notes.notes.items) |*note| {
                note.state = .off;
                self.synth_voices[note.voice_index].noteStop(1.0, allow_tail_off);
            }
        }

        fn appendToQueuedNotes(self: *@This(), note_number: i32) void {
            if (self.queued_notes.items.len == self.queued_notes.capacity) {
                _ = self.queued_notes.orderedRemove(0);
            }

            self.queued_notes.appendAssumeCapacity(note_number);
        }

        fn removeNoteFromQueuedNotes(self: *@This(), note_number: i32) void {
            var i = self.queued_notes.items.len;
            while (i > 0) {
                i -= 1;

                if (self.queued_notes.items[i] == note_number) {
                    _ = self.queued_notes.orderedRemove(i);
                }
            }
        }

        fn getNextQueuedNote(self: *@This()) ?i32 {
            return self.queued_notes.pop();
        }

        fn numOnVoices(self: *const @This()) usize {
            var count: usize = 0;

            for (self.active_notes.notes.items) |note| {
                if (note.isOnOrSustain()) count += 1;
            }

            return count;
        }

        /// nth_newest = 0 is the same as the newest
        fn getNthNewestOnVoiceIndex(self: *const @This(), nth_newest: usize) ?usize {
            var i = self.active_notes.getLength();
            while (i > nth_newest) {
                i -= 1;
                const index = i - nth_newest;

                const note = self.active_notes.notes.items[index];
                if (note.isOnOrSustain()) {
                    return index;
                }
            }

            return null;
        }

        fn reclaimVoices(self: *@This()) void {
            var i = self.active_notes.getLength();
            while (i > 0) {
                i -= 1;

                const note = self.active_notes.get(i);
                if (!note.isOff() or self.synth_voices[note.voice_index].isCurrentlyPlaying()) continue;

                self.inactive_voices.appendAssumeCapacity(note.voice_index);
                self.active_notes.remove(i);
            }
        }

        /// Get nth-latest pitch.
        fn getNthLatestPitch(self: *const @This(), nth_latest: usize) f32 {
            comptime std.debug.assert(config.can_do_porta);

            const newest_on_voice_index = self.getNthNewestOnVoiceIndex(nth_latest);
            if (newest_on_voice_index) |active_index| {
                const voice_index = self.active_notes.notes.items[active_index].voice_index;
                return self.synth_voices[voice_index].getCurrentPitch();
            }

            return self.prev_note;
        }

        fn setPrevNoteToNewestPlayingVoice(self: *@This()) void {
            var i = self.active_notes.notes.items.len;
            while (i > 0) {
                i -= 1;
                const note = self.active_notes.notes.items[i];
                if (note.isOnOrSustain()) {
                    self.prev_note = @floatFromInt(note.note_number);
                    return;
                }
            }
        }
    };
}

test "SynthProcessor tests" {
    const SynthVoice = @import("SineVoice.zig");
    const dsp = framework.dsp;
    const allocator = std.testing.allocator;

    const sample_rate = 48000.0;
    const num_channels = 2;
    const block_size = 128;

    var processor: SynthProcessor(SynthVoice, .{}) = undefined;
    processor.init(.{});
    defer processor.deinit(allocator);
    try processor.prepare(allocator, .{
        .sample_rate = sample_rate,
        .num_channels = num_channels,
        .block_size = block_size,
    });

    // Ensure notes stop instantly
    const adsr_parameters: dsp.AdsrProcessor.Parameters = .{
        .attack_time = 0.0,
        .decay_time = 0.0,
        .sustain_gain = 1.0,
        .release_time = 0.0,
    };
    for (&processor.synth_voices) |*synth_voice| {
        synth_voice.updateAdsr(adsr_parameters);
    }

    var audio_buffer: audio.AudioBuffer = .empty;
    defer audio_buffer.deinit(allocator);
    try audio_buffer.resize(allocator, num_channels, block_size);

    var note_events = [_]NoteEvent{.{
        .sample = 0,
        .kind = .NoteOn,
        .key = 69,
        .velocity = 0.5,
    }};

    try std.testing.expect(processor.active_notes.isEmpty());
    try std.testing.expect(processor.inactive_voices.items.len == max_voices);

    processor.process(audio_buffer.createSlice(), &note_events);

    try std.testing.expect(processor.active_notes.getLength() == 1);
    try std.testing.expect(processor.inactive_voices.items.len == max_voices - 1);

    note_events[0] = .{
        .sample = 0,
        .kind = .NoteOff,
        .key = 69,
        .velocity = 0.5,
    };

    processor.process(audio_buffer.createSlice(), &note_events);
    processor.reclaimVoices();

    try std.testing.expectEqual(0, processor.active_notes.getLength());
    try std.testing.expectEqual(max_voices, processor.inactive_voices.items.len);
}
