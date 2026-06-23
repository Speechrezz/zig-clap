const std = @import("std");
const builtin = @import("builtin");
const dbg = @import("debug_clap.zig");
const clap = @import("clap.zig").c;

const c = @cImport({
    @cInclude("string.h");
    @cInclude("stdlib.h");
});

const clap_version: clap.clap_version_t = .{
    .major = clap.CLAP_VERSION_MAJOR,
    .minor = clap.CLAP_VERSION_MINOR,
    .revision = clap.CLAP_VERSION_REVISION,
};

// ---Entry---

export const clap_entry: clap.clap_plugin_entry_t = .{
    .clap_version = clap_version,
    .init = entryInit,
    .deinit = entryDeinit,
    .get_factory = entryGetFactory,
};

fn entryInit(plugin_path: [*c]const u8) callconv(.c) bool {
    _ = plugin_path;
    return true;
}

fn entryDeinit() callconv(.c) void {}

fn entryGetFactory(factory_id: [*c]const u8) callconv(.c) ?*const anyopaque {
    const does_id_match = c.strcmp(factory_id, &clap.CLAP_PLUGIN_FACTORY_ID) == 0;
    if (!does_id_match) return null;

    return &plugin_factory;
}

// ---Factory---

const plugin_factory: clap.clap_plugin_factory_t = .{
    .get_plugin_count = getPluginCount,
    .get_plugin_descriptor = getPluginDescriptor,
    .create_plugin = createPlugin,
};

fn getPluginCount(_: [*c]const clap.clap_plugin_factory_t) callconv(.c) u32 {
    return 1;
}

fn getPluginDescriptor(
    _: [*c]const clap.clap_plugin_factory_t,
    index: u32,
) callconv(.c) [*c]const clap.clap_plugin_descriptor_t {
    if (index != 0)
        return null;

    return &plugin_descriptor;
}

fn createPlugin(
    _: [*c]const clap.clap_plugin_factory_t,
    host: [*c]const clap.clap_host_t,
    plugin_id: [*c]const u8,
) callconv(.c) [*c]const clap.clap_plugin_t {
    const is_version_compatible = clap.clap_version_is_compatible(host.*.clap_version);
    const is_id_matching = c.strcmp(plugin_id, plugin_descriptor.id) == 0;
    if (!is_version_compatible or !is_id_matching) {
        return null;
    }

    // TODO: Maybe don't use malloc here lol
    const plugin: *MyPlugin = @ptrCast(@alignCast(c.malloc(@sizeOf(MyPlugin))));
    plugin.init(plugin_class, host);
    return &plugin.plugin;
}

const plugin_descriptor: clap.clap_plugin_descriptor_t = .{
    .clap_version = clap_version,
    .id = "xynth.Test2",
    .name = "Test2",
    .vendor = "Xynth Audio",
    .url = "xynth.audio",
    .manual_url = "https://github.com/Speechrezz/zig-clap",
    .support_url = "https://github.com/Speechrezz/zig-clap",
    .version = "0.0.1",
    .description = "The best audio plugin ever.",
    .features = &plugin_features,
};

const plugin_features = [_][*c]const u8{
    clap.CLAP_PLUGIN_FEATURE_INSTRUMENT,
    clap.CLAP_PLUGIN_FEATURE_SYNTHESIZER,
    clap.CLAP_PLUGIN_FEATURE_STEREO,
    null,
};

// ---Plugin Class---

const plugin_class: clap.clap_plugin_t = .{
    .desc = &plugin_descriptor,
    .plugin_data = null,
    .init = initPlugin,
    .destroy = destroyPlugin,
    .activate = activatePlugin,
    .deactivate = deactivatePlugin,
    .start_processing = startProcessingPlugin,
    .stop_processing = stopProcessingPlugin,
    .reset = resetPlugin,
    .process = processPlugin,
    .get_extension = getExtension,
    .on_main_thread = onMainThread,
};

fn initPlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) bool {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
    return true;
}

fn destroyPlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) void {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    plugin.deinit();
    c.free(plugin);
}

fn activatePlugin(
    clap_plugin: [*c]const clap.clap_plugin_t,
    sample_rate: f64,
    min_frames_count: u32,
    max_frames_count: u32,
) callconv(.c) bool {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    plugin.sample_rate = @floatCast(sample_rate);
    _ = min_frames_count;
    _ = max_frames_count;

    return true;
}

