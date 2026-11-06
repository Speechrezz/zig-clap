const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");

const framework = @import("framework/framework.zig");
const midi = framework.midi;

const PluginProcessor = @import("PluginProcessor.zig");

const use_safe_allocator = switch (builtin.mode) {
    .debug, .safe => true,
    else => false,
};

safe_allocator: if (use_safe_allocator) std.heap.SafeAllocator else void,
allocator: std.mem.Allocator,
io: std.Io,
io_impl: std.Io.Threaded,

processor: PluginProcessor,

clap_plugin: c.clap_plugin_t,
host: *const c.clap_host_t,

note_events: std.ArrayList(midi.NoteEvent),

pub fn init(
    self: *@This(),
    clap_plugin: c.clap_plugin_t,
    host: *const c.clap_host_t,
) !void {
    if (use_safe_allocator) {
        self.safe_allocator = .init(std.heap.c_allocator, .{});
        self.allocator = self.safe_allocator.allocator();
    } else {
        self.allocator = std.heap.c_allocator;
    }

    self.io_impl = .init_single_threaded;
    self.io = self.io_impl.io();

    self.clap_plugin = clap_plugin;
    self.clap_plugin.plugin_data = self;
    self.host = host;

    self.note_events = .empty;

    try self.processor.init(self.allocator, self.io);
}

pub fn deinit(self: *@This()) void {
    self.processor.deinit(self.allocator);

    if (use_safe_allocator) {
        _ = self.safe_allocator.deinit();
    }

    self.io_impl.deinit();
}

pub fn processEvent(self: *@This(), event: *const c.clap_event_header_t) !void {
    if (event.space_id != c.CLAP_CORE_EVENT_SPACE_ID) return;

    if (isNoteEventClap(event.type)) {
        try self.handleNoteEvent(event);
    } else if (event.type == c.CLAP_EVENT_PARAM_VALUE) {
        self.handleParamValueEvent(event);
    }
}

fn handleNoteEvent(self: *@This(), event: *const c.clap_event_header_t) !void {
    const clap_note_event: *const c.clap_event_note_t = @ptrCast(@alignCast(event));

    var note_event: midi.NoteEvent = .{
        .sample = event.time,
        .kind = undefined,
        .key = clap_note_event.key,
        .velocity = @floatCast(clap_note_event.velocity),
    };

    switch (event.type) {
        c.CLAP_EVENT_NOTE_ON => note_event.kind = .NoteOn,
        c.CLAP_EVENT_NOTE_OFF => note_event.kind = .NoteOff,
        c.CLAP_EVENT_NOTE_CHOKE => note_event.kind = .NoteChoke,
        else => return,
    }

    try self.note_events.append(self.allocator, note_event);
}

fn handleNoteEventOld(self: *@This(), event: *const c.clap_event_header_t) void {
    const note_event: *const c.clap_event_note_t = @ptrCast(@alignCast(event));

    var i = self.voices.items.len;
    while (i > 0) {
        i -= 1;
        const voice = &self.voices.items[i];

        const key_match = note_event.key == -1 or note_event.key == voice.key;
        const id_match = note_event.note_id == -1 or note_event.note_id == voice.note_id;
        const channel_match = note_event.channel == -1 or note_event.channel == voice.channel;
        if (key_match and id_match and channel_match) {
            _ = self.voices.orderedRemove(i);
        }
    }

    if (event.type == c.CLAP_EVENT_NOTE_ON and self.voices.items.len < self.voices.capacity) {
        self.voices.appendAssumeCapacity(.{
            .held = true,
            .note_id = note_event.note_id,
            .channel = note_event.channel,
            .key = note_event.key,
            .phase = 0.0,
        });
    }
}

fn handleParamValueEvent(self: *@This(), event: *const c.clap_event_header_t) void {
    const value_event: *const c.clap_event_param_value_t = @ptrCast(@alignCast(event));
    const i = value_event.param_id;

    self.processor.params.items[i].setValue(value_event.value);
}

pub fn syncMainToAudio(self: *@This(), out: [*c]const c.clap_output_events_t) void {
    _ = out;

    for (0..self.processor.params.items.len) |i| {
        _ = i;
        // TODO: Check if parameter was changed via main thread using a dirty flag

        // const event: c.clap_event_param_value_t = .{
        //     .header = .{
        //         .size = @sizeOf(c.clap_event_param_value_t),
        //         .time = 0,
        //         .space_id = c.CLAP_CORE_EVENT_SPACE_ID,
        //         .type = c.CLAP_EVENT_PARAM_VALUE,
        //         .flags = 0,
        //     },
        //     .param_id = @intCast(i),
        //     .cookie = null,
        //     .note_id = -1,
        //     .port_index = -1,
        //     .channel = -1,
        //     .key = -1,
        //     .value = self.parameters[i],
        // };

        // _ = out.*.try_push.?(out, &event.header);
    }
}

// pub fn processBlock(self: *@This(), start: u32, end: u32, outputL: [*]f32, outputR: [*]f32) void {
pub fn processBlock(self: *@This(), start: u32, end: u32, channels: [][*]f32) void {
    const audio_slice: framework.audio.AudioSlice = .{
        .channels = channels,
        .start_sample = start,
        .num_samples = end - start,
    };

    self.processor.process(audio_slice, self.note_events.items);
}

fn isNoteEventClap(event_type: u16) bool {
    return switch (event_type) {
        c.CLAP_EVENT_NOTE_ON => true,
        c.CLAP_EVENT_NOTE_OFF => true,
        c.CLAP_EVENT_NOTE_CHOKE => true,
        else => false,
    };
}
