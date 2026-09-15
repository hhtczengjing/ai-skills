# 算法细节

## 1. 基线测速

合成 80 字左右的样本文本，测量实际朗读时长，换算为「字/分钟」：

```
rate = zh_chars(sample) / duration_sec * 60
```

为什么是 80 字？
- 太短（< 30 字）：受 `say` 启动开销影响，速度失真
- 太长（> 200 字）：浪费每次调用的几秒钟
- 80 字在 macOS 上稳定在 20 秒左右，是好折中

## 2. 目标字数估算

```
target_chars = ceil(target_seconds * rate / 60 * 1.05)
```

1.05 是富余系数——保证源稿 ≥ 目标 5%，留出裁剪空间。

## 3. 循环达标

```
while actual < target * 1.02:
    add = ceil((target * 1.05 - actual) * rate / 60) + 30
    text = extend_text(text, add)
    synthesize(text)
    actual = measure()
```

- 阈值 1.02（2% 富余）而非 1.0，避免裁剪时把最后半句砍掉
- 30 字 buffer 防止「差一点不够」时反复循环
- 默认 3 轮上限，避免死循环

## 4. 裁剪策略

```
ffmpeg -i raw.aiff -t target_seconds -c:a <codec> out.<fmt>
```

为什么不分两步（先裁 aiff 再转格式）？
- 一步完成：省一次 IO，省一次编码
- AIFF 是 PCM 无损，编码后（mp3/aac）的帧边界从 PCM 重新编码更干净

为什么不 `-c copy`？
- 压缩格式（mp3/m4a）的帧边界是 1024/2048 样本的倍数，`-c copy -t` 会停在最后一个完整帧，可能比 target 多 10–50ms
- 重编码时 `-t` 在 sample 级别精确停下，误差 < 1ms

## 5. 校验

`afinfo` 读取最终文件时长，与 target 比对：
- |diff| ≤ 2s：✅
- |diff| > 2s：⚠️ 但仍交付，让用户决定是否重跑

## 6. 输出文件结构

```
tts-output/
  20250915-113000/
    out.m4a        ← 最终交付
    _work/
      raw.aiff     ← 中间产物，可保留以便复用
```

`_work/` 目录保留了未裁剪的 AIFF，便于：
- 重新裁剪到不同时长
- 转其他格式（不用再跑 TTS）
- 调试时长不准的问题

## 7. 为什么不直接用 `say` 的 `-r` 控制速度？

`say -r 200`（词/分钟）确实可以提速，但：
- 用户给的是文稿，不一定能改
- 调速会让声音不自然
- 我们的策略是「稿子不够就加内容」，比「强行加速」更可读
