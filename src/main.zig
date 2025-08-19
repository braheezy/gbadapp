const std = @import("std");
const gba = @import("gba");
const frames = @import("assets/simple_frames.zig");

// GBA header
export var header linksection(".gbaheader") = gba.initHeader("BADAPPLE", "AFSE", "00", 0);

// Global variables
var frame_index: u16 = 0;
var frame_timer: u16 = 0;
var frame_delay: u16 = 1; // 1 VBlank cycle = 60fps

export fn main() void {
    // Initialize interrupts
    gba.interrupt.init();
    _ = gba.interrupt.add(.vblank, vblank_handler);

    // Initialize display in mode 4 (8-bit color bitmap)
    gba.display.ctrl.* = .{ .mode = .mode4, .bg2 = .enable };

    // Set up a simple black and white palette for Bad Apple
    setupPalette();

    // Clear screen to black
    gba.bitmap.Mode4.fill(0);

    // Main loop
    while (true) {
        gba.display.vSync();

        frame_timer += 1;
        if (frame_timer >= frame_delay) {
            frame_timer = 0;
            render_next_frame();
        }
    }
}

fn vblank_handler() void {
    // VBlank processing if needed
}

fn setupPalette() void {
    // Create a simple black and white palette for Bad Apple
    const palette = [_]u16{
        @bitCast(gba.Color.rgb(0, 0, 0)), // 0 = black
        @bitCast(gba.Color.rgb(31, 31, 31)), // 1 = white
    };

    gba.mem.memcpy32(gba.bg.palette, &palette, palette.len * 2);
}

fn render_next_frame() void {
    if (frame_index >= frames.FRAME_COUNT) {
        frame_index = 0; // Loop back to start
    }

    // Get the current frame data
    const current_frame = frames.frame_data[frame_index];

    // Render the frame pixel by pixel at 60fps
    var y: u8 = 0;
    while (y < 160) : (y += 1) {
        var x: u8 = 0;
        while (x < 240) : (x += 1) {
            const pixel_index = @as(usize, y) * 240 + @as(usize, x);
            if (pixel_index < current_frame.len) {
                const pixel_value = @as(u8, @intCast(current_frame[pixel_index]));
                gba.bitmap.Mode4.setPixel(x, y, pixel_value);
            }
        }
    }

    frame_index += 1;
}
