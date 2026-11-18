const builtin = @import("builtin");
const Config = @import("../Config.zig");

pub fn Gui(comptime config: Config) type {
    switch (builtin.target.os.tag) {
        .windows => return @import("win32.zig").Gui(config),
        else => @compileError("Unsupported OS"),
    }
}
