const std = @import("std");
const windows = std.os.windows;
const c = @import("c");
const Config = @import("../Config.zig");

pub fn Gui(comptime config: Config) type {
    return struct {
        pub const API = c.CLAP_WINDOW_API_WIN32;

        var global_open_gui_count: u32 = 0;

        window: ?windows.HWND = null,
        bits: []u32 = undefined,

        pub fn create(allocator: std.mem.Allocator, width: comptime_int, height: comptime_int) !*@This() {
            const self = try allocator.create(@This());
            self.* = .{};

            if (global_open_gui_count == 0) {
                // Register the window class.
                var window_class = std.mem.zeroes(c.WNDCLASSA);
                window_class.lpfnWndProc = &windowsCallback;
                window_class.cbWndExtra = @sizeOf(*@This());
                window_class.lpszClassName = config.descriptor.id;
                window_class.hCursor = c.LoadCursorA(null, 32512); // c.IDC_ARROW
                window_class.style = c.CS_DBLCLKS;
                _ = c.RegisterClassA(&window_class);
            }
            global_open_gui_count += 1;

            self.window = @ptrCast(c.CreateWindowA(
                config.descriptor.id,
                config.descriptor.name,
                c.WS_CHILDWINDOW | c.WS_CLIPSIBLINGS,
                c.CW_USEDEFAULT,
                0,
                width,
                height,
                c.GetDesktopWindow(),
                null,
                null,
                null,
            ));

            self.bits = try allocator.alloc(u32, 4 * width * height);
            @memset(self.bits, 0);

            _ = c.SetWindowLongPtrA(@ptrCast(self.window), 0, @intCast(@intFromPtr(self)));

            // GUIPaint(plugin, true);
            return self;
        }

        pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
            _ = c.DestroyWindow(@ptrCast(self.window));

            allocator.free(self.bits);
            allocator.destroy(self);

            global_open_gui_count -= 1;
            if (global_open_gui_count == 0) {
                _ = c.UnregisterClassA(config.descriptor.id, null);
            }
        }

        pub fn setParent(self: *@This(), parent: *const c.clap_window_t) void {
            _ = c.SetParent(
                self.window,
                @ptrCast(parent.unnamed_0.win32),
            );
        }

        pub fn setVisible(self: *@This(), is_visible: bool) void {
            // Hard code the enum values lol
            _ = c.ShowWindow(
                @ptrCast(self.window),
                if (is_visible) 5 else 0,
            );
        }

        fn windowsCallback(window: c.HWND, message: c.UINT, wParam: c.WPARAM, lParam: c.LPARAM) callconv(.winapi) c.LRESULT {
            _ = window;
            _ = message;
            _ = wParam;
            _ = lParam;

            return 0;
            // const self_maybe: ?*@This() = @ptrCast(@alignCast(c.GetWindowLongPtr(window, 0)));
            // if (self_maybe == null) {
            //     return c.DefWindowProc(window, message, wParam, lParam);
            // }

            // switch (message) {
            //     // TODO
            //     else => return c.DefWindowProc(window, message, wParam, lParam),
            // }
        }
    };
}
