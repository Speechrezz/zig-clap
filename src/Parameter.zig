const std = @import("std");
const c = @import("c");

const Flags = enum(usize) {
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
flags: usize = 0,
name: []const u8,
min_value: f64,
max_value: f64,
default_value: f64,

current_value: f64 = 0.0,
