const std = @import("std");
const builtin = @import("builtin");
const c = @import("c");
const Config = @import("Config.zig");

pub fn ClapGui(comptime config: Config) type {
    return struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        processor: *config.PluginProcessor,

        width: u32 = 300,
        height: u32 = 200,

        // gui: config.PluginGui,

        pub fn init(self: *@This(), allocator: std.mem.Allocator, io: std.Io, processor: *config.PluginProcessor) void {
            self.* = .{
                .allocator = allocator,
                .io = io,
                .processor = processor,
            };
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
            // TODO:
        }

        pub fn paint(self: *@This(), bits: []u32) void {
            // Background
            self.paintRectangle(bits, 0, 0, self.width, self.height, 0xC0C0C0, 0xC0C0C0);

            // Slider for volume
            const volume = self.processor.params.values.volume.getNormalizedValue();
            const slider_width = 80;
            const fill_width: u32 = @round(slider_width * volume);
            self.paintRectangle(bits, 10, 10, slider_width, 30, 0x000000, 0xC0C0C0);
            self.paintRectangle(bits, 10, 10, fill_width, 30, 0x000000, 0x000000);
        }

        pub fn getSize(self: *const @This()) struct { u32, u32 } {
            return .{ self.width, self.height };
        }

        pub fn handleMouseMove(self: *@This(), x: i32, y: i32) void {
            _ = self;
            _ = x;
            _ = y;
            // TODO
        }

        pub fn handleMouseDown(self: *@This(), x: i32, y: i32) void {
            _ = self;
            _ = x;
            _ = y;
            // TODO
        }

        pub fn handleMouseUp(self: *@This()) void {
            _ = self;
            // TODO
        }

        // TEMP HELPER FUNCTIONS
        fn paintRectangle(self: *@This(), bits: []u32, x: u32, y: u32, width: u32, height: u32, border: u32, fill: u32) void {
            const right = x + width;
            const bottom = y + height;

            std.debug.assert(right <= self.width);
            std.debug.assert(bottom <= self.height);
            std.debug.assert(bits.len >= self.width * self.height);

            for (y..bottom) |j| {
                for (x..right) |i| {
                    const idx: usize = i + j * @as(usize, @intCast(self.width));
                    bits[idx] = if (i == x or i == right - 1 or j == y or j == bottom - 1) border else fill;
                }
            }
        }
    };
}
