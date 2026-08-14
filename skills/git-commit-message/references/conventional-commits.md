# Conventional Commits 参考

## 类型

| type | 用途 |
|------|------|
| feat | 新功能 |
| fix | 修复 bug |
| docs | 仅文档 |
| refactor | 重构（不改变行为） |
| perf | 性能优化 |
| test | 测试 |
| build | 构建 / 依赖 |
| chore | 其他杂项 |

## 格式

```
<type>[可选 scope][!]: <描述>

[可选 body]

[可选 footer]
```

## 示例

- `feat: 添加用户登录功能`
- `fix(parser): 修复数组越界导致的崩溃`
- `feat!: 移除已废弃的旧 API`
- `docs: 补充 README 安装说明`
