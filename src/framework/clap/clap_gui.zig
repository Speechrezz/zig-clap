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

        mouse_dragging: bool = false,
        dragging_param: u32 = undefined,
        mouse_anchor_x: i32 = undefined,
        mouse_anchor_y: i32 = undefined,
        param_value_anchor: f64 = undefined,

        // gui: config.PluginGui,

        const slider_x = 10;
        const slider_y = 10;
        const slider_width = 80;
        const slider_height = 30;
        const slider_right = slider_x + slider_width;
        const slider_bottom = slider_y + slider_height;

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
            const fill_width: u32 = @round(slider_width * volume);
            self.paintRectangle(bits, slider_x, slider_y, slider_width, slider_height, 0x000000, 0xC0C0C0);
            self.paintRectangle(bits, slider_x, slider_y, fill_width, slider_height, 0x000000, 0x000000);
        }

        pub fn getSize(self: *const @This()) struct { u32, u32 } {
            return .{ self.width, self.height };
        }

        pub fn handleMouseMove(self: *@This(), x: i32, y: i32) void {
            _ = y;
            if (self.mouse_dragging) {
                const volume_parm = &self.processor.params.values.volume;

                var new_value = @as(f64, @floatFromInt(x - self.mouse_anchor_x)) * 0.01;
                new_value = std.math.clamp(self.param_value_anchor + new_value, 0.0, 1.0);

                volume_parm.setNormalizedValue(new_value);
                volume_parm.param.markDirtyFromMain();

                // TODO: Notify host to flush params
            }
        }

        pub fn handleMouseDown(self: *@This(), x: i32, y: i32) void {
            const volume_parm = &self.processor.params.values.volume;

            if (x >= slider_x and x < slider_right and y >= slider_y and y < slider_bottom) {
                self.mouse_dragging = true;
                self.dragging_param = volume_parm.param.id;
                self.mouse_anchor_x = x;
                self.mouse_anchor_y = y;
                self.param_value_anchor = volume_parm.getNormalizedValue();

                volume_parm.param.startGesture();

                // TODO: Notify host to flush params
            }
        }

        pub fn handleMouseUp(self: *@This()) void {
            const volume_parm = &self.processor.params.values.volume;

            if (self.mouse_dragging) {
                self.mouse_dragging = false;

                volume_parm.param.endGesture();

                // TODO: Notify host to flush params
            }
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
