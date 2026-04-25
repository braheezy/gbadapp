#!/usr/bin/env -S uv run
# /// script
# dependencies = ["opencv-python", "numpy"]
# ///

"""
Simple frame extraction for Bad Apple demo
Extracts video frames at target FPS and saves as raw binary data
"""

from pathlib import Path
import shutil


def extract_frames_from_video(video_path, output_dir, start_time=0.0, duration=40.0, target_fps=20):
    """Extract frames from video at target FPS and save as raw binary data"""
    import cv2
    import numpy as np

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

    start_frame = int(start_time * fps)
    end_frame = int((start_time + duration) * fps)
    frame_range = end_frame - start_frame
    target_frame_count = int(duration * target_fps)

    print(f"Frame range: {start_frame} to {end_frame} ({frame_range} frames)")
    print(f"Will extract: {target_frame_count} frames at {fps:.1f} FPS")
    print(f"Playback: {target_frame_count} frames ÷ {target_fps} FPS = {target_frame_count/target_fps:.1f} seconds")

    frame_count = 0

    for i in range(target_frame_count):
        source_frame_pos = start_frame + (i * frame_range / target_frame_count)
        frame_index = int(source_frame_pos)

        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_index)
        ret, frame = cap.read()

        if ret:
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            resized = cv2.resize(gray, (240, 160))
            _, binary = cv2.threshold(resized, 128, 1, cv2.THRESH_BINARY)

            output_file = output_dir / f"frame_{frame_count:04d}.raw"
            binary.astype(np.uint8).tofile(output_file)
            frame_count += 1

            if frame_count % 100 == 0:
                print(f"Extracted {frame_count} frames...")

    cap.release()
    print(f"Extracted {frame_count} frames to {output_dir}")
    print(f"Quality: {fps:.1f} FPS source → {target_fps} FPS playback")
    print(f"Playback: {frame_count} frames ÷ {target_fps} FPS = {frame_count/target_fps:.1f} seconds")


def generate_zig_code(frames_dir, output_file):
    """Generate Zig code for all frame data"""
    frames_dir = Path(frames_dir)
    output_file = Path(output_file)

    frame_files = sorted(frames_dir.glob("frame_*.raw"))

    if not frame_files:
        print("No frame files found!")
        return

    # Generate Zig source code
    with open(output_file, "w") as f:
        f.write("// Auto-generated frame data for Bad Apple demo\n")
        f.write("// Contains binary frame data as byte arrays\n\n")

        # Write frame count constant
        f.write(f"pub const FRAME_COUNT: u32 = {len(frame_files)};\n\n")

        # Write each frame as a named aligned object. The renderer uses DMA32,
        # so the ROM source address must be 4-byte aligned.
        for i, frame_file in enumerate(frame_files):
            with open(frame_file, "rb") as frame_f:
                data = frame_f.read()

            hex_data = ", ".join(f"0x{b:02x}" for b in data)
            f.write(f"const frame_{i:04d} align(4) = [_]u8{{ {hex_data} }};\n")

        f.write("\npub const frame_data = [_][]align(4) const u8{\n")
        for i, _ in enumerate(frame_files):
            f.write(f"    &frame_{i:04d},\n")

        f.write("};\n")

    print(f"Generated Zig code for {len(frame_files)} frames...")




if __name__ == "__main__":
    # Path to the Bad Apple video
    video_path = "src/bad_apple.mp4"

    frames_dir = Path("assets/simple_frames")
    if frames_dir.exists():
        shutil.rmtree(frames_dir)
    frames_dir.mkdir(parents=True, exist_ok=True)

    START_TIME = 0.0
    DURATION = 40.0
    TARGET_FPS = 20

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

    print("Frame extraction complete!")
