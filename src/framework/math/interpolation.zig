const std = @import("std");

pub const lerp = std.math.lerp;

/// Given a range `[a, b]`, this function returns how far along `x` as a proportion `[0, 1]`.
pub fn invLerp(a: anytype, b: anytype, x: anytype) @TypeOf(a, b, x) {
    return (x - a) / (b - a);
}

/// Given a normalized value [0, 1], this will map to the desired range logorithmically
pub fn mapToLog10(
    value_linear: anytype,
    range_min: anytype,
    range_max: anytype,
) @TypeOf(value_linear, range_min, range_max) {
    const T = @TypeOf(value_linear, range_min, range_max);
    std.debug.assert(range_min > 0.0);
    std.debug.assert(range_max > 0.0);

    const log_min = @log10(range_min);
    const log_max = @log10(range_max);

    return std.math.pow(T, 10.0, value_linear * (log_max - log_min) + log_min);
}

pub fn mapFromLog10(
    value_log: anytype,
    range_min: anytype,
    range_max: anytype,
) @TypeOf(value_log, range_min, range_max) {
    std.debug.assert(range_min > 0.0);
    std.debug.assert(range_max > 0.0);

    const log_min = @log10(range_min);
    const log_max = @log10(range_max);

    return (@log10(value_log) - log_min) / (log_max - log_min);
}

pub fn hermite(
    v0: anytype,
    v1: anytype,
    v2: anytype,
    v3: anytype,
    t: anytype,
) @TypeOf(v0, v1, v2, v3, t) {
    const slope0 = (v2 - v0) * 0.5;
    const slope1 = (v3 - v1) * 0.5;
    const v = v1 - v2;
    const w = slope0 + v;
    const a = w + v + slope1;
    const b_neg = w + a;
    const stage1 = a * t - b_neg;
    const stage2 = stage1 * t + slope0;
    return stage2 * t + v1;
}

pub fn lagrange(
    v0: anytype,
    v1: anytype,
    v2: anytype,
    v3: anytype,
    t: anytype,
) @TypeOf(v0, v1, v2, v3, t) {
    const d1 = t - 1.0;
    const d2 = t - 2.0;
    const d3 = t - 3.0;

    const c0 = -d1 * d2 * d3 / 6.0;
    const c1 = d2 * d3 * 0.5;
    const c2 = -d1 * d3 * 0.5;
    const c3 = d1 * d2 / 6.0;

    return v0 * c0 + t * (v1 * c1 + v2 * c2 + v3 * c3);
}

test "Log mapping" {
    const tolerance = 1e-5;

    const range_min: f32 = 20.0;
    const range_max: f32 = 20000.0;

    var mapped = mapToLog10(0.0, range_min, range_max);
    try std.testing.expectApproxEqAbs(range_min, mapped, tolerance);

    mapped = mapToLog10(1.0, range_min, range_max);
    try std.testing.expectApproxEqRel(range_max, mapped, tolerance);

    mapped = mapFromLog10(range_min, range_min, range_max);
    try std.testing.expectApproxEqAbs(0.0, mapped, tolerance);

    mapped = mapFromLog10(range_max, range_min, range_max);
    try std.testing.expectApproxEqRel(1.0, mapped, tolerance);
}
