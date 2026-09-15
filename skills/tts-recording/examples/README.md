# 示例文稿（examples/）

预写好的中文文稿，可直接喂给 `generate.py`。每篇约 1230 中文字，对应 Tingting 普通话约 5 分钟时长。

| 文件 | 主题 | 时长 |
|---|---|---|
| `reading-method.md` | 学习方法：《如何阅读一本书》四层阅读法 | 5 分 05 秒 |
| `focus-science.md` | 科普：专注力的科学原理与训练方法 | ~5 分钟 |
| `daily-24h.md` | 播客：一天 24 小时的合理使用 | ~5 分钟 |

## 用法

```bash
python3 skills/tts-recording/scripts/generate.py \
  --text-file skills/tts-recording/examples/reading-method.md \
  --target-seconds 300 \
  --voice Tingting \
  --format m4a \
  --output ~/Desktop/reading.m4a
```

## 扩展示例

要加新主题的示例稿，按以下规范：

1. 中文为主，字数 ≈ `target_seconds × 250 字/分钟 × 1.05`
2. 段落清晰，便于断句；少用生僻字与复杂数字
3. 长度差异不超过 ±10%，避免脚本循环扩稿
