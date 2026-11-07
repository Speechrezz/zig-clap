const std = @import("std");

pub const BinaryStreamOut = struct {
    data: std.ArrayList(u8) = .empty,

    pub fn init() @This() {
        return .{};
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
    }

    pub fn appendBytes(self: *@This(), allocator: std.mem.Allocator, data: []const u8) !void {
        try self.data.appendSlice(allocator, data);
    }

    pub fn appendValue(self: *@This(), allocator: std.mem.Allocator, value: anytype) !void {
        const bytes = std.mem.toBytes(value);
        try self.appendBytes(allocator, &bytes);
    }
};

pub const BinaryStreamIn = struct {
    data: []const u8,
    read_pos: usize = 0,

    pub fn init(data: []const u8) @This() {
        return .{
            .data = data,
        };
    }

    pub fn reset(self: *@This()) void {
        self.read_pos = 0;
    }

    pub fn getRemainingCount(self: @This()) usize {
        std.debug.assert(self.read_pos <= self.data.len);
        return self.data.len - self.read_pos;
    }

    pub fn readBytes(self: *@This(), byte_count: usize) []const u8 {
        std.debug.assert(self.getRemainingCount() >= byte_count);

        const out = self.data[self.read_pos .. self.read_pos + byte_count];

        self.read_pos += byte_count;
        return out;
    }

    pub fn readValue(self: *@This(), comptime T: type) T {
        const byte_count = @sizeOf(T);
        const bytes = self.readBytes(byte_count);

        return std.mem.bytesToValue(T, bytes);
    }
};

test {
    const allocator = std.testing.allocator;

    const test_data = "awesome sauce";
    const test_value: f64 = 3.14;

    var out: BinaryStreamOut = .init();
    defer out.deinit(allocator);

    try out.appendBytes(allocator, test_data);
    try out.appendValue(allocator, test_value);

    var in: BinaryStreamIn = .init(out.data.items);
    try std.testing.expectEqualStrings(test_data, in.readBytes(test_data.len));
    try std.testing.expectApproxEqRel(test_value, in.readValue(f64), 1e-5);
}
