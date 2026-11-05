const std = @import("std");
const builtin = @import("builtin");
const dbg = @import("debug_clap.zig");
const c = @import("c");

const ClapProcessor = @import("ClapProcessor.zig");

const clap_version: c.clap_version_t = .{
    .major = c.CLAP_VERSION_MAJOR,
    .minor = c.CLAP_VERSION_MINOR,
    .revision = c.CLAP_VERSION_REVISION,
};

// Returns `true` if the two C-Strings are equal
fn cStrEql(lhs: [*:0]const u8, rhs: [*:0]const u8) bool {
    return std.mem.orderZ(u8, lhs, rhs) == .eq;
}

// ---Entry---

export const clap_entry: c.clap_plugin_entry_t = .{
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
    const does_id_match = cStrEql(factory_id.?, &c.CLAP_PLUGIN_FACTORY_ID);
    if (!does_id_match) return null;

    return &plugin_factory;
}

// ---Factory---

const plugin_factory: c.clap_plugin_factory_t = .{
    .get_plugin_count = getPluginCount,
    .get_plugin_descriptor = getPluginDescriptor,
    .create_plugin = createPlugin,
};

fn getPluginCount(_: [*c]const c.clap_plugin_factory_t) callconv(.c) u32 {
    return 1;
}

fn getPluginDescriptor(
    _: [*c]const c.clap_plugin_factory_t,
    index: u32,
) callconv(.c) [*c]const c.clap_plugin_descriptor_t {
    if (index != 0)
        return null;

    return &plugin_descriptor;
}

fn createPlugin(
    _: [*c]const c.clap_plugin_factory_t,
    host: [*c]const c.clap_host_t,
    plugin_id: [*c]const u8,
) callconv(.c) [*c]const c.clap_plugin_t {
    const is_version_compatible = c.clap_version_is_compatible(host.*.clap_version);
    const is_id_matching = cStrEql(plugin_id.?, plugin_descriptor.id.?);
    if (!is_version_compatible or !is_id_matching) {
        return null;
    }

    const plugin = std.heap.c_allocator.create(ClapProcessor) catch return null;
    plugin.init(plugin_class, host) catch return null;
    return &plugin.clap_plugin;
}

const plugin_descriptor: c.clap_plugin_descriptor_t = .{
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
    c.CLAP_PLUGIN_FEATURE_INSTRUMENT,
    c.CLAP_PLUGIN_FEATURE_SYNTHESIZER,
    c.CLAP_PLUGIN_FEATURE_STEREO,
    null,
};

// ---Plugin Class---

const plugin_class: c.clap_plugin_t = .{
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

fn initPlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
    return true;
}

fn destroyPlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    plugin.deinit();
    std.heap.c_allocator.destroy(plugin);
}

fn activatePlugin(
    clap_plugin: [*c]const c.clap_plugin_t,
    sample_rate: f64,
    min_frames_count: u32,
    max_frames_count: u32,
) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    plugin.sample_rate = @floatCast(sample_rate);
    _ = min_frames_count;
    _ = max_frames_count;

    return true;
}

fn deactivatePlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn startProcessingPlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
    return true;
}

fn stopProcessingPlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn resetPlugin(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    _ = plugin;
}

fn processPlugin(
    clap_plugin: [*c]const c.clap_plugin_t,
    process: [*c]const c.clap_process_t,
) callconv(.c) c.clap_process_status {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

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

    return c.CLAP_PROCESS_CONTINUE;
}

fn getExtension(
    _: [*c]const c.clap_plugin_t,
    id: [*c]const u8,
) callconv(.c) ?*const anyopaque {
    if (cStrEql(id.?, &c.CLAP_EXT_NOTE_PORTS)) return &extension_note_ports;
    if (cStrEql(id.?, &c.CLAP_EXT_AUDIO_PORTS)) return &extension_audio_ports;
    if (cStrEql(id.?, &c.CLAP_EXT_PARAMS)) return &extension_params;
    if (cStrEql(id.?, &c.CLAP_EXT_STATE)) return &extension_plugin_state;

    return null;
}

fn onMainThread(_: [*c]const c.clap_plugin_t) callconv(.c) void {
    //
}

// ---Extensions---

const extension_note_ports: c.clap_plugin_note_ports_t = .{
    .count = notePortsCount,
    .get = getNotePorts,
};

fn notePortsCount(_: [*c]const c.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    return if (is_input) 1 else 0;
}

fn getNotePorts(
    _: [*c]const c.clap_plugin_t,
    index: u32,
    is_input: bool,
    info: [*c]c.clap_note_port_info_t,
) callconv(.c) bool {
    if (!is_input or index != 0) return false;

    info.*.id = 0;
    info.*.supported_dialects = c.CLAP_NOTE_DIALECT_CLAP;
    info.*.preferred_dialect = c.CLAP_NOTE_DIALECT_CLAP;
    _ = std.mem.printSentinel(
        &info.*.name,
        "Note Port",
        .{},
        0,
    ) catch return false;

    return true;
}

const extension_audio_ports: c.clap_plugin_audio_ports_t = .{
    .count = audioPortsCount,
    .get = getAudioPorts,
};

fn audioPortsCount(_: [*c]const c.clap_plugin_t, is_input: bool) callconv(.c) u32 {
    return if (is_input) 0 else 1;
}

