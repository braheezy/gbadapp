const std = @import("std");
const gba = @import("gba");
const uncompressed_tiles = @import("assets/sequential/uncompressed_tiles.zig");

// GBA header
export var header linksection(".gbaheader") = gba.initHeader("BADAPPLE", "AFSE", "00", 0);

// Constants from uncompressed tiles
const TILE_SIZE = uncompressed_tiles.TILE_SIZE;
const GRID_WIDTH = uncompressed_tiles.GRID_WIDTH;
const GRID_HEIGHT = uncompressed_tiles.GRID_HEIGHT;
const TILES_PER_FRAME = uncompressed_tiles.TILE_COUNT;
const MAX_TILES = uncompressed_tiles.TILE_COUNT;
const MAX_FRAMES = uncompressed_tiles.FRAME_COUNT;

// Frame timing - target 30fps for smooth playback
const FRAME_DURATION = 2; // 2 vsync cycles = 30fps (60/2)

// Frame counter and timing
var current_frame: u32 = 0;
var frame_timer: u32 = 0;

// Double buffering - two frame buffers
var frame_buffer_a: [GRID_HEIGHT][GRID_WIDTH]u32 = undefined;
var frame_buffer_b: [GRID_HEIGHT][GRID_WIDTH]u32 = undefined;
var active_buffer: *[GRID_HEIGHT][GRID_WIDTH]u32 = &frame_buffer_a;
var back_buffer: *[GRID_HEIGHT][GRID_WIDTH]u32 = &frame_buffer_b;

// Previous frame for delta rendering optimization
var prev_frame: [GRID_HEIGHT][GRID_WIDTH]u32 = undefined;

// Tile data storage - loaded directly from embedded data
var tile_data: [MAX_TILES][TILE_SIZE * TILE_SIZE]u8 = undefined;
var tile_count: u32 = 0;

// Create a better 4-bit grayscale palette optimized for Bad Apple content
const grayscale_palette: [16]u16 = .{
    @bitCast(gba.Color.rgb(31, 31, 31)), // 0 = pure white (background)
    @bitCast(gba.Color.rgb(8, 8, 8)), // 1 = dark gray (main content)
    @bitCast(gba.Color.rgb(12, 12, 12)), // 2 = medium dark gray
    @bitCast(gba.Color.rgb(16, 16, 16)), // 3 = medium gray
    @bitCast(gba.Color.rgb(20, 20, 20)), // 4 = medium light gray
    @bitCast(gba.Color.rgb(24, 24, 24)), // 5 = light gray
    @bitCast(gba.Color.rgb(28, 28, 28)), // 6 = very light gray
    @bitCast(gba.Color.rgb(0, 0, 0)), // 7 = pure black (for contrast)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 8 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 9 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 10 = pure black (highlights)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 11 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 12 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 13 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 14 = pure black (unused)
    @bitCast(gba.Color.rgb(0, 0, 0)), // 15 = pure black (unused)
};

// Function to load all tiles from embedded data
fn loadTiles() void {
    var i: u32 = 0;
    while (i < MAX_TILES) : (i += 1) {
        const embedded_tile = uncompressed_tiles.tile_data[i];
        const output = &tile_data[i];

        // Copy tile data directly (no decompression needed)
        var j: usize = 0;
        while (j < TILE_SIZE * TILE_SIZE) : (j += 1) {
            output[j] = embedded_tile[j];
        }
        tile_count += 1;
    }
}

// Function to load tile map for a specific frame into the back buffer
fn loadFrameTileMap(frame_id: u32) void {
    var y: u32 = 0;
    while (y < GRID_HEIGHT) : (y += 1) {
        var x: u32 = 0;
        while (x < GRID_WIDTH) : (x += 1) {
            back_buffer[y][x] = uncompressed_tiles.frame_tile_maps[frame_id][y][x];
        }
    }
}

