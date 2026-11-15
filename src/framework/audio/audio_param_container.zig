const std = @import("std");
const AudioParam = @import("AudioParam.zig");
const state = @import("../state/state.zig");

fn sortIndicesByVersion(
    comptime Schema: type,
) [@typeInfo(Schema).@"struct".field_names.len]usize {
    const info = @typeInfo(Schema).@"struct";
    const count = info.field_names.len;

    @setEvalBranchQuota(100_000);

    const Versions = [count]usize;

    var indices: [count]usize = undefined;
    var versions: Versions = undefined;

    inline for (info.field_types, 0..) |T, i| {
        indices[i] = i;
        versions[i] = T.version;
    }

    const Context = struct {
        fn lessThan(ver: Versions, lhs: usize, rhs: usize) bool {
            return ver[lhs] < ver[rhs];
        }
    };

    std.sort.block(
        usize,
        &indices,
        versions,
        Context.lessThan,
    );

    return indices;
}

pub fn AudioParamContainer(comptime Schema: type) type {
    const info = @typeInfo(Schema).@"struct";
    const field_names = info.field_names;
    const count = field_names.len;

    const sorted_indices = comptime sortIndicesByVersion(Schema);

    return struct {
        pub const ParamCount = count;

        // Concrete parameter instances
        values: Schema,

        // Type-erased parameters
        erased: [count]*AudioParam,

        pub fn init(self: *@This()) void {
            inline for (field_names) |name| {
                const param = &@field(self.values, name);
                param.init();
            }

            // Populate the erased array in sorted order.
            inline for (sorted_indices, 0..) |src, dst| {
                const name = field_names[src];
                const param = &@field(self.values, name);

                self.erased[dst] = &param.param;
                param.param.id = @intCast(dst);
            }
        }

        pub fn getCount(self: *const @This()) usize {
            _ = self;
            return count;
        }

        pub fn getChecked(self: *const @This(), index: usize) ?*AudioParam {
            if (index >= self.getCount()) return null;

            return self.erased[index];
        }

        pub fn get(self: *const @This(), index: usize) *AudioParam {
            std.debug.assert(index < self.getCount());

            return self.erased[index];
        }

        pub fn saveState(self: *const @This(), allocator: std.mem.Allocator, stream: *state.BinaryStreamOut) !void {
            for (self.erased) |param| {
                try stream.appendValue(allocator, param.getNormalizedValue());
            }
        }

        pub fn loadState(self: *@This(), stream: *state.BinaryStreamIn) void {
            for (self.erased) |param| {
                param.setNormalizedValue(stream.readValue(f64));
            }
        }
    };
}

test {
    const normalizable = @import("../math/normalizable.zig");

    const Params = AudioParamContainer(struct {
        volume: AudioParam.Float(
            2,
            "Volume",
            normalizable.Linear(f64, 0.0, 100.0),
            50.0,
        ),
        frequency: AudioParam.Float(
            1,
            "Frequency",
            normalizable.Log10(f64, 20.0, 20_000.0),
            1000.0,
        ),
    });

    var params: Params = undefined;
    params.init();

    _ = params.values.volume;
    _ = params.values.frequency;

    try std.testing.expectEqual(null, params.getChecked(2));

    const volume = params.erased[1];
    try std.testing.expectEqualStrings("Volume", volume.name);
}
