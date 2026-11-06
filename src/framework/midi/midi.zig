const std = @import("std");

pub const NoteNumber = i32;

pub const NoteEventKind = enum { NoteOn, NoteOff, NoteChoke };

pub const NoteEvent = struct {
    sample: u32,
    kind: NoteEventKind,
    key: NoteNumber,
    velocity: f32,
};

pub fn frequencyFromKey(key: anytype) @TypeOf(key) {
    440.0 * std.math.exp2((key - 57.0) / 12.0);
}
