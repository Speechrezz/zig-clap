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

id: u32,
flags: u32 = 0,
name: []const u8,
min_value: f64,
max_value: f64,
default_value: f64,

value: std.atomic.Value(f64),

pub fn init(id: u32, name: []const u8, min_value: f64, max_value: f64, default_value: f64) @This() {
    return .{
        .id = id,
        .flags = @backingInt(Flags.IsAutomatable),
        .name = name,
        .min_value = min_value,
        .max_value = max_value,
        .default_value = default_value,
        .value = .init(default_value),
    };
}

pub fn setValueUnchecked(self: *@This(), value: f64) void {
    self.value.store(value, .unordered);
}

pub fn setValue(self: *@This(), value: f64) void {
    self.setValueUnchecked(std.math.clamp(value, self.min_value, self.max_value));
}

pub fn getValue(self: *const @This()) f64 {
    return self.value.load(.unordered);
}
