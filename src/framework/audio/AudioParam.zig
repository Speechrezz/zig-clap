const std = @import("std");

const AudioParam = @This();

pub const Flags = enum(u32) {
    IsStepped = 1 << 0,
    IsPeriodic = 1 << 1,
    IsHidden = 1 << 2,
    IsReadOnly = 1 << 3,
    IsBypass = 1 << 4,
    IsAutomatable = 1 << 5,
    isAutomatablePerNote = 1 << 6,
    IsAutomatablePerKey = 1 << 7,
    IsAutomatablePerChannel = 1 << 8,
    IsAutomatablePerPort = 1 << 9,
    IsModulatable = 1 << 10,
    IsModulatablePerNote = 1 << 11,
    IsModulatablePerKey = 1 << 12,
    IsModulatablePerChannel = 1 << 13,
    IsModulatablePerPort = 1 << 14,
    RequiresProcess = 1 << 15,
    IsEnum = 1 << 16,
};

id: u32 = undefined,
flags: u32 = @backingInt(Flags.IsAutomatable),
name: []const u8,
min_value: f64,
max_value: f64,
default_value: f64,

normalized_value: std.atomic.Value(f64),

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    toNormalized: *const fn (*const anyopaque, value: f64) f64,
    fromNormalized: *const fn (*const anyopaque, norm: f64) f64,

    textFromValue: *const fn (*const anyopaque, value: f64, buffer: []u8) ?[]u8,
    valueFromText: *const fn (*const anyopaque, text: []const u8) ?f64,
};

pub fn setNormalizedValueUnchecked(self: *@This(), value: f64) void {
    self.normalized_value.store(value, .unordered);
}

pub fn setNormalizedValue(self: *@This(), value: f64) void {
    const clamped = std.math.clamp(value, 0.0, 1.0);
    self.setNormalizedValueUnchecked(clamped);
}

pub fn setValue(self: *@This(), value: f64) void {
    self.setNormalizedValue(self.toNormalized(value));
}

pub fn getNormalizedValue(self: *const @This()) f64 {
    return self.normalized_value.load(.unordered);
}

pub fn getValue(self: *const @This()) f64 {
    return self.fromNormalized(self.getNormalizedValue());
}

pub fn toNormalized(self: *const @This(), value: f64) f64 {
    return self.vtable.toNormalized(self.ptr, value);
}

pub fn fromNormalized(self: *const @This(), norm: f64) f64 {
    return self.vtable.fromNormalized(self.ptr, norm);
}

pub fn textFromValue(self: *const @This(), value: f64, buffer: []u8) ?[]u8 {
    return self.vtable.textFromValue(self.ptr, value, buffer);
}

pub fn valueFromText(self: *const @This(), text: []const u8) ?f64 {
    return self.vtable.valueFromText(self.ptr, text);
}

// ---Param types---

pub fn Float(
    comptime param_version: comptime_int,
    comptime name: []const u8,
    comptime Range: type,
    comptime default_value: comptime_float,
) type {
    return struct {
        pub const version: comptime_int = param_version;

        param: AudioParam,

        pub fn init(self: *@This()) void {
            self.* = .{
                .param = .{
                    .name = name,
                    .min_value = Range.lower,
                    .max_value = Range.upper,
                    .default_value = default_value,
                    .normalized_value = .init(Range.toNormalized(default_value)),
                    .ptr = self,
                    .vtable = &.{
                        .toNormalized = toNormalizedErased,
                        .fromNormalized = fromNormalizedErased,
                        .textFromValue = textFromValueErased,
                        .valueFromText = valueFromTextErased,
                    },
                },
            };
        }

        // --Custom methods--

        pub fn toNormalizedErased(ptr: *const anyopaque, value: f64) f64 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return Range.toNormalized(value);
        }

        pub fn fromNormalizedErased(ptr: *const anyopaque, value: f64) f64 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return Range.fromNormalized(value);
        }

        pub fn textFromValueErased(ptr: *const anyopaque, value: f64, buffer: []u8) ?[]u8 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return std.mem.print(buffer, "{:.2}", .{value}) catch return null;
        }

        pub fn valueFromTextErased(ptr: *const anyopaque, text: []const u8) ?f64 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return std.fmt.parseFloat(f64, text) catch return null;
        }

        // --Shared methods--
        // TODO: Move this into a shared place

        pub fn getNormalizedValue(self: *const @This()) f64 {
            return self.param.normalized_value.load(.unordered);
        }

        pub fn getValue(self: *const @This()) f64 {
            return Range.fromNormalized(self.getNormalizedValue());
        }
    };
}

test "Float" {
    const normalizable = @import("../math/normalizable.zig");

    var param1: Float(
        1,
        "Volume",
        normalizable.Linear(f64, 0.0, 100.0),
        50.0,
    ) = undefined;

    param1.init();
}
