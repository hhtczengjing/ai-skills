# drawio-designer 技能参考

## 概述

本目录包含 `drawio-designer` 技能的参考文档。该技能让 Claude Code / Trae AI 能正确构建和管理 `.drawio` XML 架构图，保持一致的排版、布局与视觉保真度。

## 关键：XML 合法性规则（必须遵循）

这些规则是强制性的。违反会导致 draw.io 将文件报告为“损坏”并拒绝打开。

### 1. 禁止 XML 注释

draw.io 的 XML 解析器**不支持** XML 注释（`<!-- ... -->`）。使用注释会损坏文件。

```
错误：<!-- 这是一条注释 -->
正确：（完全省略注释，或用 mxCell 作为标签）
```

### 2. `value` 属性中禁止原始特殊 Unicode 字符

制表符字符（`━`、`─`、`│`、`┌` 等）及其他特殊 Unicode 出现在 `value` 属性中会导致解析错误。改用普通 ASCII 分隔符。

```
错误：value="Header&#xa;━━━━━━━━━━━━━━━&#xa;Content"
正确：value="Header&lt;br&gt;------------------------&lt;br&gt;Content"
```

### 3. `value` 中的富文本使用 HTML 实体

`value` 属性中的所有文本内容都必须使用 HTML 编码：

- 换行：使用 `&#xa;`（XML 实体）或 `&lt;br&gt;`（设置 `html=1` 时的 HTML 标签）
- 加粗：`&lt;b&gt;text&lt;/b&gt;`
- 字号：`&lt;font style="font-size: 20px;"&gt;text&lt;/font&gt;`
- 切勿在 value 中使用原始 `<` 或 `>`——始终转义为 `&lt;` / `&gt;`

### 4. 完整的 `<mxfile>` 包装

`<mxfile>` 元素必须包含标准属性。缺少属性会导致 draw.io 拒绝打开文件。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2026-08-12" agent="Claude" version="21.0.0" type="device">
  <diagram name="Page-1" id="unique-id">
    <mxGraphModel dx="1422" dy="794" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="1200" math="0" shadow="0">
```

不要在 `<mxGraphModel>` 上设置 `defaultFontFamily`——改为通过 style 字符串按元素设置。

### 5. 边标签样式格式

边标签的 `style` 必须以 `edgeLabel;` 为前缀、后接其他属性，且不要在边标签里使用 `fontFamily`（旧格式，可能导致解析问题）：

```xml
# 正确的边标签
<mxCell id="e1l" value="Label" style="edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;points=[];fontSize=11;" connectable="0" vertex="1" parent="e1">

