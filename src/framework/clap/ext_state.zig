const std = @import("std");
const c = @import("c");

pub fn ExtState(comptime ClapProcessor: type) type {
    return struct {
        pub const extension: c.clap_plugin_state_t = .{
            .save = stateSave,
            .load = stateLoad,
        };

        fn stateSave(
            clap_plugin: [*c]const c.clap_plugin_t,
            stream: [*c]const c.clap_ostream_t,
        ) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

            return plugin.saveState(@ptrCast(stream));
        }

        fn stateLoad(
            clap_plugin: [*c]const c.clap_plugin_t,
            stream: [*c]const c.clap_istream_t,
        ) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

            return plugin.loadState(@ptrCast(stream));
        }
    };
}
