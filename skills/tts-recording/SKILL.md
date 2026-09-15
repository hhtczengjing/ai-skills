---
name: tts-recording
description: 当用户需要「生成音频」「TTS 朗读」「把文字变成语音」「5 分钟录音」「播客样带」「学习材料朗读」时使用。基于 macOS `say` 命令生成 AIFF，可转 m4a（AAC）/ mp3 / wav，按目标时长精准裁剪——保证源音频 ≥ 目标时长，再从末尾精确裁剪到目标秒数。无主题时推荐 5 个常见主题（学习/科普/播客/AI 史/心理学），时长和格式均支持自定义输入。
license: MIT
metadata:
  category: media
  version: "1.0.0"
  tags: tts, audio, 录音, 语音合成, say, podcast, audiobook
---

# TTS Recording

把一段文字变成指定时长、任意格式的音频文件。

## 何时用

- 用户给了文字稿，希望转成指定时长的音频（播客样带、学习材料、有声书）
- 用户只给了主题，希望产出一段固定时长的朗读
- 已有 AIFF/WAV，需要转 m4a/mp3 或压到精确时长

## 不适用

- 需要真人录音（用 GarageBand / Audacity）
- 需要多角色对话 / 拟人情感（用 ElevenLabs / Azure TTS）
- 服务器环境（无 macOS `say`）

## 前置

- macOS（依赖 `say`、`afconvert`、`afinfo`）
- Python 3.9+（系统自带可用）
- 转 mp3 时需要 ffmpeg：`brew install ffmpeg`
  - 缺失时脚本会 fail-fast 并给出安装指引，不静默降级

## 使用

```bash
python3 skills/tts-recording/scripts/generate.py \
  --text-file speech.txt \
  --target-seconds 300 \
  --format m4a \
  --voice Tingting \
  --output out.m4a
```

常用参数：

| 参数 | 说明 |
|---|---|
| `--text-file PATH` | 文稿文件路径 |
| `--text "..."` | 内联文本（与 `--text-file` 互斥） |
| `--topic "..."` | 只给主题，让脚本现场写稿（agent 用法） |
| `--target-seconds N` | 目标时长（秒），最终文件 ±2 秒 |
| `--format {m4a,mp3,wav,aiff}` | 输出格式 |
| `--voice NAME` | TTS 语音，默认 `Tingting` |
| `--output PATH` | 输出路径，默认 `./tts-output/<timestamp>/out.<ext>` |
| `--rate WPM` | 覆盖自动测速结果 |

详细见 `python3 generate.py --help`。

## 算法

1. **基线测速**：用 80~100 字样本统计当前 voice 的朗读速率（字/分钟）。不同 voice 速度差 30%+。
2. **估算字数**：`target_chars = ceil(target_seconds × rate / 60 × 1.05)`，预留 5% 富余便于裁剪。
3. **首轮生成**：固定稿一次生成；topic 驱动则先写稿再生成。
4. **测量**：`afinfo` 读实际时长 `actual`。
5. **循环**：
   - `actual < target` → 重写稿 / 加段扩展，再次生成（最多 3 轮）
   - `actual ≥ target × 1.02` → 进入裁剪
6. **裁剪**：用 `ffmpeg -t`（mp3/m4a）或 `afconvert -d`（wav/aiff）从末尾精确截断。
7. **转码**：m4a/aac → `afconvert`；mp3 → `ffmpeg -c:a libmp3lame -q:a 2`。
8. **校验**：`afinfo` 再次确认时长差 ≤ 2 秒。

**精度保证**：最终输出时长 = target ± 2 秒。
**前提保证**：源稿必须 ≥ target × 1.02；不足时报错并提示用户加内容。

详见 [algorithm.md](./references/algorithm.md)。

## Agent 必做：开任务前先问

接到本 skill 后，agent 必须分两阶段用 `AskUserQuestion` 收集信息，不要中途追问其他问题。

