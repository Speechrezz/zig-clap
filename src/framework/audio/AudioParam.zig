const std = @import("std");
const formatting = @import("../fmt/value_formatting.zig");

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
default_value_norm: f64,

normalized_value: std.atomic.Value(f64),

dirty_from_main: std.atomic.Value(bool) = .init(false), // Value was changed on main thread
dirty_from_audio: std.atomic.Value(bool) = .init(false), // Value was changed on audio thread

gesture_started: std.atomic.Value(bool) = .init(false),
gesture_ended: std.atomic.Value(bool) = .init(false),

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

pub fn markDirtyFromMain(self: *@This()) void {
    self.dirty_from_main.store(true, .release);
}

pub fn consumeDirtyFromMain(self: *@This()) bool {
    if (!self.dirty_from_main.load(.acquire)) return false;

    self.dirty_from_main.store(false, .release);
    return true;
}

pub fn markDirtyFromAudio(self: *@This()) void {
    self.dirty_from_audio.store(true, .release);
}

pub fn consumeDirtyFromAudio(self: *@This()) bool {
    if (!self.dirty_from_audio.load(.acquire)) return false;

    self.dirty_from_audio.store(false, .release);
    return true;
}

pub fn startGesture(self: *@This()) void {
    self.gesture_started.store(true, .release);
}

pub fn consumeGestureStarted(self: *@This()) bool {
    if (!self.gesture_started.load(.acquire)) return false;

    self.gesture_started.store(false, .release);
    return true;
}

pub fn endGesture(self: *@This()) void {
    self.gesture_ended.store(true, .release);
}

pub fn consumeGestureEnded(self: *@This()) bool {
    if (!self.gesture_ended.load(.acquire)) return false;

    self.gesture_ended.store(false, .release);
    return true;
}

// ---Param types---

pub fn Float(comptime spec: struct {
    version: comptime_int,
    name: []const u8,
    Range: type,
    default_value: comptime_float,
    Formatter: type = formatting.Basic(f64, "{:.2}", 1.0),
}) type {
    const default_value_norm = spec.Range.toNormalized(spec.default_value);

    return struct {
        pub const version: comptime_int = spec.version;
        pub const Range = spec.Range;
        pub const Formatter = spec.Formatter;

        param: AudioParam,

        pub fn init(self: *@This()) void {
            self.* = .{
                .param = .{
                    .name = spec.name,
                    .min_value = Range.lower,
                    .max_value = Range.upper,
                    .default_value = spec.default_value,
                    .default_value_norm = default_value_norm,
                    .normalized_value = .init(default_value_norm),
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

            return spec.Range.toNormalized(value);
        }

        pub fn fromNormalizedErased(ptr: *const anyopaque, value: f64) f64 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return spec.Range.fromNormalized(value);
        }

        pub fn textFromValueErased(ptr: *const anyopaque, value: f64, buffer: []u8) ?[]u8 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return Formatter.textFromValue(value, buffer) catch return null;
        }

        pub fn valueFromTextErased(ptr: *const anyopaque, text: []const u8) ?f64 {
            // TODO: This is a temporary implementation
            const self: *const @This() = @ptrCast(@alignCast(ptr));
            _ = self;

            return Formatter.valueFromText(text) catch return null;
        }

        // --Shared methods--
        // TODO: Move this into a shared place

        pub fn getNormalizedValue(self: *const @This()) f64 {
            return self.param.normalized_value.load(.unordered);
        }

        pub fn getValue(self: *const @This()) f64 {
            return Range.fromNormalized(self.getNormalizedValue());
        }

        pub fn setNormalizedValue(self: *@This(), value: f64) void {
            self.param.normalized_value.store(value, .unordered);
        }

        pub fn setValue(self: *@This(), value: f64) void {
            self.setNormalizedValue(Range.toNormalized(value));
        }
    };
}

test "Float" {
    const normalizable = @import("../math/normalizable.zig");

    var param1: Float(.{
        .version = 1,
        .name = "Volume",
        .Range = normalizable.Linear(f64, 0.0, 100.0),
        .default_value = 50.0,
    }) = undefined;

    param1.init();
}
