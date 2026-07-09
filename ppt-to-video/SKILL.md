---
name: "ppt-to-video"
description: "Convert PPT to video with AI voiceover and synced animations. Invoke when user asks to convert PPT/PPTX to video, create narrated video from slides, or add voiceover to presentation."
---

# PPT to Video Converter

Convert PowerPoint presentations to narrated videos with AI-generated voiceover, preserving all slide animations and styles.

## How It Works

1. **Analyze PPT** - Extract slide count, text content, and animation metadata
2. **Generate TTS** - Create AI voiceover for each slide using edge-tts (zh-CN-XiaoxiaoNeural)
3. **Fix Animations** - Modify PPTX XML to auto-play all animations (avoid click-trigger issues)
4. **Record Slideshow** - Launch WPS COM slideshow, capture screen at native resolution
5. **Encode Video** - FFmpeg encodes frames to 1920x1080 H.264
6. **Merge Audio** - Concatenate per-slide audio, merge with video
7. **Output** - Final MP4 video file (optional ZIP packaging)

## Requirements

- Windows with WPS Office installed (WPS COM: `KWpp.Application`)
- Python 3.8+ with: `edge-tts`, `mss`, `Pillow`, `lxml`, `pywin32`
- FFmpeg + ffprobe (chocolatey: `choco install ffmpeg`)
- Screen resolution: 1920x1080 recommended

## Usage

### Basic Usage

```
User: 帮我把PPT转成视频，要有配音
User: Convert my PPT to video with voiceover
```

The skill will automatically:
1. Read the uploaded PPT file
2. Generate TTS audio for each slide
3. Record the PPT slideshow with animations
4. Output a synced MP4 video

### Advanced Options

- **Duration**: Control per-slide timing by adjusting TTS text length
- **Voice**: Default `zh-CN-XiaoxiaoNeural` (female), can use `zh-CN-YunxiNeural` (male)
- **Rate**: Default `+10%`, adjust for faster/slower speech
- **Subtitles**: Optional, set `ENABLE_SUBTITLES=true` in script
- **Resolution**: Default 1920x1080, adjustable via `TARGET_WIDTH`/`TARGET_HEIGHT`

## Technical Details

### Key Design Decisions

1. **WPS COM over PowerPoint COM**: WPS `KWpp.Application` is more reliable in sandboxed environments. PowerPoint COM may fail due to license/activation issues.

2. **Animation Auto-Play Fix**: The critical step that prevents "PPT plays too fast" issue. We modify the PPTX XML to change `delay="indefinite"` to `delay="0"`, making all click-triggered animations play automatically. This avoids the problem where extra clicks/spacebar presses accidentally advance slides.

3. **Screen Capture**: Use `mss` library for high-performance screen capture. Typical capture rate: 11-15 fps on 1920x1080. The video is encoded at the calculated fps to maintain perfect sync.

4. **Audio Sync**: Per-slide TTS audio is generated first. Slide durations are set to match audio durations exactly. The video is encoded with `calc_fps = total_frames / total_duration` to ensure frame count matches audio length.

5. **Binary Copy**: Due to potential filesystem permission issues, final video is binary-copied (read bytes, write bytes) rather than using file copy utilities.

### Scripts

| Script | Purpose |
|--------|---------|
| `scripts/ppt_to_video.py` | Main pipeline script - runs the full conversion |
| `scripts/fix_ppt_animations.py` | Standalone PPTX animation fixer |

### Output Paths

- **Temporary files**: `c:\Users\Admin\.trae-cn\work\<session_id>\ppt_video\`
  - `audio/` - Per-slide MP3 files
  - `frames/` - Captured JPEG frames
  - `video.avi` - OpenCV encoded video (if FFmpeg fails)
  - `merged.mp3` - Concatenated audio
- **Final output**: `d:\trae\wendang\ppt-video-final.mp4`
- **ZIP package**: `d:\trae\wendang\ppt-video-final.zip`

## Troubleshooting

| Problem | Solution |
|---------|----------|
| PPT plays too fast | Ensure animation fix is applied (`fix_ppt_animations.py`) |
| WPS COM not found | Install WPS Office, verify `KWpp.Application` in registry |
| FFmpeg can't write files | Use OpenCV encoding fallback or pipe mode |
| Audio out of sync | Verify `calc_fps = valid_frames / total_audio_duration` |
| Empty video file | Binary-copy from C: to D: instead of direct write |
| Low fps | Close other apps, reduce monitor resolution to 1920x1080 |

## Workflow Example

```python
# 1. User uploads presentation.pptx
# 2. Skill reads PPT, extracts text
# 3. Generate TTS (12 slides → 12 MP3 files, ~2.5 min total)
# 4. Fix animations (XML: indefinite → 0)
# 5. Launch WPS slideshow, record 145s
# 6. Encode: 1888 frames @ 12.96fps → 1920x1080 H.264
# 7. Merge audio + video → final.mp4
# 8. Output: 4.47MB ZIP
```

## Limitations

- Windows only (requires WPS COM)
- Screen capture fps depends on hardware (typically 11-15fps)
- TTS uses edge-tts (requires internet connection)
- No support for embedded video/audio in PPT slides
- Animations are auto-played (individual click timing is not preserved)