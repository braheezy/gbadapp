#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "numpy",
#   "Pillow",
# ]
# ///

#!/usr/bin/env python3
"""
Convert Bad Apple frames into a tile-based system.
This creates a set of unique 8x8 tiles and tile maps for each frame.
"""

import os
import glob
import numpy as np
from collections import defaultdict
from PIL import Image

def create_tile_system():
    """Convert all frames into a tile-based system"""

    # Get all frame files
    frame_files = glob.glob("assets/frame_*.ag4")
    frame_files.sort()

    print(f"Processing {len(frame_files)} frames...")

    # Create output directories
    os.makedirs("assets/tiles", exist_ok=True)
    os.makedirs("assets/tilemaps", exist_ok=True)

    # Dictionary to store unique tiles
    unique_tiles = {}
    tile_counter = 0

    # Process each frame
    for frame_idx, frame_file in enumerate(frame_files):
        if frame_idx % 100 == 0:
            print(f"Processing frame {frame_idx}/{len(frame_files)}")

        # Read the frame data (240x160 pixels, 4-bit grayscale)
        with open(frame_file, 'rb') as f:
            frame_data = f.read()

        # Convert to numpy array for easier processing
        frame_array = np.frombuffer(frame_data, dtype=np.uint8)
        frame_array = frame_array.reshape(160, 240)

        # Create tile map for this frame (30x20 tiles)
        tile_map = np.zeros((20, 30), dtype=np.uint32)

        # Process each 8x8 tile
        for tile_y in range(20):
            for tile_x in range(30):
                # Extract 8x8 tile from frame
                start_y = tile_y * 8
                start_x = tile_x * 8
                tile = frame_array[start_y:start_y+8, start_x:start_x+8]

                # Convert tile to bytes for storage
                tile_bytes = tile.tobytes()

                # Check if we've seen this tile before
                if tile_bytes not in unique_tiles:
                    unique_tiles[tile_bytes] = tile_counter
                    tile_counter += 1

                    # Debug output every 1000 tiles
                    if tile_counter % 1000 == 0:
                        print(f"  Created {tile_counter} unique tiles so far...")

                    # Save the tile
                    tile_filename = f"assets/tiles/tile_{tile_counter-1:04d}.raw"
                    with open(tile_filename, 'wb') as f:
                        f.write(tile_bytes)

                # Store tile index in tile map
                tile_map[tile_y, tile_x] = unique_tiles[tile_bytes]

        # Save tile map for this frame
        map_filename = f"assets/tilemaps/frame_{frame_idx:04d}.map"
        with open(map_filename, 'wb') as f:
            f.write(tile_map.tobytes())

    # Create tile index file
    with open("assets/tiles/tile_index.txt", 'w') as f:
        f.write(f"Total unique tiles: {len(unique_tiles)}\n")
        f.write(f"Tiles per frame: 600 (30x20)\n")
        f.write(f"Total frames: {len(frame_files)}\n")
        f.write(f"Space saved: {len(frame_files) * 38400 - len(unique_tiles) * 64} bytes\n")

    print(f"\nTile system created!")
    print(f"Unique tiles: {len(unique_tiles)}")
    print(f"Tiles per frame: 600")
    print(f"Space saved: {len(frame_files) * 38400 - len(unique_tiles) * 64} bytes")

    # Show some statistics
    if len(unique_tiles) > 0:
        print(f"Average tiles per frame: {len(frame_files) * 600 / len(unique_tiles):.1f}")
        print(f"Compression ratio: {(1 - len(unique_tiles) * 64 / (len(frame_files) * 38400)) * 100:.1f}%")

def analyze_tile_reuse():
    """Analyze how much tile reuse we get"""
    print("\nAnalyzing tile reuse patterns...")

    # Count tile usage across all frames
    tile_usage = defaultdict(int)

    map_files = glob.glob("assets/tilemaps/frame_*.map")
    for map_file in map_files:
        with open(map_file, 'rb') as f:
            tile_map = np.frombuffer(f.read(), dtype=np.uint8)
            for tile_id in tile_map:
                tile_usage[tile_id] += 1

    # Show most and least used tiles
    sorted_usage = sorted(tile_usage.items(), key=lambda x: x[1], reverse=True)

    print(f"Most used tiles:")
    for tile_id, count in sorted_usage[:10]:
        print(f"  Tile {tile_id}: used {count} times")

    print(f"\nLeast used tiles:")
    for tile_id, count in sorted_usage[-10:]:
        print(f"  Tile {tile_id}: used {count} times")

    # Calculate reuse efficiency
    total_tile_instances = sum(tile_usage.values())
    unique_tiles = len(tile_usage)
    reuse_efficiency = total_tile_instances / unique_tiles if unique_tiles > 0 else 0

    print(f"\nReuse efficiency: {reuse_efficiency:.1f}x")
    print(f"Total tile instances: {total_tile_instances}")
    print(f"Unique tiles: {unique_tiles}")

if __name__ == "__main__":
    create_tile_system()
    analyze_tile_reuse()
