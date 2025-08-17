#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "numpy",
# ]
# ///

import os
import glob

def create_sequential_uncompressed():
    """Convert sequential uncompressed tiles into Zig code"""

    # Get raw tile files
    raw_dir = "assets/sequential/tiles"
    tile_files = glob.glob(f"{raw_dir}/tile_*.raw")
    tile_files.sort()

    print(f"Found {len(tile_files)} raw tile files")

    # Read raw tile data
    tile_data = []
    for tile_file in tile_files:
        with open(tile_file, 'rb') as f:
            raw_data = f.read()
        tile_data.append(raw_data)
        print(f"  {os.path.basename(tile_file)}: {len(raw_data)} bytes")

    # Generate Zig code
    zig_content = f"""// Auto-generated uncompressed tile data
// This file contains the raw tile data without compression

pub const TILE_COUNT = {len(tile_files)};
pub const TILE_SIZE = 16;
pub const TILE_BYTES = TILE_SIZE * TILE_SIZE;

// Raw tile data array - each tile is 256 bytes (16x16 pixels)
pub const tile_data: [TILE_COUNT][TILE_BYTES]u8 = .{{
"""
    for i, data in enumerate(tile_data):
        hex_data = ", ".join([f"0x{b:02x}" for b in data])
        zig_content += f"    .{{ {hex_data} }}, // tile_{i:04d}\n"

    zig_content += "};\n\n"

    # Read tile map data
    tilemap_path = "assets/sequential/tilemaps"
    frame_map_files = glob.glob(f"{tilemap_path}/frame_*.map")
    frame_map_files.sort()

    frame_maps_content = []
    for frame_idx, frame_file in enumerate(frame_map_files):
        with open(frame_file, 'rb') as f:
            frame_map_data = f.read()

        # Convert bytes to 32-bit values (4 bytes per u32)
        tilemap_array = []
        for i in range(0, len(frame_map_data), 4):  # 4 bytes per u32
            if i + 3 < len(frame_map_data):
                value = (frame_map_data[i] |
                        (frame_map_data[i+1] << 8) |
                        (frame_map_data[i+2] << 16) |
                        (frame_map_data[i+3] << 24))
                tilemap_array.append(value)

        # Split into grid
        frame_content = f"    .{{ // frame_{frame_idx:02d}\n"
        for y in range(10):  # GRID_HEIGHT
            frame_content += "        .{ "
            for x in range(15):  # GRID_WIDTH
                idx = y * 15 + x
                if idx < len(tilemap_array):
                    frame_content += f"{tilemap_array[idx]}, "
                else:
                    frame_content += "0, "
            frame_content += "},\n"
        frame_content += "    }"
        frame_maps_content.append(frame_content)

    zig_content += f"""
// Tile map data for each frame
pub const FRAME_COUNT = {len(frame_map_files)};
pub const GRID_WIDTH = 15;
pub const GRID_HEIGHT = 10;

pub const frame_tile_maps: [FRAME_COUNT][GRID_HEIGHT][GRID_WIDTH]u32 = .{{
"""
    zig_content += ",\n".join(frame_maps_content)
    zig_content += "\n};\n"

    output_path = "assets/sequential/uncompressed_tiles.zig"
    with open(output_path, 'w') as f:
        f.write(zig_content)

    print(f"Generated {output_path}")
    print(f"Total uncompressed size: {sum(len(d) for d in tile_data)} bytes")

if __name__ == "__main__":
    create_sequential_uncompressed()
