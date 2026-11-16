const std = @import("std");

pub fn trimFloatString(text: []const u8) []const u8 {
    const number_chars = "0123456789+-.";

    const start = std.mem.findAny(u8, text, number_chars) orelse 0;
    const end = std.mem.findNonePos(u8, text, start, number_chars) orelse text.len;

    return text[start..end];
}

pub fn Basic(comptime T: type, comptime format: []const u8, comptime scale: comptime_float) type {
    return struct {
        pub fn textFromValue(value: T, buffer: []u8) ![]u8 {
            return std.mem.print(buffer, format, .{value * scale});
        }
        pub fn valueFromText(text: []const u8) !T {
            const trimmed = trimFloatString(text);

            const value = try std.fmt.parseFloat(T, trimmed);
            return value / scale;
        }
    };
}

pub fn Percent(comptime T: type) type {
    return Basic(T, "{:.1}%", 100.0);
}

pub fn Hertz(comptime T: type) type {
    return struct {
        pub fn textFromValue(value: T, buffer: []u8) ![]u8 {
            if (value < 1000.0) {
                return std.mem.print(buffer, "{:.1} Hz", .{value});
            } else {
                return std.mem.print(buffer, "{:.2} kHz", .{value / 1000.0});
            }
        }
        pub fn valueFromText(text: []const u8) !T {
            const trimmed = trimFloatString(text);
            const value = try std.fmt.parseFloat(T, trimmed);

            if (std.mem.findAny(u8, text, "Kk") == null) {
                return value;
            } else {
                return value * 1000.0;
            }
        }
    };
}

pub fn Seconds(comptime T: type) type {
    return struct {
        pub fn textFromValue(value: T, buffer: []u8) ![]u8 {
            if (value >= 1.0) {
                return std.mem.print(buffer, "{:.2} sec", .{value});
            } else {
                return std.mem.print(buffer, "{:.1} ms", .{value * 1000.0});
            }
        }

        pub fn valueFromText(text: []const u8) !T {
            const trimmed = trimFloatString(text);
            const value = try std.fmt.parseFloat(T, trimmed);

            const found_ms = std.mem.find(u8, text, "ms") != null;

            if (found_ms) {
                return value / 1000.0;
            } else {
                return value;
            }
        }
    };
}

pub fn Milliseconds(comptime T: type) type {
    return struct {
        pub fn textFromValue(value: T, buffer: []u8) ![]u8 {
            if (value < 1000.0) {
                return std.mem.print(buffer, "{:.1} ms", .{value});
            } else {
                return std.mem.print(buffer, "{:.2} sec", .{value / 1000.0});
            }
        }
        pub fn valueFromText(text: []const u8) !T {
            const trimmed = trimFloatString(text);
            const value = try std.fmt.parseFloat(T, trimmed);

            const found_ms = std.mem.find(u8, text, "ms") != null;
            const found_s = std.mem.findScalar(u8, text, 's') != null;

            if (found_ms or !found_s) {
                return value;
            } else {
                return value * 1000.0;
            }
        }
    };
}

const tolerance = 1e-5;

test Basic {
    var buffer: [32]u8 = @splat(0);

    const Formatter = Percent(f64);
    try std.testing.expectEqualStrings("31.4%", try Formatter.textFromValue(0.314, &buffer));
    try std.testing.expectApproxEqRel(0.314, try Formatter.valueFromText("31.4%"), tolerance);
}

test Hertz {
    var buffer: [32]u8 = @splat(0);

    const Formatter = Hertz(f64);

    try std.testing.expectEqualStrings("123.4 Hz", try Formatter.textFromValue(123.4, &buffer));
    try std.testing.expectEqualStrings("12.34 kHz", try Formatter.textFromValue(12_340.0, &buffer));

    try std.testing.expectApproxEqRel(123.4, try Formatter.valueFromText("123.4 Hz"), tolerance);
    try std.testing.expectApproxEqRel(12_340.0, try Formatter.valueFromText("12.34 k"), tolerance);
}

test Seconds {
    var buffer: [32]u8 = @splat(0);

    const Formatter = Seconds(f64);

    try std.testing.expectEqualStrings("123.4 ms", try Formatter.textFromValue(0.1234, &buffer));
    try std.testing.expectEqualStrings("12.34 sec", try Formatter.textFromValue(12.34, &buffer));

    try std.testing.expectApproxEqRel(0.1234, try Formatter.valueFromText("0.1234"), tolerance);
    try std.testing.expectApproxEqRel(0.1234, try Formatter.valueFromText("123.4 ms"), tolerance);
    try std.testing.expectApproxEqRel(12.34, try Formatter.valueFromText("12.34 s"), tolerance);
}

test Milliseconds {
    var buffer: [32]u8 = @splat(0);

    const Formatter = Milliseconds(f64);

    try std.testing.expectEqualStrings("123.4 ms", try Formatter.textFromValue(123.4, &buffer));
    try std.testing.expectEqualStrings("12.34 sec", try Formatter.textFromValue(12_340.0, &buffer));

    try std.testing.expectApproxEqRel(123.4, try Formatter.valueFromText("123.4"), tolerance);
    try std.testing.expectApproxEqRel(123.4, try Formatter.valueFromText("123.4 ms"), tolerance);
    try std.testing.expectApproxEqRel(12_340.0, try Formatter.valueFromText("12.34 s"), tolerance);
}