# 错误：使用旧格式且带 fontFamily，可能出错
<mxCell id="e1l" value="Label" style="edgeLabel;fontSize=11;fontFamily=Noto Sans JP;html=1;..." ...>
```

### 6. 自闭合标签

始终使用自闭合格式 `<mxCell ... />` 和 `<mxGeometry ... />`（结尾空格 + `/`）。这是 draw.io 的标准格式。

### 7. 保存前校验

生成 `.drawio` 文件后，始终用以下命令校验：

```bash
xmllint --noout your-diagram.drawio 2>&1 && echo "OK"
```

## 技术细节

AI 直接与 draw.io 图表的原始 `mxGraphModel` XML 结构交互。

### 布局算法（强制——避免图表拥挤）

**最常见的失败模式是元素放得太近。**写任何 XML 之前，你必须遵循此算法。

#### 第 0 步：根据文本内容计算元素尺寸（先做这一步）

**每个元素的宽高由文本内容决定。**切勿使用任意尺寸。

**12px 字号下的字符宽度：**

- CJK 字符（中/日/한）：**15px**
- 拉丁字母（a-z、A-Z）：**7.5px**
- 数字（0-9）：**7.5px**
- 空格/标点：**4-7.5px**

**其他字号按比例缩放**：乘以 (fontSize / 12)。例如 14px 时：CJK=17.5px，拉丁=8.75px。

**宽度公式：**

```
textWidth = Σ 各字符宽度
rectWidth = textWidth + 32  （每侧 16px 留白）→ 向上取整到最近的 10
iconBBoxWidth = max(80, textWidth + 20)  （图标主体为 80，标签可外扩）
```

**高度公式：**

```
lineHeight = fontSize × 1.4  （12px 字号 → 每行 17px）
textHeight = numLines × lineHeight
rectHeight = textHeight + 24  （上下各 12px 留白）→ 向上取整到最近的 10
iconBBoxHeight = 80 + 20 + labelLineHeight  （图标 + 间隙 + 标签）
```

**速查表：**

| 文本内容 | 字号 | 计算宽度 | 取整后的元素宽度 |
|-------------|------|------------------|----------------------|
| "用户"（2 CJK） | 12px | 30 + 32 = 62 | 70px |
| "数据库"（3 CJK） | 12px | 45 + 32 = 77 | 80px |
| "负载均衡器"（5 CJK） | 12px | 75 + 32 = 107 | 110px |
| "EC2"（3 拉丁） | 12px | 22.5 + 32 = 54.5 | 60px |
| "API Gateway"（11 拉丁） | 12px | 82.5 + 32 = 114.5 | 120px |
| "AWS Lambda Function"（19 拉丁） | 12px | 142.5 + 32 = 174.5 | 180px |
| "微服务架构图"（7 CJK） | 14px | 7×17.5 + 32 = 154.5 | 160px |

#### 第 1 步：确定布局模式

| 模式 | 使用场景 | 示例 |
|---------|------------|---------|
| 线性流程 | 顺序步骤 | A → B → C → D |
| 分层/层级 | 组件按层分组（前端/后端/数据） | Web → API → DB |
| 中心辐射 | 中心组件带放射状连接 | API Gateway → 多个服务 |
| 网格/矩阵 | 多个相似组件 | 微服务阵列 |
| 树形 | 层级结构 | 组织架构图、决策树 |

#### 第 2 步：统计元素并计算网格

**根据文本计算每个元素尺寸后**（第 0 步），再计算网格：

```
maxCols = 任意单行中的最大元素数
maxRows = 最大层级/行数

maxElementWidth  = 所有元素中的最大宽度（来自第 0 步计算）
maxElementHeight = 所有元素中的最大高度（来自第 0 步计算）

hGap = max(120px, 0.3 × maxElementWidth)   （至少 120px，元素越宽越大）
vGap = max(140px, 0.3 × maxElementHeight)  （至少 140px，元素越高越大）

cellWidth  = maxElementWidth  + hGap
cellHeight = maxElementHeight + vGap

canvasWidth  = marginL + (maxCols × cellWidth)  + marginR
canvasHeight = marginT + (maxRows × cellHeight) + marginB

marginL = marginR = marginT = marginB = 60px（最小值）
```

将 canvasWidth 与 canvasHeight 向上取整到最近的 200，作为 `pageWidth`/`pageHeight` 属性值。

**混合宽度元素示例：**

```
第 0 行元素：
  "用户"（宽 70px）
  "API Gateway"（宽 120px）
  "负载均衡器"（宽 110px）

maxElementWidth = 120px（最宽元素）
hGap = max(120, 0.3 × 120) = max(120, 36) = 120px

