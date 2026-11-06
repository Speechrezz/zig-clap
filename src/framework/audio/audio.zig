pub const AudioBuffer = @import("AudioBuffer.zig");
pub const AudioSlice = @import("AudioSlice.zig");

pub const ProcessSpec = struct {
    sample_rate: f64,
    num_channels: u32,
    block_size: u32,
};

test {
    _ = AudioBuffer;
    _ = AudioSlice;
}
