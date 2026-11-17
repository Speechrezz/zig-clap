const std = @import("std");
const c = @import("c");

pub fn ExtAudioPorts(comptime ClapProcessor: type) type {
    _ = ClapProcessor;

    return struct {
        pub const extension: c.clap_plugin_audio_ports_t = .{
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
    };
}
