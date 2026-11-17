const std = @import("std");
const c = @import("c");

pub fn ExtNotePorts(comptime ClapProcessor: type) type {
    _ = ClapProcessor;

    return struct {
        pub const extension: c.clap_plugin_note_ports_t = .{
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
    };
}
