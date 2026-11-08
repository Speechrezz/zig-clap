const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");

const audio = @import("../audio/audio.zig");
const logging = @import("../logging/logging.zig");
const midi = @import("../midi/midi.zig");
const state = @import("../state/state.zig");

const AudioParameter = audio.AudioParameter;
const BinaryStreamOut = state.BinaryStreamOut;
const BinaryStreamIn = state.BinaryStreamIn;

const use_safe_allocator = switch (builtin.mode) {
    .debug, .safe => true,
    else => false,
};

pub fn ClapProcessor(comptime PluginProcessor: type) type {
    return struct {
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

        pub fn getParamCount(self: *const @This()) u32 {
            return @intCast(self.processor.params.getCount());
        }

        pub fn getParamAtIndex(self: *const @This(), index: u32) ?*AudioParameter {
            return self.processor.params.getChecked(index);
        }

        pub fn getParamWithId(self: *const @This(), id: u32) ?*AudioParameter {
            return self.getParamAtIndex(id);
        }

        pub fn prepare(self: *@This(), sample_rate: f64, min_frames_count: u32, max_frames_count: u32) !void {
            _ = min_frames_count;

            try self.processor.prepare(self.allocator, .{
                .sample_rate = sample_rate,
                .num_channels = 2,
                .block_size = max_frames_count,
            });
        }

        fn isNoteEventClap(event_type: u16) bool {
            return switch (event_type) {
                c.CLAP_EVENT_NOTE_ON => true,
                c.CLAP_EVENT_NOTE_OFF => true,
                c.CLAP_EVENT_NOTE_CHOKE => true,
                else => false,
            };
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

        fn handleParamValueEvent(self: *@This(), event: *const c.clap_event_header_t) void {
            const value_event: *const c.clap_event_param_value_t = @ptrCast(@alignCast(event));
            const id = value_event.param_id;

            self.processor.params.get(id).setValue(value_event.value);
        }

        pub fn syncMainToAudio(self: *@This(), out: [*c]const c.clap_output_events_t) void {
            _ = self;
            _ = out;

            // for (0..self.processor.params.items.len) |i| {
            // _ = i;
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
            // }
        }

        // pub fn processBlock(self: *@This(), start: u32, end: u32, outputL: [*]f32, outputR: [*]f32) void {
        pub fn processBlock(self: *@This(), start: u32, end: u32, channels: [][*]f32) void {
            const audio_slice: audio.AudioSlice = .{
                .channels = channels,
                .start_sample = start,
                .num_samples = end - start,
            };

            self.processor.process(audio_slice, self.note_events.items);
        }

        pub fn saveState(self: *@This(), clap_stream: *const c.clap_ostream_t) bool {
            var stream: BinaryStreamOut = .init();
            defer stream.deinit(self.allocator);

            self.processor.saveState(self.allocator, &stream) catch |err| {
                logging.debugPrint("Error saving processor state: {}\n", .{err});
                return false;
            };

            const buffer = stream.data.items;
            const result = clap_stream.*.write.?(clap_stream, buffer.ptr, buffer.len);
            return result == buffer.len;
        }

        pub fn loadState(self: *@This(), clap_stream: *const c.clap_istream_t) bool {
            const chunk_size = 256;
            var buffer: [chunk_size]u8 = undefined;

            var stream_buffer: std.ArrayList(u8) = .empty;
            defer stream_buffer.deinit(self.allocator);

            while (true) {
                const amount = clap_stream.*.read.?(clap_stream, @ptrCast(&buffer), chunk_size);
                if (amount < 0) return false; // Error occurred
                if (amount == 0) break;

                stream_buffer.appendSlice(self.allocator, buffer[0..@intCast(amount)]) catch return false;
            }

            var stream: BinaryStreamIn = .init(stream_buffer.items);
            self.processor.loadState(self.allocator, &stream) catch return false;

            return true;
        }
    };
}