### 第一阶段：基础参数（4 个问题，必问）

| # | 问题 | 选项（Other 输入可自定义） |
|---|---|---|
| 1 | **文稿来源** | ① 我提供文件 ② 给主题让 agent 写 ③ 用内置示例 |
| 2 | **目标时长** | ① 1 分钟 ② 3 分钟 ③ 5 分钟 ④ 10 分钟 ⑤ 15 分钟 ⑥ 30 分钟 ⑦ Other 自定义（如「7 分钟」「45 分钟」「120 秒」） |
| 3 | **输出格式** | ① m4a（推荐，体积小）② mp3（兼容广，需 ffmpeg）③ wav（无损）④ aiff（macOS 原生）⑤ Other 自定义（如 flac / ogg） |
| 4 | **输出位置** | ① `./tts-output/<时间戳>/`（默认）② 当前目录 ③ Other 自定义路径（如 `~/Desktop/`） |

> 时长和格式都支持用户选「Other」自由输入。不必列尽所有可能——Common 选项 + Other 已经覆盖 99% 场景。

### 第二阶段：主题选择（仅在第一阶段 Q1 = ② 时触发）

第一阶段答完，根据 Q1 走分支：

#### Q1 = ① 我提供文件
直接进入生产，不需要第二阶段。

#### Q1 = ② 给主题让 agent 写
弹一个**「选一个推荐主题」**问题：

| 选项（5 个推荐 + Other） |
|---|
| 《如何阅读一本书》学习材料（四层阅读法） |
| 《专注力的科学》科普（大脑机制 + 训练方法） |
| 《一天里的二十四小时》播客（时间管理） |
| 《AI 简史：从图灵到 GPT》科普 |
| 《为什么我们会拖延》心理学 |
| Other 自定义主题（agent 据此现场写稿） |

用户选 Other 后，**agent 直接用用户输入的主题写稿**，不再追问。

#### Q1 = ③ 用内置示例
弹一个**「选一个内置示例」**问题：

| 选项（3 个示例 + Other） |
|---|
| [如何阅读一本书] 四层阅读法（5 分钟） |
| [专注力的科学] 大脑机制与训练（5 分钟） |
| [一天的二十四小时] 时间管理（5 分钟） |
| Other 自定义（用户可直接说"用 examples 里的 X"） |

### 三种文稿来源的真相

| 选项 | 主题谁定 | 文稿谁写 |
|---|---|---|
| 我提供文件 | 用户 | 用户已写好 |
| 给主题让 agent 写 | 用户（含推荐列表） | **Agent 当场按主题写** |
| 用内置示例 | 内置 | 脚本读 `examples/*.md` |

**只有第二种模式下，agent 才扮演「写作者」**。第一种是搬运，第三种是引用。

## 规则

- **严格裁剪**：目标 5 分钟，最终文件时长必须在 4:58 ~ 5:02 区间内。
- **不省略文稿**：固定稿 < target 时直接报错，不要静默补字。
- **不污染当前目录**：默认输出到 `./tts-output/<时间戳>/`，避免 13 MB 大文件散落。
- **mp3 必须检测 ffmpeg**：缺失则 fail-fast，不静默降级到其他格式。
- **保存文稿源**：生成的 AIFF + 文稿 .txt 一起落到输出目录，便于复用。
- **推荐主题不限于 examples**：第二阶段列出的 5 个是常见主题；用户随时可走 Other 自定义。

## 参考

- [voices.md](./references/voices.md) — 系统可用中文/英文语音列表
- [troubleshooting.md](./references/troubleshooting.md) — 常见问题（ffmpeg 缺失、语速异常、音频含杂音等）
- [algorithm.md](./references/algorithm.md) — 测速与循环达标算法细节
- [examples/](./examples/README.md) — 3 篇预写好的 5 分钟示例稿（学习方法 / 科普 / 播客）
