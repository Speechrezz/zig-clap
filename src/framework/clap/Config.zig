pub const Descriptor = struct {
    id: [:0]const u8,
    name: [:0]const u8,
    vendor: [:0]const u8 = "",
    url: [:0]const u8 = "",
    manual_url: [:0]const u8 = "",
    support_url: [:0]const u8 = "",
    version: [:0]const u8 = "",
    description: [:0]const u8 = "",
    features: [:null]const ?[*:0]const u8 = &.{},
};

PluginProcessor: type,
descriptor: Descriptor,
