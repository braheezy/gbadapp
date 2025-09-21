# gbadapp

GBA bad apple. Small demo that plays some of the Bad Apple!! video with full audio.

## Features

- 40 seconds of Bad Apple video at 20fps (240x160 resolution)
- Full synchronized audio playback using `maxmod-zig`
- Optimized DMA transfers for smooth graphics performance

## Prerequisites

- [Zig 0.14.1](https://ziglang.org/)
- [uv](https://github.com/astral-sh/uv) (for Python dependencies)
- [mGBA](https://mgba.io/) emulator
- Bad Apple video file (`src/bad_apple.mp4`)

## Building

1. Generate video frame assets:
```bash
uv run src/create_simple_frames.py
```

2. Build the GBA ROM:
```bash
zig build
```

3. Run on mGBA emulator:
```bash
mgba zig-out/bin/gbadapp.gba
```

## Asset Configuration

Edit `src/create_simple_frames.py` to adjust video parameters:

- `DURATION`: Video length in seconds (default: 40s)
- `TARGET_FPS`: Video framerate (default: 20fps)
- `START_TIME`: Start offset in source video (default: 0s)

## ROM Size

The current configuration generates approximately 29MB ROM files. The GBA has a 32MB limit. I tried several approaches and 20 FPS for 40s seems to give the best tradeoff in length and quality.

The whole video won't fit. The audio does fit, so video freezes at the end and the audio continues.
