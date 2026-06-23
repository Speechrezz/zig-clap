const std = @import("std");
const Io = std.Io;

const clap = @cImport({
    @cInclude("clap/clap.h");
});

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
        clap.CLAP_VERSION_MAJOR,
        clap.CLAP_VERSION_MINOR,
        clap.CLAP_VERSION_REVISION,
    });
}

test {
    _ = @import("plugin.zig");
}
