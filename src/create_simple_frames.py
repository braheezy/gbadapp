#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "opencv-python",
#   "numpy",
# ]
# ///

"""
Create simple frame data for GBA Bad Apple player
Just stores full frames in a simple format
"""

import cv2
import numpy as np
import os
from pathlib import Path

def extract_frames_from_video(video_path, output_dir, max_frames=300):
    """Extract frames from video and convert to simple format"""
    if not os.path.exists(video_path):
        print(f"Video file not found: {video_path}")
        return

    # Create output directory
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Open video
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    print(f"Video: {total_frames} frames at {fps} fps")
    print(f"Extracting {max_frames} frames...")

    # Calculate frame step to get desired number of frames
    step = max(1, total_frames // max_frames)

    frame_count = 0
    frame_index = 0

    while frame_count < max_frames and frame_index < total_frames:
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        ret, frame = cap.read()

        if ret:
            # Convert to grayscale
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            # Resize to GBA resolution (240x160)
            resized = cv2.resize(gray, (240, 160))

            # Convert to binary (black/white) using threshold
            _, binary = cv2.threshold(resized, 128, 1, cv2.THRESH_BINARY)

            # Save as raw binary data
            output_file = output_dir / f"frame_{frame_count:04d}.raw"
            binary.astype(np.uint8).tofile(output_file)

            frame_count += 1
            if frame_count % 50 == 0:
                print(f"Processed {frame_count} frames...")

        frame_index += step

    cap.release()
    print(f"Extracted {frame_count} frames to {output_dir}")

def generate_zig_code(frames_dir, output_file):
    """Generate simple Zig code with frame data"""
    frames_dir = Path(frames_dir)
    frame_files = sorted(list(frames_dir.glob("frame_*.raw")))

    if not frame_files:
        print("No frame files found!")
        return

    print(f"Generating Zig code for {len(frame_files)} frames...")

    with open(output_file, 'w') as f:
        f.write("// Auto-generated frame data for Bad Apple video player\n")
        f.write("// Simple full frame format\n\n")
        f.write(f"pub const FRAME_COUNT = {len(frame_files)};\n")
        f.write("pub const SCREEN_WIDTH = 240;\n")
        f.write("pub const SCREEN_HEIGHT = 160;\n\n")

        f.write(f"pub const frame_data: [{len(frame_files)}][]const u8 = .{{\n")

        for i, frame_file in enumerate(frame_files):
            with open(frame_file, 'rb') as frame_f:
                frame_data = frame_f.read()

            # Convert to Zig array format
            hex_data = ', '.join([f"0x{b:02x}" for b in frame_data])
            f.write(f"    &[_]u8{{ {hex_data} }}, // frame_{i:04d}\n")

        f.write("};\n")

    print(f"Generated {output_file}")

if __name__ == "__main__":
    # Check if we have the MP4 file
    video_path = "bad_apple.mp4"
    if not os.path.exists(video_path):
        print(f"Video file {video_path} not found!")
        print("Please place the Bad Apple MP4 file in the project root directory.")
        exit(1)

    # Extract frames
    frames_dir = "assets/simple_frames"
    extract_frames_from_video(video_path, frames_dir, max_frames=120)

    # Generate Zig code
    output_file = "src/assets/simple_frames.zig"
    generate_zig_code(frames_dir, output_file)

    print("Done! Now you can import 'simple_frames.zig' in your main.zig")
