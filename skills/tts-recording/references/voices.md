# 可用语音

## 查询当前系统

```bash
say -v "?"
```

## 中文（普通话 / 粤语 / 国语）

| Voice | Locale | 备注 |
|---|---|---|
| Tingting | zh_CN | 普通话女声（**默认**，速度约 243 字/分） |
| Sinji | zh_HK | 粤语女声 |
| Meijia | zh_TW | 台湾普通话女声 |
| Sandy (中文（中国大陆）) | zh_CN | 增强普通话女声 |
| Shelley (中文（中国大陆）) | zh_CN | 增强普通话女声 |
| Reed (中文（中国大陆）) | zh_CN | 增强普通话男声 |
| Flo (中文（中国大陆）) | zh_CN | 增强普通话 |
| Eddy (中文（中国大陆）) | zh_CN | 增强普通话 |
| Grandma (中文（中国大陆）) | zh_CN | 增强普通话 |
| Grandpa (中文（中国大陆）) | zh_CN | 增强普通话 |
| Rocko (中文（中国大陆）) | zh_CN | 增强普通话 |

> 增强语音（带括号显示）是 macOS Monterey+ 的高质量语音，单独下载，系统设置 → 辅助功能 → 朗读内容 → 系统语音 → 自定义可下载。

## 英文（美式 / 英式）

| Voice | Locale | 备注 |
|---|---|---|
| Samantha | en_US | 美式女声（**默认**，速度约 175 词/分） |
| Alex | en_US | 美式男声 |
| Daniel | en_GB | 英式男声 |
| Karen | en_AU | 澳式女声 |
| Moira | en_IE | 爱式女声 |
| Tessa | en_ZA | 南非女声 |
| Veena | en_IN | 印度女声 |

## 速度参考

中文（Tingting 实测）：约 240–250 字/分钟
英文（Samantha 实测）：约 170–180 词/分钟

不同 voice 之间速度差异可达 ±30%。脚本会通过基线测速自动适配，无需手动指定 `--rate`。