fn deactivatePlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) void {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn startProcessingPlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) bool {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
    return true;
}

fn stopProcessingPlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) void {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn resetPlugin(clap_plugin: [*c]const clap.clap_plugin_t) callconv(.c) void {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn processPlugin(
    clap_plugin: [*c]const clap.clap_plugin_t,
    process: [*c]const clap.clap_process_t,
) callconv(.c) clap.clap_process_status {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    std.debug.assert(process.*.audio_inputs_count == 0);
    std.debug.assert(process.*.audio_outputs_count == 1);

    plugin.syncMainToAudio(process.*.out_events);

    const frame_count = process.*.frames_count;
    const input_event_count = process.*.in_events.*.size.?(process.*.in_events);
    var event_index: u32 = 0;
    var next_event_frame: u32 = if (input_event_count > 0) 0 else frame_count;

    var i: u32 = 0;
    while (i < frame_count) {
        while (event_index < input_event_count and next_event_frame == i) {
            const event = process.*.in_events.*.get.?(process.*.in_events, event_index);

            if (event.*.time != i) {
                next_event_frame = event.*.time;
                break;
            }

            plugin.processEvent(event);
            event_index += 1;

            if (event_index == input_event_count) {
                next_event_frame = frame_count;
                break;
            }
        }

        plugin.renderAudio(i, next_event_frame, process.*.audio_outputs[0].data32[0], process.*.audio_outputs[0].data32[1]);
        i = next_event_frame;
    }

    return clap.CLAP_PROCESS_CONTINUE;
}

fn getExtension(
    _: [*c]const clap.clap_plugin_t,
    id: [*c]const u8,
) callconv(.c) ?*const anyopaque {
    if (0 == c.strcmp(id, &clap.CLAP_EXT_NOTE_PORTS)) return &extension_note_ports;
    if (0 == c.strcmp(id, &clap.CLAP_EXT_AUDIO_PORTS)) return &extension_audio_ports;
    if (0 == c.strcmp(id, &clap.CLAP_EXT_PARAMS)) return &extension_params;

    return null;
}

fn onMainThread(_: [*c]const clap.clap_plugin_t) callconv(.c) void {
    //
}

// ---Extensions---

const extension_note_ports: clap.clap_plugin_note_ports_t = .{
    .count = notePortsCount,
    .get = getNotePorts,
};

fn notePortsCount(_: [*c]const clap.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    return if (is_input) 1 else 0;
}

fn getNotePorts(
    _: [*c]const clap.clap_plugin_t,
    index: u32,
    is_input: bool,
    info: [*c]clap.clap_note_port_info_t,
) callconv(.c) bool {
    if (!is_input or index != 0) return false;

    info.*.id = 0;
    info.*.supported_dialects = clap.CLAP_NOTE_DIALECT_CLAP;
    info.*.preferred_dialect = clap.CLAP_NOTE_DIALECT_CLAP;
    _ = std.fmt.bufPrintSentinel(
        &info.*.name[0],
        "Note Port",
        .{},
        0,
    ) catch return false;

    return true;
}

const extension_audio_ports: clap.clap_plugin_audio_ports_t = .{
    .count = audioPortsCount,
    .get = getAudioPorts,
};

fn audioPortsCount(_: [*c]const clap.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    return if (is_input) 0 else 1;
}

fn getAudioPorts(
    _: [*c]const clap.clap_plugin_t,
    index: u32,
    is_input: bool,
    info: [*c]clap.clap_audio_port_info_t,
) callconv(.c) bool {
    if (is_input or index != 0) return false;

    info.*.id = 0;
    info.*.channel_count = 2;
    info.*.flags = clap.CLAP_AUDIO_PORT_IS_MAIN;
    info.*.port_type = &clap.CLAP_PORT_STEREO;
    info.*.in_place_pair = clap.CLAP_INVALID_ID;
    _ = std.fmt.bufPrintSentinel(
        &info.*.name[0],
        "Audio Output",
        .{},
        0,
    ) catch return false;

    return true;
}

const extension_params: clap.clap_plugin_params_t = .{
    .count = extParamCount,
    .get_info = extParamGetInfo,
    .get_value = extParamGetValue,
    .value_to_text = extParamValueToText,
    .text_to_value = extParamTextToValue,
    .flush = extParamFlush,
};

fn extParamCount(_: [*c]const clap.clap_plugin_t) callconv(.c) u32 {
    return MyPlugin.parameter_count;
}

fn extParamGetInfo(
    _: [*c]const clap.clap_plugin_t,
    index: u32,
    info: [*c]clap.clap_param_info_t,
) callconv(.c) bool {
    if (index != @intFromEnum(MyPlugin.ParameterIndex.volume)) return false;

    info.* = .{};
    info.*.id = index;
    info.*.flags = clap.CLAP_PARAM_IS_AUTOMATABLE; // | clap.CLAP_PARAM_IS_MODULATABLE;
    info.*.min_value = 0.0;
    info.*.max_value = 1.0;
    info.*.default_value = 0.5;
    _ = std.fmt.bufPrintSentinel(&info.*.name[0], "Volume", .{}, 0) catch return false;

    return true;
}

/// This will be called on the main thread, so we need to communicate this info to the audio thread
fn extParamGetValue(clap_plugin: [*c]const clap.clap_plugin_t, index: u32, value: [*c]f64) callconv(.c) bool {
    if (index >= MyPlugin.parameter_count) return false;
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    plugin.parameter_mutex.lockUncancelable(plugin.io);
    defer plugin.parameter_mutex.unlock(plugin.io);

    value.* = @floatCast(if (plugin.changed_main[index]) plugin.parameters_main[index] else plugin.parameters[index]);
    return true;
}

fn extParamValueToText(
    _: [*c]const clap.clap_plugin_t,
    id: clap.clap_id,
    value: f64,
    display: [*c]u8,
    size: u32,
) callconv(.c) bool {
    if (id >= MyPlugin.parameter_count) return false;

    _ = std.fmt.bufPrintSentinel(display[0..size], "{}", .{value}, 0) catch return false;
    return true;
}

fn extParamTextToValue(
    _: [*c]const clap.clap_plugin_t,
    id: clap.clap_id,
    display: [*c]const u8,
    value: [*c]f64,
) callconv(.c) bool {
    // TODO
    _ = id;
    _ = display;
    _ = value;
    return false;
}

fn extParamFlush(
    clap_plugin: [*c]const clap.clap_plugin_t,
    in: [*c]const clap.clap_input_events_t,
    out: [*c]const clap.clap_output_events_t,
) callconv(.c) void {
    const plugin: *MyPlugin = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    const event_count = in.*.size.?(in);

    plugin.syncMainToAudio(out);
    for (0..event_count) |i| {
        plugin.processEvent(in.*.get.?(in, @intCast(i)));
    }
}

// ---MyPlugin---

const Voice = struct {
    held: bool,
    note_id: i32,
    channel: i16,
    key: i16,
    phase: f32,
};

const MyPlugin = struct {
    const max_voices = 8;
    const ParameterIndex = enum { volume, COUNT };
    const parameter_count = @intFromEnum(ParameterIndex.COUNT);

    allocator: std.mem.Allocator,
    io: std.Io,
    io_impl: std.Io.Threaded,

    plugin: clap.clap_plugin_t,
    host: *const clap.clap_host_t,

    sample_rate: f32,
    voices: std.ArrayList(Voice),
    voices_buffer: [max_voices]Voice = undefined,

    parameters: [parameter_count]f32,
    parameters_main: [parameter_count]f32,
    changed: [parameter_count]bool,
    changed_main: [parameter_count]bool,
    parameter_mutex: std.Io.Mutex,

    fn init(
        self: *@This(),
        clap_plugin: clap.clap_plugin_t,
        host: *const clap.clap_host_t,
    ) void {
        self.allocator = std.heap.smp_allocator;
        self.io_impl = .init_single_threaded;
        self.io = self.io_impl.io();

        self.plugin = clap_plugin;
        self.plugin.plugin_data = self;
        self.host = host;

        self.voices = .initBuffer(&self.voices_buffer);

        for (0..parameter_count) |i| {
            var info: clap.clap_param_info_t = .{};
            _ = extension_params.get_info.?(&self.plugin, @intCast(i), &info);
            self.parameters[i] = @floatCast(info.default_value);
            self.parameters_main[i] = @floatCast(info.default_value);
        }
        self.changed = [_]bool{false} ** parameter_count;
        self.changed_main = [_]bool{false} ** parameter_count;
        self.parameter_mutex = .init;
    }

    fn deinit(self: *@This()) void {
        self.io_impl.deinit();
    }

    fn processEvent(self: *@This(), event: *const clap.clap_event_header_t) void {
        if (event.space_id != clap.CLAP_CORE_EVENT_SPACE_ID) return;

        if (isNoteEventClap(event.type)) {
            self.handleNoteEvent(event);
        } else if (event.type == clap.CLAP_EVENT_PARAM_VALUE) {
            self.handleParamValueEvent(event);
        }
    }

    fn handleNoteEvent(self: *@This(), event: *const clap.clap_event_header_t) void {
        const note_event: *const clap.clap_event_note_t = @ptrCast(@alignCast(event));

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

        if (event.type == clap.CLAP_EVENT_NOTE_ON and self.voices.items.len < self.voices.capacity) {
            self.voices.appendAssumeCapacity(.{
                .held = true,
                .note_id = note_event.note_id,
                .channel = note_event.channel,
                .key = note_event.key,
                .phase = 0.0,
            });
        }
    }

    fn handleParamValueEvent(self: *@This(), event: *const clap.clap_event_header_t) void {
        const value_event: *const clap.clap_event_param_value_t = @ptrCast(@alignCast(event));
        const i = value_event.param_id;

        self.parameter_mutex.lockUncancelable(self.io);
        defer self.parameter_mutex.unlock(self.io);

        self.parameters[i] = @floatCast(value_event.value);
        self.changed[i] = true;
    }

    fn syncMainToAudio(self: *@This(), out: [*c]const clap.clap_output_events_t) void {
        self.parameter_mutex.lockUncancelable(self.io);
        defer self.parameter_mutex.unlock(self.io);

        for (0..parameter_count) |i| {
            if (self.changed_main[i] == false) continue;

            self.parameters[i] = self.parameters_main[i];
            self.changed_main[i] = false;

            const event: clap.clap_event_param_value_t = .{
                .header = .{
                    .size = @sizeOf(clap.clap_event_param_value_t),
                    .space_id = clap.CLAP_CORE_EVENT_SPACE_ID,
                    .type = clap.CLAP_EVENT_PARAM_VALUE,
                },
                .param_id = @intCast(i),
                .note_id = -1,
                .port_index = -1,
                .channel = -1,
                .key = -1,
                .value = self.parameters[i],
            };

            _ = out.*.try_push.?(out, &event.header);
        }
    }

    fn renderAudio(self: *@This(), start: u32, end: u32, outputL: [*]f32, outputR: [*]f32) void {
        const volume = self.parameters[@intFromEnum(ParameterIndex.volume)];

        var i: u32 = start;
        while (i < end) : (i += 1) {
            var sample: f32 = 0.0;

            for (self.voices.items) |*voice| {
                if (voice.held == false) continue;

                sample += @sin(voice.phase * 2.0 * 3.14159) * 0.2 * volume;

                const key_float: f32 = @floatFromInt(voice.key);
                voice.phase += 440.0 * std.math.exp2((key_float - 57.0) / 12.0) / self.sample_rate;
                voice.phase -= @floor(voice.phase);
            }

            outputL[i] = sample;
            outputR[i] = sample;
        }
    }
};

fn isNoteEventClap(event_type: u16) bool {
    return switch (event_type) {
        clap.CLAP_EVENT_NOTE_ON => true,
        clap.CLAP_EVENT_NOTE_OFF => true,
        clap.CLAP_EVENT_NOTE_CHOKE => true,
        else => false,
    };
}

test {
    var my_plugin: MyPlugin = undefined;
    my_plugin.init(plugin_class, undefined);
    defer my_plugin.deinit();

    const clap_process: clap.clap_process_t = .{
        .audio_outputs_count = 1,
        .in_events = dbg.initDummyInputEvents(),
    };

    const plugin = &my_plugin.plugin;
    try std.testing.expect(plugin.init.?(plugin));
    try std.testing.expect(plugin.activate.?(plugin, 48000.0, 0, 128));
    try std.testing.expectEqual(1, plugin.process.?(plugin, &clap_process));
    plugin.deactivate.?(plugin);
}
