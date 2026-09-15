#!/usr/bin/env python3
"""TTS Recording — 文字 → 精准时长音频.

流程：测速 → 估算字数 → 循环达标（不足自动扩稿）→ 裁剪到目标秒数 → 转码.

精度：最终输出时长 = target ± 2 秒.
前提：源稿必须 ≥ target × 1.02；不足时循环扩稿，最多 3 轮.
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


# -------- shell helpers --------

def run(cmd: list[str]) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True)
    except subprocess.CalledProcessError as e:
        sys.exit(f"❌ 命令失败：{' '.join(cmd)}\n{e.stderr.strip()}")


def sh(cmd: list[str]) -> str:
    return run(cmd).stdout.strip()


def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


# -------- prerequisites --------

def assert_voice_exists(voice: str) -> None:
    """校验 voice 名是否真实存在；不存在则列出候选。"""
    out = sh(["say", "-v", "?"])
    names = sorted({line.split()[0] for line in out.splitlines() if line.strip()})
    if voice not in names:
        hint = "、".join(names[:30]) + "、…"
        sys.exit(f"❌ 语音 {voice!r} 不存在。可用：{hint}")


def assert_ffmpeg_or_fail() -> None:
    if not have("ffmpeg"):
        sys.exit(
            "❌ 需要 ffmpeg 来裁剪 / 转码，但未安装。\n"
            "   安装命令：brew install ffmpeg\n"
        )


# -------- text helpers --------

def zh_chars(text: str) -> int:
    """中文字符数（CJK 基本平面）。其他字符不计。"""
    return sum(1 for c in text if "一" <= c <= "鿿")


def extend_text(text: str, add_chars: int) -> str:
    """按语种追加占位段落。"""
    if zh_chars(text) > 0:
        body = (
            "再补充一点：这个主题在实际场景里其实还有不少可以展开的方向，"
            "比如它在日常应用中的具体表现、不同条件下的细微差异，"
            "以及它和相邻概念之间的关系。听了之后，不妨回想一下，"
            "哪些点对你最有启发。"
        )
        repeat = max(1, add_chars // max(1, zh_chars(body)))
        filler = body * repeat
    else:
        body = ("Additionally, it is worth noting a few more points about "
                "this topic in practical scenarios and edge cases. ")
        repeat = max(1, add_chars // max(1, len(body)))
        filler = body * repeat
    return text.rstrip() + "\n\n" + filler


# -------- audio helpers --------

def audio_duration(path: Path) -> float:
    """通过 afinfo 读时长（秒）。"""
    out = sh(["afinfo", str(path)])
    m = re.search(r"estimated duration:\s*([\d.]+)\s*sec", out)
    if not m:
        raise RuntimeError(f"无法解析 {path} 时长")
    return float(m.group(1))


def measure_rate(voice: str) -> float:
    """测当前 voice 的稳定朗读速度（字/分钟）。"""
    sample = (
        "这是一段用于测量语音合成引擎稳定朗读速度的样本文字。"
        "我们用一小段固定文本测出每秒字数，再换算到每分钟。"
    ) * 2
    target = 80
    while zh_chars(sample) > target:
        sample = sample[:-5]
    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as f:
        tmp = Path(f.name)
    try:
        run(["say", "-v", voice, "-o", str(tmp), sample])
        d = audio_duration(tmp)
    finally:
        tmp.unlink(missing_ok=True)
    return zh_chars(sample) / d * 60


def synthesize_aiff(text: str, voice: str, out: Path) -> None:
    """say 合成到 AIFF。"""
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False,
                                     encoding="utf-8") as f:
        f.write(text)
        tf = Path(f.name)
    try:
        run(["say", "-v", voice, "-o", str(out), "-f", str(tf)])
    finally:
        tf.unlink(missing_ok=True)


def finalize(input_aiff: Path, output: Path,
             target_seconds: float, fmt: str) -> None:
    """裁剪到 target_seconds 并转码到目标格式（ffmpeg 一步完成）。"""
    if not have("ffmpeg"):
        assert_ffmpeg_or_fail()
    codecs = {
        "mp3":  ["-c:a", "libmp3lame", "-q:a", "2"],
        "m4a":  ["-c:a", "aac",        "-b:a", "128k"],
        "wav":  ["-c:a", "pcm_s16le"],
        "aiff": ["-c:a", "pcm_s16be"],
    }
    run([
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(input_aiff),
        "-t", f"{target_seconds:.3f}",
        *codecs[fmt],
        str(output),
    ])


# -------- main --------

def main() -> None:
    ap = argparse.ArgumentParser(
        description="TTS Recording — 文字 → 精准时长音频")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--text-file", type=Path, help="文稿文件路径")
    src.add_argument("--text", type=str, help="内联文稿（与 --text-file 互斥）")
    src.add_argument("--topic", type=str,
                     help="只给主题（提示 agent 先写稿再传 --text-file）")
    ap.add_argument("--target-seconds", type=float, required=True,
                    help="目标时长（秒），最终 ±2 秒")
    ap.add_argument("--format", choices=["m4a", "mp3", "wav", "aiff"],
                    default="m4a")
    ap.add_argument("--voice", default="Tingting")
    ap.add_argument("--output", type=Path,
                    help="默认 ./tts-output/<时间戳>/out.<格式>")
    ap.add_argument("--rate", type=int,
                    help="覆盖自动测速（每分钟中文字数）")
    ap.add_argument("--max-loops", type=int, default=3,
                    help="循环达标最大轮数")
    args = ap.parse_args()

    if args.topic and not (args.text or args.text_file):
        sys.exit("❌ --topic 仅是 agent 提示；脚本本身需要 --text 或 --text-file")

    assert_voice_exists(args.voice)
    assert_ffmpeg_or_fail()

    text = args.text if args.text else args.text_file.read_text(encoding="utf-8")
    text = text.strip()
    if not text:
        sys.exit("❌ 文稿为空")

    # 输出路径
    if args.output:
        out = args.output
        out.parent.mkdir(parents=True, exist_ok=True)
    else:
        ts = time.strftime("%Y%m%d-%H%M%S")
        out_dir = Path.cwd() / "tts-output" / ts
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / f"out.{args.format}"

    work_dir = out.parent / "_work"
    work_dir.mkdir(exist_ok=True)
    raw_aiff = work_dir / "raw.aiff"

    # 1. 测速
    if args.rate:
        rate = args.rate
        print(f"[1/5] 使用指定语速：{rate} 字/分")
    else:
        rate = measure_rate(args.voice)
        print(f"[1/5] {args.voice} 实测速率：{rate:.1f} 字/分")

    # 2. 估算
    target_chars = int(args.target_seconds * rate / 60 * 1.05)
    print(f"[2/5] 目标字数 ≈ {target_chars}（含 5% 富余）"
          f"，当前文稿 {zh_chars(text)} 字")

    # 3. 循环达标
    actual = 0.0
    for loop in range(1, args.max_loops + 1):
        print(f"[3/5] 第 {loop}/{args.max_loops} 轮 TTS 合成...")
        synthesize_aiff(text, args.voice, raw_aiff)
        actual = audio_duration(raw_aiff)
        print(f"        实际时长：{actual:.2f} 秒 / 目标 {args.target_seconds:.0f} 秒")
        if actual >= args.target_seconds * 1.02:
            break
        if loop < args.max_loops:
            deficit = args.target_seconds * 1.05 - actual
            add = int(deficit * rate / 60) + 30
            text = extend_text(text, add)
            print(f"        时长不足，追加约 {add} 字后重试")

    if actual < args.target_seconds:
        sys.exit(f"❌ {args.max_loops} 轮后仍仅 {actual:.1f} 秒，"
                 f"未达目标 {args.target_seconds:.0f} 秒。请手动扩充文稿。")

    # 4. 裁剪 + 转码
    print(f"[4/5] 裁剪到 {args.target_seconds:.0f} 秒 → {args.format}")
    finalize(raw_aiff, out, args.target_seconds, args.format)

    # 5. 校验
    final = audio_duration(out)
    diff = final - args.target_seconds
    badge = "✅" if abs(diff) <= 2.0 else "⚠️"
    print(f"[5/5] {badge} 输出：{out}")
    print(f"        最终时长：{final:.2f} 秒（diff {diff:+.2f}s）")
    if abs(diff) > 2.0:
        sys.exit(1)


if __name__ == "__main__":
    main()