fn getAudioPorts(
    _: [*c]const c.clap_plugin_t,
    index: u32,
    is_input: bool,
    info: [*c]c.clap_audio_port_info_t,
) callconv(.c) bool {
    if (is_input or index != 0) return false;

    info.*.id = 0;
    info.*.channel_count = 2;
    info.*.flags = c.CLAP_AUDIO_PORT_IS_MAIN;
    info.*.port_type = &c.CLAP_PORT_STEREO;
    info.*.in_place_pair = c.CLAP_INVALID_ID;
    _ = std.mem.printSentinel(
        &info.*.name,
        "Audio Output",
        .{},
        0,
    ) catch return false;

    return true;
}

const extension_params: c.clap_plugin_params_t = .{
    .count = extParamCount,
    .get_info = extParamGetInfo,
    .get_value = extParamGetValue,
    .value_to_text = extParamValueToText,
    .text_to_value = extParamTextToValue,
    .flush = extParamFlush,
};

fn extParamCount(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) u32 {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    return @intCast(plugin.processor.params.items.len);
}

fn extParamGetInfo(
    clap_plugin: [*c]const c.clap_plugin_t,
    index: u32,
    info: [*c]c.clap_param_info_t,
) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    if (index >= plugin.processor.params.items.len) return false;

    const param = &plugin.processor.params.items[index];

    info.* = std.mem.zeroes(c.clap_param_info_t);
    info.*.id = index;
    info.*.flags = c.CLAP_PARAM_IS_AUTOMATABLE; // | clap.CLAP_PARAM_IS_MODULATABLE;
    info.*.min_value = param.min_value;
    info.*.max_value = param.max_value;
    info.*.default_value = param.default_value;
    _ = std.mem.printSentinel(
        &info.*.name,
        "{s}",
        .{param.name},
        0,
    ) catch return false;

    return true;
}

/// This will be called on the main thread, so we need to communicate this info to the audio thread
fn extParamGetValue(clap_plugin: [*c]const c.clap_plugin_t, index: u32, value: [*c]f64) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    if (index >= plugin.processor.params.items.len) return false;

    value.* = plugin.processor.params.items[index].getValue();
    return true;
}

fn extParamValueToText(
    clap_plugin: [*c]const c.clap_plugin_t,
    id: c.clap_id,
    value: f64,
    display: [*c]u8,
    size: u32,
) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    if (id >= plugin.processor.params.items.len) return false;

    _ = std.mem.printSentinel(display[0..size], "{:.2}", .{value}, 0) catch return false;
    return true;
}

fn extParamTextToValue(
    _: [*c]const c.clap_plugin_t,
    id: c.clap_id,
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
    clap_plugin: [*c]const c.clap_plugin_t,
    in: [*c]const c.clap_input_events_t,
    out: [*c]const c.clap_output_events_t,
) callconv(.c) void {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
    const event_count = in.*.size.?(in);

    plugin.syncMainToAudio(out);
    for (0..event_count) |i| {
        plugin.processEvent(in.*.get.?(in, @intCast(i)));
    }
}

const extension_plugin_state: c.clap_plugin_state_t = .{
    .save = extStateSave,
    .load = extStateLoad,
};

fn extStateSave(
    clap_plugin: [*c]const c.clap_plugin_t,
    stream: [*c]const c.clap_ostream_t,
) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    // TODO: Move the serialization logic to ClapProcessor
    const param_count = plugin.processor.params.items.len;

    const buffer = plugin.allocator.alloc(f64, param_count) catch return false;
    defer plugin.allocator.free(buffer);

    for (plugin.processor.params.items, buffer) |*param, *out| {
        out.* = param.getValue();
    }

    const byte_count = @sizeOf(f64) * param_count;
    const result = stream.*.write.?(stream, buffer.ptr, byte_count);
    return result == byte_count;
}

fn extStateLoad(
    clap_plugin: [*c]const c.clap_plugin_t,
    stream: [*c]const c.clap_istream_t,
) callconv(.c) bool {
    const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

    // TODO: Move the serialization logic to ClapProcessor
    const param_count = plugin.processor.params.items.len;

    const buffer = plugin.allocator.alloc(f64, param_count) catch return false;
    defer plugin.allocator.free(buffer);

    const byte_count = @sizeOf(f64) * param_count;

    const result = stream.*.read.?(stream, buffer.ptr, byte_count);
    if (result != byte_count) return false;

    for (plugin.processor.params.items, buffer) |*param, value| {
        param.setValue(value);
    }

    return true;
}

test {
    var my_plugin: ClapProcessor = undefined;
    try my_plugin.init(plugin_class, undefined);
    defer my_plugin.deinit();

    var clap_process = std.mem.zeroes(c.clap_process_t);
    clap_process.audio_outputs_count = 1;
    clap_process.in_events = dbg.initDummyInputEvents();

    const plugin = &my_plugin.clap_plugin;
    try std.testing.expect(plugin.init.?(plugin));
    try std.testing.expect(plugin.activate.?(plugin, 48000.0, 0, 128));
    try std.testing.expectEqual(1, plugin.process.?(plugin, &clap_process));
    plugin.deactivate.?(plugin);
}
