const std = @import("std");
const gba = @import("gba");
const mm = @import("maxmod");

const frames = @import("assets/simple_frames.zig");
const bank_data align(4) = @embedFile("assets/soundbank.bin");

// GBA header
export var header linksection(".gbaheader") = gba.Header.init("BADAPPLE", "AFSE", "00", 0);

// Global variables
var vblank_count: u32 = 0;
var simple_frame_index: u32 = 0;
var next_frame_data: ?[]align(4) const u8 = null;
var next_frame_offset: usize = 0;
var catchup_counter: u32 = 0;

const VRAM_PAGE_SIZE: u32 = 0x0A000;
const VRAM_FRONT: u32 = 0x06000000;
const VIDEO_FRAME_INTERVAL = 3;
const VIDEO_COPY_CHUNK_BYTES = 12800;

export fn main() void {
    gba.mem.wait_ctrl.* = .default;

    // Initialize interrupts
    gba.interrupt.init();
    gba.interrupt.isr_default_redirect = vblank_handler;

    gba.display.ctrl.* = .initMode4(.{});
    setupPalette();
    clearVRAMPage(VRAM_FRONT);

    _ = mm.gba.initDefault(@ptrCast(@constCast(&bank_data[0])), 32) catch unreachable;

    mm.mas.mmStart(0, 0);

    while (true) {
        mm.gba.frame();

        if (vblank_count % VIDEO_FRAME_INTERVAL == 0) {
            prepare_next_frame();
        }

        gba.display.naiveVSync();
    }
}

fn vblank_handler(_: gba.interrupt.InterruptFlags) callconv(.c) void {
    mm.mixer.vBlank();
    vblank_count += 1;

    if (next_frame_data) |frame_data| {
        const remaining = frame_data.len - next_frame_offset;
        const copy_len = @min(remaining, VIDEO_COPY_CHUNK_BYTES);
        render_frame_chunk_to_vram(frame_data, next_frame_offset, copy_len, VRAM_FRONT);

        next_frame_offset += copy_len;
        if (next_frame_offset >= frame_data.len) {
            next_frame_data = null;
            next_frame_offset = 0;
        }
    }
}

fn setupPalette() void {
    const palette = [_]gba.ColorRgb555{
        .rgb(0, 0, 0),
        .rgb(31, 31, 31),
    };

    gba.display.memcpyBackgroundPalette(0, &palette);
}

fn prepare_next_frame() void {
    catchup_counter += 1;

    const frame_index = if (simple_frame_index >= frames.FRAME_COUNT)
        frames.FRAME_COUNT - 1
    else
        simple_frame_index;

    if (next_frame_data == null) {
        next_frame_data = frames.frame_data[frame_index];
        next_frame_offset = 0;
    }

    if (simple_frame_index < frames.FRAME_COUNT) {
        var frame_advance: u32 = 1;

        if (catchup_counter % 12 == 0) {
            frame_advance = 2;
        }

        simple_frame_index += frame_advance;
    }
}

fn render_frame_chunk_to_vram(data: []align(4) const u8, offset: usize, len: usize, vram_addr: u32) void {
    const dma = &gba.mem.dma[3];
    const word_count = (len + 3) / 4;

    dma.source = @ptrFromInt(@intFromPtr(data.ptr + offset));
    dma.dest = @ptrFromInt(vram_addr + offset);
    dma.count = @truncate(word_count);
    dma.ctrl = .{
        .dest = .increment,
        .source = .increment,
        .size = .bits_32,
        .timing = .immediate,
        .enabled = true,
    };
}

fn clearVRAMPage(vram_addr: u32) void {
    const dma = &gba.mem.dma[3];
    const zero_word: u32 = 0;
    const word_count = VRAM_PAGE_SIZE / 4;

    dma.source = @ptrFromInt(@intFromPtr(&zero_word));
    dma.dest = @ptrFromInt(vram_addr);
    dma.count = @truncate(word_count);
    dma.ctrl = .{
        .dest = .increment,
        .source = .fixed,
        .size = .bits_32,
        .timing = .immediate,
        .enabled = true,
    };
}
