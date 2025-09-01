const std = @import("std");
const gba = @import("gba");
const mm = @import("maxmod");

const frames = @import("assets/simple_frames.zig");
var bank_data: []const u8 = @embedFile("assets/soundbank.bin");

// GBA header
export var header linksection(".gbaheader") = gba.initHeader("BADAPPLE", "AFSE", "00", 0);

// Global variables
var frame_index: u16 = 0;

// Double buffering variables
var current_page: u8 = 0; // 0 = front page, 1 = back page
var frame_ready: bool = false; // Whether the back page is ready to swap

// 30fps timing variables
var vblank_count: u16 = 0; // Count VBlanks to control frame rate

// VRAM page addresses for Mode 4
const VRAM_PAGE_SIZE: u32 = 0x0A000; // 40,960 bytes per page
const VRAM_FRONT: u32 = 0x06000000; // Front page
const VRAM_BACK: u32 = 0x06000000 + VRAM_PAGE_SIZE; // Back page

export fn main() void {
    // Initialize interrupts
    gba.interrupt.init();
    _ = gba.interrupt.add(.vblank, vblank_handler);

    // Initialize display in mode 4 (8-bit color bitmap)
    gba.display.ctrl.* = .{ .mode = .mode4, .bg2 = .enable };

    // Set up a simple black and white palette for Bad Apple
    setupPalette();

    // Clear both VRAM pages to black
    clearVRAMPage(VRAM_FRONT);
    clearVRAMPage(VRAM_BACK);

    _ = mm.gba.mmInitDefault(@ptrCast(@constCast(&bank_data[0])), 32);

    mm.mas.mmStart(0, 0);

    // Main loop
    while (true) {
        vblank_count += 1;
        if (vblank_count % 16 == 0) {
            render_next_frame();
        }

        gba.display.vSync();

        mm.mas.mmFrame();
    }
}

fn vblank_handler() void {
    // Swap pages during VBlank if frame is ready
    if (frame_ready) {
        // Switch to the back page
        gba.display.ctrl.*.page_select = if (current_page == 0) 1 else 0;
        current_page = if (current_page == 0) 1 else 0;
        frame_ready = false;
    }
    mm.mixer.mmVBlank();
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

    // Get the current frame data and render it to the back page
    const frame_data = frames.frame_data[frame_index];
    const target_page = if (current_page == 0) VRAM_BACK else VRAM_FRONT;
    render_full_frame_to_vram(frame_data, target_page);

    // Mark frame as ready for next VBlank
    frame_ready = true;
    frame_index += 3; // Skip 2 frames to create choppy 10fps motion from 30fps data
}

fn render_full_frame_to_vram(data: []const u8, vram_addr: u32) void {
    // Use 32-bit aligned fast copy
    const vram_ptr = @as([*]align(2) volatile u8, @ptrFromInt(vram_addr));
    gba.mem.memcpy32(vram_ptr, @as([*]align(2) const u8, @ptrCast(@alignCast(data.ptr))), data.len);
}

fn clearVRAMPage(vram_addr: u32) void {
    // Clear VRAM page to black (0)
    const vram_ptr = @as([*]volatile u8, @ptrFromInt(vram_addr));
    for (0..VRAM_PAGE_SIZE) |i| {
        vram_ptr[i] = 0;
    }
}

// Legacy function for compatibility (now renders to current page)
fn render_full_frame(data: []const u8) void {
    const current_vram = if (current_page == 0) VRAM_FRONT else VRAM_BACK;
    render_full_frame_to_vram(data, current_vram);
}
