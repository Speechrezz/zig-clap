const std = @import("std");

pub const NoteNumber = i32;

pub const NoteEventKind = enum { NoteOn, NoteOff, NoteChoke };

pub const NoteEvent = struct {
    sample: u32,
    kind: NoteEventKind,
    key: NoteNumber,
    velocity: f32,
};

pub fn frequencyFromKey(key: anytype, freq_of_a: anytype) @TypeOf(key, freq_of_a) {
    return freq_of_a * std.math.exp2((key - 57.0) / 12.0);
}
