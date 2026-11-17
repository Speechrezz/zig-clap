const std = @import("std");
const c = @import("c");

pub fn ExtParams(comptime ClapProcessor: type) type {
    return struct {
        pub const extension: c.clap_plugin_params_t = .{
            .count = extParamCount,
            .get_info = extParamGetInfo,
            .get_value = extParamGetValue,
            .value_to_text = extParamValueToText,
            .text_to_value = extParamTextToValue,
            .flush = extParamFlush,
        };

        fn extParamCount(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) u32 {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            return plugin.getParamCount();
        }

        fn extParamGetInfo(
            clap_plugin: [*c]const c.clap_plugin_t,
            index: u32,
            info: [*c]c.clap_param_info_t,
        ) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            const param = plugin.getParamAtIndex(index) orelse return false;

            info.* = std.mem.zeroes(c.clap_param_info_t);
            info.*.id = param.id;
            info.*.flags = param.flags;
            info.*.min_value = 0.0;
            info.*.max_value = 1.0;
            info.*.default_value = param.default_value_norm;
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
            const param = plugin.getParamAtIndex(index) orelse return false;

            value.* = param.getNormalizedValue();
            return true;
        }

        fn extParamValueToText(
            clap_plugin: [*c]const c.clap_plugin_t,
            id: c.clap_id,
            normalized_value: f64,
            display: [*c]u8,
            size: u32,
        ) callconv(.c) bool {
            std.debug.assert(size > 0);

            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            const param = plugin.getParamWithId(id) orelse return false;
            const value = param.fromNormalized(normalized_value);

            if (param.textFromValue(value, display[0 .. size - 1])) |text| {
                display[text.len] = 0; // Add null terminator
                return true;
            } else {
                display[size - 1] = 0; // Add null terminator
                return false;
            }
        }

        fn extParamTextToValue(
            clap_plugin: [*c]const c.clap_plugin_t,
            id: c.clap_id,
            display: [*c]const u8,
            value: [*c]f64,
        ) callconv(.c) bool {
            std.debug.assert(display != null);

            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            const param = plugin.getParamWithId(id) orelse return false;

            const text = std.mem.span(display);
            value.* = param.valueFromText(text) orelse return false;
            value.* = param.toNormalized(value.*);

            return true;
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
                plugin.processEvent(in.*.get.?(in, @intCast(i))) catch @panic("Out of memory");
            }
        }
    };
}