cellWidth = 120 + 120 = 240px
canvasWidth = 60 + (3 × 240) + 60 = 780 → 取整为 800
```

**注意**：同一列的所有元素共享相同的 x 坐标，即使宽度不同。它们在网格单元内居中，因此较窄的元素周围留白更多。

#### 第 3 步：分配位置

对于网格位置 `(col, row)` 上的每个元素：

```
element.x = marginL + col × cellWidth  + (cellWidth  - elementWidth)  / 2
element.y = marginT + row × cellHeight + (cellHeight - elementHeight) / 2
```

这使每个元素在其网格单元内居中，保证最小间距。

#### 第 4 步：容器尺寸

对于每个容器（虚线框、VPC、子网等）：

```
container.x      = minChildX - 60
container.y      = minChildY - 60
container.width  = (maxChildX + maxChildWidth) - minChildX + 120
container.height = (maxChildY + maxChildHeight) - minChildY + 120
```

#### 第 5 步：边路由

对于源与目标之间的每条边：

1. 确定最佳出口/入口侧：
   - 垂直流程：`exitX=0.5;exitY=1`（底部）→ `entryX=0.5;entryY=0`（顶部）
   - 水平流程：`exitX=1;exitY=0.5`（右侧）→ `entryX=0;entryY=0.5`（左侧）
   - 同一行、不同列：使用左/右侧
   - 同一列、不同行：使用上/下侧

2. 若边会穿过其他元素，添加中间路径点：
   ```xml
   <mxGeometry relative="1" as="geometry">
     <Array as="points">
       <mxPoint x="600" y="300" />
       <mxPoint x="600" y="400" />
     </Array>
   </mxGeometry>
   ```

3. 同一对元素之间的平行边，将路径点偏移 30-40px。

#### 第 6 步：验证（写 XML 前在脑中核对）

对于每一对元素，核对：

- [ ] 它们的包围盒（含图标下方 30px 标签空间）不重叠
- [ ] 无边穿过另一元素的包围盒
- [ ] 边标签不与其他元素或边重叠
- [ ] 容器边界距最内层子元素 ≥60px

若任一检查不通过，增大间距并重新计算。

### 具体示例

布局：3 层架构，User → [API Gateway, CDN] → [EC2, Lambda] → RDS

```
网格：2 列 × 3 层
元素尺寸：80×80（图标）
hGap = 200px，vGap = 160px
cellWidth = 80 + 200 = 280px，cellHeight = 80 + 160 = 240px
margin = 60px

canvasWidth  = 60 + 2×280 + 60 = 680 → 取整为 800
canvasHeight = 60 + 3×240 + 60 = 840 → 取整为 1000

位置：
  (col=0, row=0) User：    x=60,  y=60
  (col=1, row=0) CDN：      x=340, y=60
  (col=0, row=1) API GW：   x=60,  y=300
  (col=1, row=1) Auth：     x=340, y=300
  (col=0, row=2) EC2：      x=60,  y=540
  (col=1, row=2) Lambda：   x=340, y=540
```

### 元素定位

Draw.io 使用绝对坐标（`x`、`y`）与尺寸（`width`、`height`）。AI 必须用数学方法计算相对定位以避免元素重叠。

- 中心通常计算为 `x + width/2` 与 `y + height/2`
- 边（箭头）必须连接到源/目标点，或定义显式的入口/出口向量。
- 边样式必须包含 `strokeColor` 与 `strokeWidth`，否则线渲染不可见

### 边样式

边样式必须始终显式定义 `strokeColor` 与 `strokeWidth`：

```xml
# 正确的边样式
<mxCell id="arrow1" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=2;" edge="1" parent="1" source="src" target="tgt">

# 带虚线样式的边
<mxCell id="arrow2" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;dashed=1;strokeColor=#82b366;strokeWidth=2;" edge="1" parent="1" source="src" target="tgt">
```

### 架构图标

`scripts/find-arch-icon.py` 工具帮助将常用术语（如 "EC2"、"pod"、"router"、"database"）映射到具体的 draw.io style 字符串。它支持 AWS、Kubernetes、网络（Cisco）与通用 IT 图标，并采用无头渲染所需的严格样式格式。

### PNG 转换

转换由外部完成。可通过 `pre-commit` 钩子（若仓库中已配置）触发，或通过提供的 `scripts/drawio-to-png.sh` 包装脚本触发，后者依赖 `drawio-batch` 等标准 CLI 工具。

### 字体管理

不要在 `<mxGraphModel>` 上设置 `defaultFontFamily`——这会导致某些 draw.io 版本的兼容性问题。改为通过 style 字符串为单个文本元素应用 `fontFamily`：

```xml
<mxCell id="text1" value="Text" style="text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];strokeColor=none;fillColor=none;fontFamily=Noto Sans JP;" vertex="1" parent="1">
```
