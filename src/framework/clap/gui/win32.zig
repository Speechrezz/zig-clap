const std = @import("std");
const windows = std.os.windows;
const c = @import("c");
const Config = @import("../Config.zig");

fn getXFromLParam(lparam: c.LPARAM) i32 {
    const raw: usize = @bitCast(lparam);
    const value: u16 = @truncate(raw);
    return @as(i16, @bitCast(value));
}
fn getYFromLParam(lparam: c.LPARAM) i32 {
    const raw: usize = @bitCast(lparam);
    const value: u16 = @truncate(raw >> 16);
    return @as(i16, @bitCast(value));
}

pub fn Gui(comptime config: Config) type {
    const ClapGui = @import("../clap_gui.zig").ClapGui(config);

    return struct {
        pub const API = c.CLAP_WINDOW_API_WIN32;

        var global_open_gui_count: u32 = 0;

        window: ?windows.HWND = null,
        bits: []u32 = undefined,

        gui: ClapGui = undefined,

        const timer_id = 1;
        const timer_interval_ms = 16;

        pub fn create(allocator: std.mem.Allocator, io: std.Io, processor: *config.PluginProcessor) !*@This() {
            const self = try allocator.create(@This());
            self.* = .{};

            self.gui.init(allocator, io, processor);
            const width, const height = self.gui.getSize();

            // TODO: Put a mutex around this?
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
                @as(i32, @intCast(width)),
                @as(i32, @intCast(height)),
                c.GetDesktopWindow(),
                null,
                null,
                null,
            ));

            self.bits = try allocator.alloc(u32, 4 * width * height);
            @memset(self.bits, 0);

            _ = c.SetWindowLongPtrA(@ptrCast(self.window), 0, @intCast(@intFromPtr(self)));

            // Start timer
            _ = c.SetTimer(
                @ptrCast(self.window),
                timer_id,
                timer_interval_ms,
                null,
            );

            self.repaint(true);
            return self;
        }

        pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
            _ = c.KillTimer(@ptrCast(self.window), timer_id);
            _ = c.DestroyWindow(@ptrCast(self.window));

            self.gui.deinit();

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

        pub fn repaint(self: *@This(), internal: bool) void {
            if (internal) self.gui.paint(self.bits);
            _ = c.RedrawWindow(@ptrCast(self.window), null, null, c.RDW_INVALIDATE);
        }

        fn windowsCallback(window: c.HWND, message: c.UINT, w_param: c.WPARAM, l_param: c.LPARAM) callconv(.winapi) c.LRESULT {
            const ptr: usize = @intCast(c.GetWindowLongPtrA(window, 0));
            const self_maybe: ?*@This() = @ptrFromInt(ptr);
            if (self_maybe == null) {
                return c.DefWindowProcA(window, message, w_param, l_param);
            }

            const self = self_maybe.?;
            const width, const height = self.gui.getSize();

            switch (message) {
                c.WM_PAINT => {
                    var paint: c.PAINTSTRUCT = undefined;
                    const dc = c.BeginPaint(window, &paint);
                    var info = std.mem.zeroes(c.BITMAPINFO);

                    info.bmiHeader = .{
                        .biSize = @sizeOf(c.BITMAPINFOHEADER),
                        .biWidth = @intCast(width),
                        .biHeight = -@as(c_long, @intCast(height)),
                        .biPlanes = 1,
                        .biBitCount = 32,
                        .biCompression = c.BI_RGB,
                        .biSizeImage = 0,
                        .biXPelsPerMeter = 0,
                        .biYPelsPerMeter = 0,
                        .biClrUsed = 0,
                        .biClrImportant = 0,
                    };

                    _ = c.StretchDIBits(
                        dc,
                        0,
                        0,
                        @intCast(width),
                        @intCast(height),
                        0,
                        0,
                        @intCast(width),
                        @intCast(height),
                        self.bits.ptr,
                        &info,
                        c.DIB_RGB_COLORS,
                        c.SRCCOPY,
                    );

                    _ = c.EndPaint(window, &paint);
                },
                c.WM_MOUSEMOVE => {
                    self.gui.handleMouseMove(getXFromLParam(l_param), getYFromLParam(l_param));
                    self.repaint(true);
                },
                c.WM_LBUTTONDOWN => {
                    _ = c.SetCapture(window);
                    self.gui.handleMouseDown(getXFromLParam(l_param), getYFromLParam(l_param));
                    self.repaint(true);
                },
                c.WM_LBUTTONUP => {
                    _ = c.ReleaseCapture();
                    self.gui.handleMouseUp();
                    self.repaint(true);
                },
                c.WM_TIMER => {
                    if (w_param == timer_id) {
                        // self.gui.onTimer();
                        self.repaint(true);
                    }
                },
                else => return c.DefWindowProcA(window, message, w_param, l_param),
            }

            return 0;
        }
    };
}
