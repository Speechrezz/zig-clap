const std = @import("std");
const Io = std.Io;

const c = @import("c");
const framework = @import("framework/framework.zig");
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

const ClapApi = @import("framework/clap/clap_api.zig").ClapApi;
const Plugin = ClapApi(
    PluginProcessor,
    .{
        .id = "xynth.ZigClap",
        .name = "ZigClap",
        .vendor = "Xynth Audio",
        .url = "https://www.xynth.audio/",
        .manual_url = "https://github.com/Speechrezz/zig-clap",
        .support_url = "https://github.com/Speechrezz/zig-clap",
        .version = "0.0.1",
        .description = "A plugin made using Zig and the CLAP SDK.",
    },
);

export var clap_entry = Plugin.clap_entry;

test {
    _ = framework;
    _ = PluginProcessor;
}
