# PPT to Video Converter - 技能包

将 PowerPoint 演示文稿转换为带 AI 配音的同步视频，保留所有幻灯片动画效果。

## 快速开始

### 方式一：在 TRAE 中使用
直接上传 PPT 文件，然后说：
> 帮我把PPT转成视频，要有配音

技能会自动启动，完成全流程。

### 方式二：命令行独立使用

```bash
# 安装依赖
pip install edge-tts mss Pillow lxml python-pptx pywin32

# 基本用法
python scripts/ppt_to_video.py presentation.pptx

# 完整选项
python scripts/ppt_to_video.py presentation.pptx \
    --voice zh-CN-XiaoxiaoNeural \
    --rate "+10%" \
    --output my-video.mp4 \
    --zip \
    --subtitles

# 仅修复PPT动画（不录制）
python scripts/fix_ppt_animations.py input.pptx output.pptx
```

## 目录结构

```
ppt-to-video/
├── SKILL.md                          # 技能描述文件
├── README.md                         # 本文件
├── scripts/
│   ├── ppt_to_video.py               # 主流程脚本（命令行可用）
│   └── fix_ppt_animations.py         # PPT动画修复工具（独立可用）
└── examples/
    └── example_usage.py              # 使用示例
```

## 工作流程

```
PPTX文件 ──→ 解析内容 ──→ 生成配音 ──→ 修复动画 ──→ 录制放映 ──→ 编码视频 ──→ 合并音频 ──→ 最终视频
              │              │            │              │             │             │
         提取文字+       edge-tts      indefinite    WPS COM放映    FFmpeg      音视频合并
         动画数量        12段MP3        → 0(自动)     屏幕捕获      H.264编码    AAC编码
```

## 关键技术点

### 1. 动画自动播放修复
**问题**: WPS 放映时，按空格不仅触发动画，还会翻页。多余的点击导致PPT秒过。

**解决方案**: 修改 PPTX 的 XML，把 `delay="indefinite"` 改为 `delay="0"`，让所有动画进入页面后自动播放。录制时只需在每页音频播完时按右箭头翻页。

### 2. 音画同步
- 先生成 TTS 音频，测量每段时长
- 每页幻灯片停留时间 = 该页音频时长
- 视频帧率 = 总帧数 ÷ 总音频时长（确保帧数与音频对齐）
- 典型偏差 < 0.1 秒

### 3. WPS COM 自动化
使用 `KWpp.Application` COM 对象启动放映：
```powershell
$wpp = New-Object -ComObject KWpp.Application
$pres = $wpp.Presentations.Open("path.pptx")
$pres.SlideShowSettings.Run()
```

### 4. 屏幕捕获
使用 `mss` 库捕获屏幕，JPEG 质量编码到内存队列，后台线程写盘。典型帧率 11-15 fps。

## 配置选项

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `voice` | `zh-CN-XiaoxiaoNeural` | TTS语音（女声） |
| `rate` | `+10%` | 语速 |
| `--subtitles` | off | 是否添加字幕 |
| `--zip` | off | 是否打包为ZIP |
| Resolution | 1920x1080 | 输出分辨率 |

### 可用语音

| 语音ID | 性别 | 风格 |
|--------|------|------|
| `zh-CN-XiaoxiaoNeural` | 女 | 温暖自然（推荐） |
| `zh-CN-YunxiNeural` | 男 | 沉稳大气 |
| `zh-CN-YunyangNeural` | 男 | 专业播报 |
| `zh-HK-HiuMaanNeural` | 女 | 粤语 |
| `en-US-JennyNeural` | 女 | 英文女声 |
| `en-US-GuyNeural` | 男 | 英文男声 |

## 常见问题

### Q: PPT播放太快，30秒就播完了
**A**: 确保执行了动画修复步骤（`fix_ppt_animations.py`）。未修复的动画需要点击触发，录制时按空格会导致翻页。

### Q: 视频文件为0字节
**A**: FFmpeg 可能因权限无法写目标目录。使用 `binary_copy` 或先输出到 `C:\Users\` 再复制。

### Q: WPS COM 启动失败
**A**: 确保已安装 WPS Office。检查注册表 `HKCR\KWpp.Application` 是否存在。

### Q: 帧率太低
**A**: 关闭其他程序，降低屏幕分辨率到 1920x1080。`mss` 捕获性能取决于硬件。

## 系统要求

- Windows 10/11
- WPS Office（最新版）
- Python 3.8+
- FFmpeg（`choco install ffmpeg`）
- 屏幕分辨率 1920x1080

## 许可

自由使用和分享。TTS 使用 Microsoft Edge TTS 服务（免费）。