const std = @import("std");
const c = @import("c");
const c_str = @import("c_str.zig");
const Config = @import("Config.zig");

pub fn ExtGui(comptime config: Config) type {
    const ClapProcessor = @import("clap_processor.zig").ClapProcessor(config);
    const Gui = @import("gui/gui.zig").Gui(config);

    return struct {
        pub const extension: c.clap_plugin_gui_t = .{
            .is_api_supported = isApiSupported,
            .get_preferred_api = getPrefferedApi,
            .create = create,
            .destroy = destroy,
            .set_scale = setScale,
            .get_size = getSize,
            .can_resize = canResize,
            .get_resize_hints = getResizeHints,
            .adjust_size = adjustSize,
            .set_size = setSize,
            .set_parent = setParent,
            .set_transient = setTransient,
            .suggest_title = suggestTitle,
            .show = show,
            .hide = hide,
        };

        fn isApiSupported(
            _: [*c]const c.clap_plugin_t,
            api: [*c]const u8,
            is_floating: bool,
        ) callconv(.c) bool {
            return c_str.isEql(api, &Gui.API) and !is_floating;
        }

        fn getPrefferedApi(
            _: [*c]const c.clap_plugin_t,
            api: [*c][*c]const u8,
            is_floating: [*c]bool,
        ) callconv(.c) bool {
            api.* = &Gui.API;
            is_floating.* = false;
            return true;
        }

        fn create(
            clap_plugin: [*c]const c.clap_plugin_t,
            api: [*c]const u8,
            is_floating: bool,
        ) callconv(.c) bool {
            if (!isApiSupported(clap_plugin, api, is_floating)) return false;

            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            plugin.gui = Gui.create(plugin.allocator, plugin.io, &plugin.processor) catch return false;
            return true;
        }

        fn destroy(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) void {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            plugin.gui.?.destroy(plugin.allocator);
        }

        fn setScale(_: [*c]const c.clap_plugin_t, scale: f64) callconv(.c) bool {
            _ = scale;
            return false;
        }

        fn getSize(clap_plugin: [*c]const c.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));

            width.*, height.* = plugin.gui.?.gui.getSize();
            return true;
        }

        fn canResize(_: [*c]const c.clap_plugin_t) callconv(.c) bool {
            return false;
        }

        fn getResizeHints(_: [*c]const c.clap_plugin_t, hints: [*c]c.clap_gui_resize_hints_t) callconv(.c) bool {
            _ = hints;
            return false;
        }

        fn adjustSize(clap_plugin: [*c]const c.clap_plugin_t, width: [*c]u32, height: [*c]u32) callconv(.c) bool {
            return getSize(clap_plugin, width, height);
        }

        fn setSize(_: [*c]const c.clap_plugin_t, width: u32, height: u32) callconv(.c) bool {
            _ = width;
            _ = height;
            return true;
        }

        fn setParent(clap_plugin: [*c]const c.clap_plugin_t, window: [*c]const c.clap_window_t) callconv(.c) bool {
            std.debug.assert(c_str.isEql(window.*.api, &Gui.API));

            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            plugin.gui.?.setParent(@ptrCast(window.?));

            return true;
        }

        fn setTransient(_: [*c]const c.clap_plugin_t, window: [*c]const c.clap_window_t) callconv(.c) bool {
            _ = window;
            return false;
        }

        fn suggestTitle(_: [*c]const c.clap_plugin_t, title: [*c]const u8) callconv(.c) void {
            _ = title;
        }

        fn show(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            plugin.gui.?.setVisible(true);
            return true;
        }

        fn hide(clap_plugin: [*c]const c.clap_plugin_t) callconv(.c) bool {
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            plugin.gui.?.setVisible(false);
            return true;
        }

        // Timer extension

        pub const timer_ext: c.clap_plugin_timer_support_t = .{
            .on_timer = onTimer,
        };

        fn onTimer(clap_plugin: [*c]const c.clap_plugin_t, timer_id: c.clap_id) callconv(.c) void {
            _ = timer_id;
            const plugin: *ClapProcessor = @ptrCast(@alignCast(clap_plugin.*.plugin_data));
            @import("../logging/logging.zig").debugPrint("onTimer\n", .{});

            const have_param_values_changed = true; // TODO
            if (plugin.gui != null and have_param_values_changed) {
                plugin.gui.?.repaint(true);
            }
        }
    };
}
