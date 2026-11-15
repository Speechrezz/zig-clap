pub const AudioBuffer = @import("AudioBuffer.zig");
pub const AudioParam = @import("AudioParam.zig");
pub const AudioParamContainer = @import("audio_param_container.zig").AudioParamContainer;
pub const AudioSlice = @import("AudioSlice.zig");

pub const ProcessSpec = struct {
    sample_rate: f64,
    num_channels: u32,
    block_size: u32,
};

test {
    _ = AudioBuffer;
    _ = AudioParam;
    _ = AudioParamContainer;
    _ = AudioSlice;
}
