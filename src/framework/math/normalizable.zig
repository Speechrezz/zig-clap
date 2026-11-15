const std = @import("std");
const interp = @import("interpolation.zig");

pub fn Linear(
    comptime T: type,
    comptime range_lower: comptime_float,
    comptime range_upper: comptime_float,
) type {
    if (range_lower >= range_upper) @compileError("Invalid range");

    return struct {
        pub const lower = range_lower;
        pub const upper = range_upper;

        pub fn toNormalized(value: T) T {
            return interp.invLerp(lower, upper, value);
        }

        pub fn fromNormalized(norm: T) T {
            return interp.lerp(lower, upper, norm);
        }
    };
}

pub fn Skewed(
    comptime T: type,
    comptime range_lower: comptime_float,
    comptime range_upper: comptime_float,
    comptime exp: comptime_float,
) type {
    if (range_lower >= range_upper) @compileError("Invalid range");
    if (exp <= 0.0) @compileError("Invalid exponent");

    return struct {
        pub const lower = range_lower;
        pub const upper = range_upper;

        pub fn toNormalized(value: T) T {
            const proportion = interp.invLerp(lower, upper, value);
            return std.math.pow(T, proportion, exp);
        }

        pub fn fromNormalized(norm: T) T {
            const proportion = std.math.pow(T, norm, 1.0 / exp);
            return interp.lerp(lower, upper, proportion);
        }
    };
}

pub fn SkewedCenter(
    comptime T: type,
    comptime lower: comptime_float,
    comptime upper: comptime_float,
    comptime center: comptime_float,
) type {
    if (center <= lower or center >= upper) @compileError("Invalid center");

    const exp = std.math.log(T, interp.invLerp(lower, upper, center), 0.5);
    return Skewed(T, lower, upper, exp);
}

pub fn Log10(
    comptime T: type,
    comptime range_lower: comptime_float,
    comptime range_upper: comptime_float,
) type {
    if (range_lower <= 0) @compileError("Invalid range");
    if (range_lower >= range_upper) @compileError("Invalid range");

    return struct {
        pub const lower = range_lower;
        pub const upper = range_upper;

        pub fn toNormalized(value: T) T {
            return interp.mapFromLog10(value, lower, upper);
        }

        pub fn fromNormalized(norm: T) T {
            return interp.mapToLog10(norm, lower, upper);
        }
    };
}

const tolerance = 1e-5;

test Linear {
    const Range = Linear(f64, 10.0, 20.0);

    try std.testing.expectApproxEqRel(10.0, Range.fromNormalized(0.0), tolerance);
    try std.testing.expectApproxEqRel(15.0, Range.fromNormalized(0.5), tolerance);
    try std.testing.expectApproxEqRel(20.0, Range.fromNormalized(1.0), tolerance);

    try std.testing.expectApproxEqRel(0.0, Range.toNormalized(10.0), tolerance);
    try std.testing.expectApproxEqRel(0.5, Range.toNormalized(15.0), tolerance);
    try std.testing.expectApproxEqRel(1.0, Range.toNormalized(20.0), tolerance);
}

test SkewedCenter {
    const Range = SkewedCenter(f64, 10.0, 20.0, 12.0);

    try std.testing.expectApproxEqRel(10.0, Range.fromNormalized(0.0), tolerance);
    try std.testing.expectApproxEqRel(12.0, Range.fromNormalized(0.5), tolerance);
    try std.testing.expectApproxEqRel(20.0, Range.fromNormalized(1.0), tolerance);

    try std.testing.expectApproxEqRel(0.0, Range.toNormalized(10.0), tolerance);
    try std.testing.expectApproxEqRel(0.5, Range.toNormalized(12.0), tolerance);
    try std.testing.expectApproxEqRel(1.0, Range.toNormalized(20.0), tolerance);
}

test Log10 {
    const Range = Log10(f64, 10.0, 20.0);

    try std.testing.expectApproxEqRel(10.0, Range.fromNormalized(0.0), tolerance);
    try std.testing.expectApproxEqRel(20.0, Range.fromNormalized(1.0), tolerance);

    try std.testing.expectApproxEqRel(0.0, Range.toNormalized(10.0), tolerance);
    try std.testing.expectApproxEqRel(1.0, Range.toNormalized(20.0), tolerance);

    const norm = Range.toNormalized(15.0);
    try std.testing.expectApproxEqRel(15.0, Range.fromNormalized(norm), tolerance);

    const value = Range.fromNormalized(0.5);
    try std.testing.expectApproxEqRel(0.5, Range.toNormalized(value), tolerance);
}
