const std = @import("std");
const Io = std.Io;

const c = @import("c");
const framework = @import("framework");
const PluginProcessor = @import("PluginProcessor.zig");

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // CLAP
    std.debug.print("CLAP version: {}.{}.{}\n", .{
        c.CLAP_VERSION_MAJOR,
        c.CLAP_VERSION_MINOR,
        c.CLAP_VERSION_REVISION,
    });
}

const Plugin = framework.ClapApi(
    PluginProcessor,
    .{
        .descriptor = .{
            .id = "xynth.ZigClap",
            .name = "ZigClap",
            .vendor = "Xynth Audio",
            .url = "https://www.xynth.audio/",
            .manual_url = "https://github.com/Speechrezz/zig-clap",
            .support_url = "https://github.com/Speechrezz/zig-clap",
            .version = "0.0.1",
            .description = "A plugin made using Zig and the CLAP SDK.",
            .features = &.{
                c.CLAP_PLUGIN_FEATURE_INSTRUMENT,
                c.CLAP_PLUGIN_FEATURE_SYNTHESIZER,
                c.CLAP_PLUGIN_FEATURE_STEREO,
            },
        },
    },
);

export var clap_entry = Plugin.clap_entry;

test {
    _ = PluginProcessor;
}

test "CLAP API" {
    try std.testing.expect(clap_entry.init.?(""));
    defer clap_entry.deinit.?();

    const factory_maybe = clap_entry.get_factory.?(&c.CLAP_PLUGIN_FACTORY_ID);
    try std.testing.expect(factory_maybe != null);
    const factory: *const c.clap_plugin_factory_t = @ptrCast(@alignCast(factory_maybe.?));

    const clap_host: c.clap_host_t = .{
        .clap_version = .{
            .major = c.CLAP_VERSION_MAJOR,
            .minor = c.CLAP_VERSION_MINOR,
            .revision = c.CLAP_VERSION_REVISION,
        },
        .host_data = null,
        .name = "Test host",
        .vendor = "Test vendor",
        .url = null,
        .version = null,
        .get_extension = null,
        .request_restart = null,
        .request_process = null,
        .request_callback = null,
    };

    try std.testing.expectEqual(1, factory.get_plugin_count.?(factory));
    const descriptor = &factory.get_plugin_descriptor.?(factory, 0).*;

    const plugin = &factory.create_plugin.?(factory, &clap_host, descriptor.id).*;
    try std.testing.expect(plugin.init.?(plugin));
    defer plugin.destroy.?(plugin);

    try std.testing.expect(plugin.activate.?(plugin, 44100.0, 1, 256));

    const params_maybe = plugin.get_extension.?(plugin, &c.CLAP_EXT_PARAMS);
    const params: *const c.clap_plugin_params_t = @ptrCast(@alignCast(params_maybe.?));

    const count = params.count.?(plugin);

    for (0..count) |i| {
        var info: c.clap_param_info_t = undefined;
        try std.testing.expect(params.get_info.?(plugin, @intCast(i), &info));

        // std.debug.print("info: {}, {s}, {}, {}, {}\n", .{
        //     info.id,
        //     info.name,
        //     info.min_value,
        //     info.max_value,
        //     info.default_value,
        // });
    }
}