// Function to render a single tile
fn renderTile(tile_x: u32, tile_y: u32, tile_id: u32) void {
    const tile = tile_data[tile_id];
    const start_x = tile_x * TILE_SIZE;
    const start_y = tile_y * TILE_SIZE;

    var y: u32 = 0;
    while (y < TILE_SIZE) : (y += 1) {
        var x: u32 = 0;
        while (x < TILE_SIZE) : (x += 1) {
            const pixel_x = start_x + x;
            const pixel_y = start_y + y;
            const color_value = tile[y * TILE_SIZE + x];

            if (pixel_x < 240 and pixel_y < 160) {
                gba.bitmap.Mode4.setPixel(@as(u8, @intCast(pixel_x)), @as(u8, @intCast(pixel_y)), color_value);
            }
        }
    }
}

// Function to render only changed tiles (delta rendering - FASTEST)
fn renderFrameDelta() void {
    var tile_y: u32 = 0;
    while (tile_y < GRID_HEIGHT) : (tile_y += 1) {
        var tile_x: u32 = 0;
        while (tile_x < GRID_WIDTH) : (tile_x += 1) {
            const new_tile_id = active_buffer[tile_y][tile_x];
            const old_tile_id = prev_frame[tile_y][tile_x];

            // Only render tiles that actually changed
            if (new_tile_id != old_tile_id and new_tile_id < tile_count) {
                renderTile(tile_x, tile_y, new_tile_id);
                // Update previous frame buffer
                prev_frame[tile_y][tile_x] = new_tile_id;
            }
        }
    }
}

// Function to render a complete frame from the active buffer (fallback)
fn renderFrame() void {
    var tile_y: u32 = 0;
    while (tile_y < GRID_HEIGHT) : (tile_y += 1) {
        var tile_x: u32 = 0;
        while (tile_x < GRID_WIDTH) : (tile_x += 1) {
            const tile_id = active_buffer[tile_y][tile_x];
            if (tile_id < tile_count) {
                renderTile(tile_x, tile_y, tile_id);
            }
        }
    }
}

// Function to swap buffers
fn swapBuffers() void {
    const temp = active_buffer;
    active_buffer = back_buffer;
    back_buffer = temp;
}

export fn main() void {
    // Initialize interrupts (needed for vsync)
    gba.interrupt.init();
    _ = gba.interrupt.add(.vblank, null);

    // Initialize display
    gba.display.ctrl.* = .{ .mode = .mode4, .bg2 = .enable };

    // Set up palette
    gba.mem.memcpy32(gba.bg.palette, &grayscale_palette, grayscale_palette.len * 2);

    // Test palette by drawing a simple color bar to verify it's working
    var x: u32 = 0;
    while (x < 240) : (x += 1) {
        var y: u32 = 0;
        while (y < 160) : (y += 1) {
            const color_index = @as(u8, @intCast((x * 16) / 240));
            gba.bitmap.Mode4.setPixel(@as(u8, @intCast(x)), @as(u8, @intCast(y)), color_index);
        }
    }

    // Wait a bit to show the test pattern
    var wait: u32 = 0;
    while (wait < 180) : (wait += 1) { // 3 seconds at 60fps
        gba.display.vSync();
    }

    // Clear screen to white (palette index 0)
    gba.bitmap.Mode4.fill(0);

    // Load all tiles
    loadTiles();

    // Load initial frame into back buffer
    loadFrameTileMap(0);

    // Swap buffers to make initial frame active
    swapBuffers();

    // Initialize previous frame buffer
    var init_y: u32 = 0;
    while (init_y < GRID_HEIGHT) : (init_y += 1) {
        var init_x: u32 = 0;
        while (init_x < GRID_WIDTH) : (init_x += 1) {
            prev_frame[init_y][init_x] = active_buffer[init_y][init_x];
        }
    }

    // Render initial frame
    renderFrame();

    // Main loop
    while (true) {
        gba.display.vSync();
        frame_timer += 1;

        // Only update frame content at target frame rate
        if (frame_timer >= FRAME_DURATION) {
            frame_timer = 0;

            // Move to next frame
            current_frame = (current_frame + 1) % MAX_FRAMES;

            // Load new frame into back buffer
            loadFrameTileMap(current_frame);

            // CRITICAL: Swap buffers FIRST, then render
            // This eliminates the top-to-bottom drawing effect
            swapBuffers();

            // Use delta rendering for maximum performance
            renderFrameDelta();
        }
    }
}
