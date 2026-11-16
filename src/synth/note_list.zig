const std = @import("std");

pub const NoteState = enum { off, on, sustain };

pub const NoteContext = struct {
    note_number: i32,
    voice_index: usize,
    channel: i32,
    state: NoteState = .on,

    pub fn isOff(self: @This()) bool {
        return self.state == .off;
    }
    pub fn isOn(self: @This()) bool {
        return self.state == .on;
    }
    pub fn isSustain(self: @This()) bool {
        return self.state == .sustain;
    }
    pub fn isOnOrSustain(self: @This()) bool {
        return self.isOn() or self.isSustain();
    }
};

pub fn NoteList(comptime max_notes: comptime_int) type {
    return struct {
        buffer: [max_notes]NoteContext = undefined,
        notes: std.ArrayList(NoteContext) = .empty,

        pub fn init(self: *@This()) void {
            self.notes = .initBuffer(&self.buffer);
        }

        pub fn append(self: *@This(), note_number: i32, voice_index: usize, channel: i32) void {
            self.notes.appendAssumeCapacity(.{
                .note_number = note_number,
                .voice_index = voice_index,
                .channel = channel,
            });
        }

        pub fn get(self: @This(), index: usize) *NoteContext {
            return &self.notes.items[index];
        }

        pub fn indexOfNote(self: @This(), note_number: i32) ?usize {
            for (self.notes.items, 0..) |note, i| {
                if (note.note_number == note_number) {
                    return i;
                }
            }

            return null;
        }

        pub fn indexOfVoice(self: @This(), voice_index: usize) ?usize {
            for (self.notes.items, 0..) |note, i| {
                if (note.voice_index == voice_index) {
                    return i;
                }
            }

            return null;
        }

        pub fn noteExists(self: @This(), note_number: i32) bool {
            return self.indexOfNote(note_number) != null;
        }

        pub fn remove(self: *@This(), index: usize) void {
            _ = self.notes.orderedRemove(index);
        }

        pub fn popFront(self: *@This()) NoteContext {
            return self.notes.orderedRemove(0);
        }

        pub fn removeNote(self: *@This(), note_number: i32) void {
            if (self.indexOfNote(note_number)) |index| {
                _ = self.remove(index);
            }
        }

        pub fn removeVoiceIndex(self: *@This(), voice_index: usize) void {
            if (self.indexOfVoice(voice_index)) |index| {
                _ = self.remove(index);
            }
        }

        pub fn clear(self: *@This()) void {
            self.notes.clearRetainingCapacity();
        }

        pub fn getLength(self: @This()) usize {
            return self.notes.items.len;
        }

        pub fn isEmpty(self: @This()) bool {
            return self.getLength() == 0;
        }

        pub fn isFull(self: @This(), note_limit: usize) bool {
            std.debug.assert(note_limit <= max_notes);
            return self.getLength() >= note_limit;
        }
    };
}

test "NoteList tests" {
    const max_size = 8;
    var note_list: NoteList(max_size) = undefined;
    note_list.init();

    note_list.append(10, 0, 0);
    try std.testing.expect(note_list.getLength() == 1);

    note_list.append(11, 1, 0);
    try std.testing.expect(note_list.getLength() == 2);

    note_list.append(12, 2, 0);
    try std.testing.expect(note_list.getLength() == 3);

    try std.testing.expect(note_list.indexOfNote(11).? == 1);
    try std.testing.expect(note_list.indexOfVoice(2).? == 2);
    try std.testing.expect(note_list.indexOfNote(42) == null);
    try std.testing.expect(note_list.isFull(max_size) == false);

    note_list.removeNote(11);
    try std.testing.expect(note_list.getLength() == 2);
    try std.testing.expect(note_list.indexOfNote(11) == null);
    try std.testing.expect(note_list.indexOfNote(10).? == 0);
    try std.testing.expect(note_list.indexOfNote(12).? == 1);

    note_list.removeVoiceIndex(2);
    try std.testing.expect(note_list.getLength() == 1);
    try std.testing.expect(note_list.indexOfVoice(2) == null);
    try std.testing.expect(note_list.indexOfVoice(0).? == 0);

    note_list.clear();
    try std.testing.expect(note_list.getLength() == 0);
    try std.testing.expect(note_list.isEmpty());

    for (0..max_size) |i| {
        note_list.append(@intCast(i + 10), i, 0);
    }

    try std.testing.expect(note_list.getLength() == max_size);
    try std.testing.expect(note_list.isFull(max_size));
}
