"""
Example: How to use ppt_to_video as a Python module
"""

import asyncio
import os
import sys

# Add scripts to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

from ppt_to_video import (
    parse_ppt,
    generate_tts_scripts,
    generate_tts_audio,
    measure_audio_durations,
    fix_ppt_animations,
    record_slideshow,
    encode_video_ffmpeg,
    merge_audio,
    final_merge,
    generate_srt,
    binary_copy,
    log
)


def convert(pptx_path, output_path='output.mp4', voice='zh-CN-XiaoxiaoNeural', rate='+10%'):
    """Full conversion pipeline example"""

    import tempfile, json
    work_dir = tempfile.mkdtemp()
    audio_dir = os.path.join(work_dir, 'audio')
    frames_dir = os.path.join(work_dir, 'frames')
    fixed_pptx = os.path.join(work_dir, 'fixed.pptx')

    # 1. Parse PPT
    log("解析PPT...")
    slide_count, slide_texts, anim_counts = parse_ppt(pptx_path)
    log(f"  {slide_count} slides, {sum(anim_counts)} animations")

    # 2. Generate TTS
    log("生成配音...")
    scripts = generate_tts_scripts(slide_texts, slide_count)
    asyncio.run(generate_tts_audio(scripts, audio_dir, voice, rate))

    # Measure durations
    durations = measure_audio_durations(audio_dir, slide_count)
    total_dur = sum(durations)
    log(f"  总时长: {total_dur:.1f}s")

    # 3. Fix animations
    log("修复动画...")
    changes = fix_ppt_animations(pptx_path, fixed_pptx)
    log(f"  修复: {changes}个动画")

    # 4. Record
    log("录制放映...")
    frames, fps = record_slideshow(fixed_pptx, total_dur, durations, frames_dir)

    # 5. Encode
    log("编码视频...")
    video_path = os.path.join(work_dir, 'video.mp4')
    encode_video_ffmpeg(frames_dir, fps, video_path)

    # 6. Merge audio
    log("合并音频...")
    merged = os.path.join(work_dir, 'merged.mp3')
    merge_audio(audio_dir, slide_count, merged)

    # 7. Final merge
    log("最终合成...")
    temp_final = os.path.join(work_dir, 'final.mp4')
    final_merge(video_path, merged, temp_final)

    # Copy to output
    size = binary_copy(temp_final, output_path)
    log(f"完成! {size/1024/1024:.2f}MB")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python example_usage.py <presentation.pptx>")
        sys.exit(1)
    convert(sys.argv[1])