const std = @import("std");
const c = @import("c");

pub const Flags = enum(usize) {
    IsStepped = c.CLAP_PARAM_IS_STEPPED,
    IsPeriodic = c.CLAP_PARAM_IS_PERIODIC,
    IsHidden = c.CLAP_PARAM_IS_HIDDEN,
    IsReadOnly = c.CLAP_PARAM_IS_READONLY,
    IsBypass = c.CLAP_PARAM_IS_BYPASS,
    IsAutomatable = c.CLAP_PARAM_IS_AUTOMATABLE,
    isAutomatablePerNote = c.CLAP_PARAM_IS_AUTOMATABLE_PER_NOTE_ID,
    IsAutomatablePerKey = c.CLAP_PARAM_IS_AUTOMATABLE_PER_KEY,
    IsAutomatablePerChannel = c.CLAP_PARAM_IS_AUTOMATABLE_PER_CHANNEL,
    IsAutomatablePerPort = c.CLAP_PARAM_IS_AUTOMATABLE_PER_PORT,
    IsModulatable = c.CLAP_PARAM_IS_MODULATABLE,
    IsModulatablePerNote = c.CLAP_PARAM_IS_MODULATABLE_PER_NOTE_ID,
    IsModulatablePerKey = c.CLAP_PARAM_IS_MODULATABLE_PER_KEY,
    IsModulatablePerChannel = c.CLAP_PARAM_IS_MODULATABLE_PER_CHANNEL,
    IsModulatablePerPort = c.CLAP_PARAM_IS_MODULATABLE_PER_PORT,
    RequiresProcess = c.CLAP_PARAM_REQUIRES_PROCESS,
    IsEnum = c.CLAP_PARAM_IS_ENUM,
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
