#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "opencv-python",
#   "numpy",
# ]
# ///

import cv2
import numpy as np
import os

def extract_frames_60fps():
    """Extract many more frames for smooth 60 FPS playback"""

    video_path = "bad_apple.mp4"
    if not os.path.exists(video_path):
        print(f"Video file {video_path} not found!")
        return

    # Create output directory
    os.makedirs("assets", exist_ok=True)

    # Open video
    cap = cv2.VideoCapture(video_path)

    # Get video properties
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    duration = total_frames / fps

    print(f"Video: {fps:.2f} FPS, {total_frames} frames, {duration:.2f} seconds")

    # For smooth 60 FPS playback, we need many more frames
    # Let's extract every frame or every 2nd frame depending on source FPS
    if fps >= 60:
        # Source is 60+ FPS, extract every frame
        frame_interval = 1
        target_frames = total_frames
        print(f"Source is {fps:.0f} FPS, extracting every frame for maximum smoothness")
    else:
        # Source is lower FPS, extract every frame to get maximum detail
        frame_interval = 1
        target_frames = total_frames
        print(f"Source is {fps:.0f} FPS, extracting every frame for maximum detail")

    print(f"Target: {target_frames} frames for smooth 60 FPS playback")
    print(f"Frame interval: {frame_interval}")
    print(f"Estimated playback time: {target_frames / 60:.1f} seconds at 60 FPS")

    frame_count = 0
    saved_count = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Save every frame (or every Nth frame if needed)
        if frame_count % frame_interval == 0:
            # Convert to grayscale
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            # High-quality downscaling with multiple stages
            # Stage 1: Downscale to 4x target size
            stage1_size = (960, 640)
            stage1 = cv2.resize(gray, stage1_size, interpolation=cv2.INTER_LANCZOS4)

            # Stage 2: Apply bilateral filter to preserve edges
            stage2 = cv2.bilateralFilter(stage1, 9, 75, 75)

            # Stage 3: Downscale to 2x target size
            stage2_size = (480, 320)
            stage3 = cv2.resize(stage2, stage2_size, interpolation=cv2.INTER_LANCZOS4)

            # Stage 4: Final downscale to GBA resolution
            final_size = (240, 160)
            stage4 = cv2.resize(stage3, final_size, interpolation=cv2.INTER_LANCZOS4)

            # Apply CLAHE for better contrast
            clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
            enhanced = clahe.apply(stage4)

            # Apply unsharp mask for edge enhancement
            gaussian = cv2.GaussianBlur(enhanced, (0, 0), 1.0)
            unsharp = cv2.addWeighted(enhanced, 1.4, gaussian, -0.4, 0)

            # Clamp values
            unsharp = np.clip(unsharp, 0, 255)

            # Convert to 4-bit with better mapping
            # Use adaptive thresholding for better quality
            scaled = np.zeros_like(unsharp, dtype=np.uint8)

            # Create 16 levels with better distribution
            for i in range(16):
                if i == 0:
                    mask = unsharp < 24
                elif i == 15:
                    mask = unsharp >= 232
                else:
                    lower = 24 + (i - 1) * 14
                    upper = 24 + i * 14
                    mask = (unsharp >= lower) & (unsharp < upper)
                scaled[mask] = i

            # Save as raw 4-bit data
            output_file = f"assets/frame_{saved_count:06d}.ag4"
            scaled.tofile(output_file)

            saved_count += 1
            if saved_count % 100 == 0:
                print(f"Saved {saved_count} frames...")

        frame_count += 1

    cap.release()

    print(f"\n60 FPS frame extraction complete!")
    print(f"Saved {saved_count} frames")
    print(f"These frames will play for {saved_count / 60:.1f} seconds at 60 FPS")
    print(f"ROM usage estimate: ~{saved_count * 38400 / (1024*1024):.1f} MB")

if __name__ == "__main__":
    extract_frames_60fps()
