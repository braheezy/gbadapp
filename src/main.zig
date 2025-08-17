const std = @import("std");
const gba = @import("gba");
const uncompressed_tiles = @import("assets/sequential/uncompressed_tiles.zig");

// GBA header
export var header linksection(".gbaheader") = gba.initHeader("UNCOMPRESS", "AFSE", "00", 0);

// Constants from uncompressed tiles
const TILE_SIZE = uncompressed_tiles.TILE_SIZE;
const GRID_WIDTH = uncompressed_tiles.GRID_WIDTH;
const GRID_HEIGHT = uncompressed_tiles.GRID_HEIGHT;
const TILES_PER_FRAME = uncompressed_tiles.TILE_COUNT;
const MAX_TILES = uncompressed_tiles.TILE_COUNT;
const MAX_FRAMES = uncompressed_tiles.FRAME_COUNT;

// Frame counter
var current_frame: u32 = 0;
var frame_timer: u32 = 0;

// Tile data storage - loaded directly from embedded data
var tile_data: [MAX_TILES][TILE_SIZE * TILE_SIZE]u8 = undefined;
var tile_count: u32 = 0;

// Tile map storage - loaded from embedded data
var tile_maps: [MAX_FRAMES][GRID_HEIGHT][GRID_WIDTH]u32 = undefined;

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

// Function to load tile map for a specific frame
fn loadFrameTileMap(frame_id: u32) void {
    var y: u32 = 0;
    while (y < GRID_HEIGHT) : (y += 1) {
        var x: u32 = 0;
        while (x < GRID_WIDTH) : (x += 1) {
            tile_maps[frame_id][y][x] = uncompressed_tiles.frame_tile_maps[frame_id][y][x];
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

// Function to render a complete frame
fn renderFrame(frame_id: u32) void {
    var tile_y: u32 = 0;
    while (tile_y < GRID_HEIGHT) : (tile_y += 1) {
        var tile_x: u32 = 0;
        while (tile_x < GRID_WIDTH) : (tile_x += 1) {
            const tile_id = tile_maps[frame_id][tile_y][tile_x];
            if (tile_id < tile_count) {
                renderTile(tile_x, tile_y, tile_id);
            }
        }
    }
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

    // Load initial frame tile map
    loadFrameTileMap(0);

    // Main loop
    while (true) {
        gba.display.vSync();

        // Update frame counter every 8 frames (0.13 seconds at 60fps) - smooth animation
        frame_timer += 1;
        if (frame_timer >= 8) {
            frame_timer = 0;
            current_frame = (current_frame + 1) % MAX_FRAMES;

            // Load new frame
            loadFrameTileMap(current_frame);
        }

        // Render the current frame every frame
        renderFrame(current_frame);
    }
}
