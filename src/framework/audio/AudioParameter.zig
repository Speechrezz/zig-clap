const std = @import("std");

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
version: u32,
flags: u32 = 0,
name: []const u8,
min_value: f64,
max_value: f64,
default_value: f64,

normalized_value: std.atomic.Value(f64),

pub fn init(version: u32, name: []const u8, min_value: f64, max_value: f64, default_value: f64) @This() {
    return .{
        .version = version,
        .flags = @backingInt(Flags.IsAutomatable),
        .name = name,
        .min_value = min_value,
        .max_value = max_value,
        .default_value = default_value,
        .normalized_value = .init(default_value),
    };
}

pub fn setNormalizedValueUnchecked(self: *@This(), value: f64) void {
    self.normalized_value.store(value, .unordered);
}

pub fn setNormalizedValue(self: *@This(), value: f64) void {
    const clamped = std.math.clamp(value, self.min_value, self.max_value);
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

pub fn toNormalized(self: *const @This(), value: anytype) @TypeOf(value) {
    // TODO
    _ = self;
    return value;
}

pub fn fromNormalized(self: *const @This(), value: anytype) @TypeOf(value) {
    // TODO
    _ = self;
    return value;
}
