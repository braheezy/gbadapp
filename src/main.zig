const std = @import("std");
const gba = @import("gba");
const mm = @import("maxmod");

const frames = @import("assets/simple_frames.zig");
const bank_data align(4) = @embedFile("assets/soundbank.bin");

// GBA header
export var header linksection(".gbaheader") = gba.initHeader("BADAPPLE", "AFSE", "00", 0);

// Global variables
var vblank_count: u32 = 0;
var simple_frame_index: u32 = 0;
var next_frame_data: ?[]const u8 = null;
var catchup_counter: u32 = 0;

const VRAM_PAGE_SIZE: u32 = 0x0A000;
const VRAM_FRONT: u32 = 0x06000000;
const VRAM_BACK: u32 = 0x06000000 + VRAM_PAGE_SIZE;

export fn main() void {
    // Initialize interrupts
    gba.interrupt.init();
    _ = gba.interrupt.add(.vblank, vblank_handler);

    gba.display.ctrl.* = .{ .mode = .mode4, .bg2 = .enable };
    setupPalette();
    clearVRAMPage(VRAM_FRONT);

    _ = mm.gba.initDefault(@ptrCast(@constCast(&bank_data[0])), 32) catch unreachable;

    mm.mas.mmStart(0, 0);

    while (true) {
        mm.gba.frame();

        if (vblank_count % 3 == 0) {
            prepare_next_frame();
        }

        gba.display.vSync();
    }
}

fn vblank_handler() void {
    mm.mixer.vBlank();
    vblank_count += 1;

    if (next_frame_data) |frame_data| {
        render_full_frame_to_vram(frame_data, VRAM_FRONT);
        next_frame_data = null;
    }
}

fn setupPalette() void {
    const palette = [_]u16{
        @bitCast(gba.Color.rgb(0, 0, 0)),
        @bitCast(gba.Color.rgb(31, 31, 31)),
    };

    gba.mem.memcpy32(gba.bg.palette, &palette, palette.len * 2);
}

fn prepare_next_frame() void {
    catchup_counter += 1;

    const frame_index = if (simple_frame_index >= frames.FRAME_COUNT)
        frames.FRAME_COUNT - 1
    else
        simple_frame_index;

    next_frame_data = frames.frame_data[frame_index];

    if (simple_frame_index < frames.FRAME_COUNT) {
        var frame_advance: u32 = 1;

        if (catchup_counter % 12 == 0) {
            frame_advance = 2;
        }

        simple_frame_index += frame_advance;
    }
}

fn render_full_frame_to_vram(data: []const u8, vram_addr: u32) void {
    const dma = &gba.mem.dma[3];
    const word_count = (data.len + 3) / 4;

    dma.source = @ptrFromInt(@intFromPtr(data.ptr));
    dma.dest = @ptrFromInt(vram_addr);
    dma.ctrl = .{
        .count = @truncate(word_count),
        .dest = .increment,
        .source = .increment,
        .transfer_type = .word,
        .start_timing = .immediate,
        .enabled = .enable,
    };
}

fn clearVRAMPage(vram_addr: u32) void {
    const dma = &gba.mem.dma[3];
    const zero_word: u32 = 0;
    const word_count = VRAM_PAGE_SIZE / 4;

    dma.source = @ptrFromInt(@intFromPtr(&zero_word));
    dma.dest = @ptrFromInt(vram_addr);
    dma.ctrl = .{
        .count = @truncate(word_count),
        .dest = .increment,
        .source = .fixed,
        .transfer_type = .word,
        .start_timing = .immediate,
        .enabled = .enable,
    };
}
