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

def extract_frames_from_video(video_path, output_dir, start_time=0.0, duration=30.0, target_fps=30):
    """Extract frames from video and save as raw binary data"""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Open video
    cap = cv2.VideoCapture(video_path)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_duration = total_frames / fps

    print(f"Video: {total_frames} frames at {fps:.2f} fps ({total_duration:.2f} seconds)")
    print(f"Extracting: {start_time:.1f}s to {start_time + duration:.1f}s ({duration:.1f}s total)")
    print(f"Target: {target_fps} FPS playback")

    # Calculate frame range
    start_frame = int(start_time * fps)
    end_frame = int((start_time + duration) * fps)
    frame_range = end_frame - start_frame

    # Calculate step size based on source FPS vs target FPS
    if fps > target_fps:
        step = int(fps / target_fps)  # Skip frames to match target FPS
        actual_frames = frame_range // step
    else:
        # If source FPS <= target FPS, we need to extract fewer frames
        # to maintain the same duration
        step = 1
        actual_frames = int((duration * target_fps))  # Extract frames for target FPS duration

    # For 30fps source to 10fps target, extract frames at 10fps rate
    if fps == 30 and target_fps == 10:
        step = int(fps / target_fps)  # 30 / 10 = 3, extract every 3rd frame
        actual_frames = int((duration * target_fps))  # 30 seconds * 10fps = 300 frames




    print(f"Frame range: {start_frame} to {end_frame} ({frame_range} frames)")
    print(f"Will extract: {actual_frames} frames at {fps} FPS")
    print(f"Playback: {actual_frames} frames ÷ {target_fps} FPS = {actual_frames/target_fps:.1f} seconds")

    # Extract frames directly
    frame_count = 0
    frame_index = start_frame

    while frame_count < actual_frames and frame_index < end_frame:
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
            if frame_count % 100 == 0:
                print(f"Extracted {frame_count} frames...")

        frame_index += step

    cap.release()
    print(f"Extracted {frame_count} frames to {output_dir}")
    print(f"Quality: {fps} FPS source → {target_fps} FPS playback")
    print(f"Playback: {frame_count} frames ÷ {target_fps} FPS = {frame_count/target_fps:.1f} seconds")

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

    # Clean up old frames to avoid confusion
    import shutil
    frames_dir = Path("assets/simple_frames")
    if frames_dir.exists():
        print("Cleaning up old frames...")
        shutil.rmtree(frames_dir)
    frames_dir.mkdir(parents=True, exist_ok=True)

    # Configuration - target: 10 FPS, first 30 seconds, real-time playback
    START_TIME = 0.0      # Start at beginning of video
    DURATION = 30.0       # Extract first 30 seconds (fits in GBA ROM)
    TARGET_FPS = 10       # Target 10 FPS playback (reduced for audio performance)

    # For higher quality, reduce duration:
    # DURATION = 15.0      # 15 seconds = higher quality
    # DURATION = 10.0      # 10 seconds = even higher quality

    # Extract frames
    frames_dir = "assets/simple_frames"
    extract_frames_from_video(
        video_path,
        frames_dir,
        start_time=START_TIME,
        duration=DURATION,
        target_fps=TARGET_FPS
    )

    # Generate Zig code
    output_file = "src/assets/simple_frames.zig"
    generate_zig_code(frames_dir, output_file)

    print("\n🎬 Frame extraction complete!")
    print("📱 Now you can import 'simple_frames.zig' in your main.zig")
