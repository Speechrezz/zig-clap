const std = @import("std");
const builtin = @import("builtin");
const dbg = @import("debug_clap.zig");
const c = @import("c");
const c_str = @import("c_str.zig");

const ExtNotePorts = @import("ext_note_ports.zig").ExtNotePorts;
const ExtAudioPorts = @import("ext_audio_ports.zig").ExtAudioPorts;
const ExtParams = @import("ext_params.zig").ExtParams;
const ExtState = @import("ext_state.zig").ExtState;
const ExtGui = @import("ext_gui.zig").ExtGui;

pub const Config = @import("Config.zig");

const clap_version: c.clap_version_t = .{
    .major = c.CLAP_VERSION_MAJOR,
    .minor = c.CLAP_VERSION_MINOR,
    .revision = c.CLAP_VERSION_REVISION,
};

pub fn ClapApi(comptime config: Config) type {
    const ClapProcessor = @import("clap_processor.zig").ClapProcessor(config);

    return struct {

        // ---Entry---

        pub const clap_entry: c.clap_plugin_entry_t = .{
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
            const does_id_match = c_str.isEql(factory_id.?, &c.CLAP_PLUGIN_FACTORY_ID);
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
            const is_id_matching = c_str.isEql(plugin_id.?, plugin_descriptor.id.?);
            if (!is_version_compatible or !is_id_matching) {
                return null;
            }

            const plugin = std.heap.c_allocator.create(ClapProcessor) catch return null;
            plugin.init(plugin_class, host) catch return null;
            return &plugin.clap_plugin;
        }

        const plugin_descriptor: c.clap_plugin_descriptor_t = .{
            .clap_version = clap_version,
            .id = config.descriptor.id.ptr,
            .name = config.descriptor.name.ptr,
            .vendor = config.descriptor.vendor.ptr,
            .url = config.descriptor.url.ptr,
            .manual_url = config.descriptor.manual_url.ptr,
            .support_url = config.descriptor.support_url.ptr,
            .version = config.descriptor.version.ptr,
            .description = config.descriptor.description.ptr,
            .features = config.descriptor.features.ptr,
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

            plugin.prepare(sample_rate, min_frames_count, max_frames_count) catch return false;
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

            var i: u32 = 0;
            while (i < input_event_count) : (i += 1) {
                const event = process.*.in_events.*.get.?(process.*.in_events, i);
                plugin.processEvent(event) catch return c.CLAP_PROCESS_ERROR;
            }

            const audio_output = process.*.audio_outputs[0];
            const channels = audio_output.data32[0..audio_output.channel_count];
            plugin.processBlock(0, frame_count, @ptrCast(channels));

            plugin.note_events.clearRetainingCapacity();

            return c.CLAP_PROCESS_CONTINUE;
        }

        fn getExtension(
            _: [*c]const c.clap_plugin_t,
            id: [*c]const u8,
        ) callconv(.c) ?*const anyopaque {
            if (c_str.isEql(id.?, &c.CLAP_EXT_NOTE_PORTS)) return &ext_note_ports;
            if (c_str.isEql(id.?, &c.CLAP_EXT_AUDIO_PORTS)) return &ext_audio_ports;
            if (c_str.isEql(id.?, &c.CLAP_EXT_PARAMS)) return &ext_params;
            if (c_str.isEql(id.?, &c.CLAP_EXT_STATE)) return &ext_plugin_state;
            if (c_str.isEql(id.?, &c.CLAP_EXT_GUI)) return &ext_gui;

            return null;
        }

        fn onMainThread(_: [*c]const c.clap_plugin_t) callconv(.c) void {
            //
        }

        // ---Extensions---

        const ext_note_ports = ExtNotePorts(ClapProcessor).extension;
        const ext_audio_ports = ExtAudioPorts(ClapProcessor).extension;
        const ext_params = ExtParams(ClapProcessor).extension;
        const ext_plugin_state = ExtState(ClapProcessor).extension;
        const ext_gui = ExtGui(config).extension;

        // ---Tests---

        test {
            const allocator = std.testing.allocator;

            var my_plugin: ClapProcessor = undefined;
            try my_plugin.init(plugin_class, undefined);
            defer my_plugin.deinit();

            var channels: [2][1]f32 = .{ .{0.0}, .{0.0} };

            var clap_process = std.mem.zeroes(c.clap_process_t);
            clap_process.audio_outputs = try allocator.create(c.clap_audio_buffer_t);
            defer allocator.destroy(&clap_process.audio_outputs[0]);

            clap_process.frames_count = 0;
            clap_process.audio_outputs_count = 1;
            clap_process.audio_outputs.*.channel_count = 2;
            clap_process.audio_outputs.*.data32 = @ptrCast(@alignCast(&channels));
            clap_process.in_events = dbg.initDummyInputEvents();

            const plugin = &my_plugin.clap_plugin;
            try std.testing.expect(plugin.init.?(plugin));
            try std.testing.expect(plugin.activate.?(plugin, 48000.0, 0, 128));
            try std.testing.expectEqual(1, plugin.process.?(plugin, &clap_process));
            plugin.deactivate.?(plugin);
        }
    };
}
