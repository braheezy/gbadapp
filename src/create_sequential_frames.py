#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "numpy",
#   "Pillow",
# ]
# ///

import os
import glob
import numpy as np
from PIL import Image

def create_sequential_frames():
    """Create sequential frames for smooth video playback"""

    # Get all frame files and sort them
    frame_files = glob.glob("assets/frame_*.ag4")
    frame_files.sort()

    print(f"Found {len(frame_files)} total frames")

    # Find a good starting point (not black)
    start_frame = None
    for frame_file in frame_files:
        with open(frame_file, 'rb') as f:
            frame_data = f.read()
        frame_array = np.frombuffer(frame_data, dtype=np.uint8).reshape(160, 240)

        # Check top-left 32x32 area (first 2x2 tiles)
        top_left_area = frame_array[0:32, 0:32]
        non_zero_percent = (top_left_area != 0).sum() / top_left_area.size * 100

        if non_zero_percent > 20:  # At least 20% non-black in top-left
            start_frame = frame_file
            print(f"Starting with {os.path.basename(start_frame)} ({non_zero_percent:.1f}% non-black in top-left)")
            break

    if not start_frame:
        print("No good starting frame found!")
        return

    # Get the frame number
    frame_num = int(os.path.basename(start_frame).split('_')[1].split('.')[0])

    # Select 10 consecutive frames for smooth playback
    selected_frames = []
    for i in range(10):
        target_frame = frame_num + (i * 2)  # Every 2nd frame for smoother motion
        frame_file = f"assets/frame_{target_frame:04d}.ag4"

        if os.path.exists(frame_file):
            selected_frames.append(frame_file)
            print(f"  Frame {target_frame:04d}: {frame_file}")
        else:
            print(f"  Frame {target_frame:04d}: Not found, stopping")
            break

    print(f"\nSelected {len(selected_frames)} frames for smooth playback")

    # Create output directories
    os.makedirs("assets/sequential/tiles", exist_ok=True)
    os.makedirs("assets/sequential/tilemaps", exist_ok=True)

    # Process each frame to extract tiles
    all_tiles = {}  # tile_hash -> tile_data
    tile_counter = 0

    for frame_idx, frame_file in enumerate(selected_frames):
        print(f"\nProcessing frame {frame_idx + 1}/{len(selected_frames)}: {os.path.basename(frame_file)}")

        # Read frame data
        with open(frame_file, 'rb') as f:
            frame_data = f.read()
        frame_array = np.frombuffer(frame_data, dtype=np.uint8).reshape(160, 240)

        # Extract 16x16 tiles
        tile_size = 16
        grid_width = 240 // tile_size
        grid_height = 160 // tile_size

        frame_tile_map = np.zeros((grid_height, grid_width), dtype=np.uint32)

        for tile_y in range(grid_height):
            for tile_x in range(grid_width):
                # Extract tile
                start_x = tile_x * tile_size
                start_y = tile_y * tile_size
                tile = frame_array[start_y:start_y + tile_size, start_x:start_x + tile_size]

                # Create hash of tile data
                tile_hash = hash(tile.tobytes())

                # Add to all_tiles if new
                if tile_hash not in all_tiles:
                    all_tiles[tile_hash] = {
                        'data': tile.copy(),
                        'id': tile_counter
                    }
                    tile_counter += 1

                # Set tile map
                frame_tile_map[tile_y, tile_x] = all_tiles[tile_hash]['id']

        # Save tile map
        tilemap_file = f"assets/sequential/tilemaps/frame_{frame_idx:02d}.map"
        frame_tile_map.tofile(tilemap_file)
        print(f"  Saved tilemap: {tilemap_file}")

    # Save all unique tiles
    print(f"\nSaving {len(all_tiles)} unique tiles...")
    for tile_hash, tile_info in all_tiles.items():
        tile_file = f"assets/sequential/tiles/tile_{tile_info['id']:04d}.raw"
        tile_info['data'].tofile(tile_file)

    print(f"\nSequential frame processing complete!")
    print(f"  Frames: {len(selected_frames)}")
    print(f"  Unique tiles: {len(all_tiles)}")
    print(f"  Output: assets/sequential/")

if __name__ == "__main__":
    create_sequential_frames()
