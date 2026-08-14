---
name: "drawio-designer"
description: "创建、编辑和管理 draw.io XML 图表，支持转换为 PNG，集成 AWS、K8s 及通用 IT 图标。当用户要求「画架构图」「画流程图」「生成 drawio 图」「修改 drawio 图」时使用。"
license: MIT
metadata:
  category: diagram
  version: "1.0.0"
  tags: diagram, drawio, architecture, aws, kubernetes
---

# drawio-designer 绘图技能

一个用于创建、编辑和管理 draw.io 图表的 Claude Code / Trae AI 技能，达到专业质量标准。

## 用途

本技能支持 AI 辅助创建和维护 draw.io 架构图、流程图与技术文档配图。它确保样式一致、布局合理，并为演示与文档自动转成 PNG。

## 何时使用本技能

当需要以程序化方式操作图表资源或布局结构时使用本技能。核心场景涵盖 XML 修改、格式转换与布局调整：

- 创建或编辑 `.drawio` XML 图表文件
- 将图表转换为透明背景的 PNG 格式
- 以程序化方式调整元素位置与布局
- 确保字体族一致（尤其针对 Quarto 幻灯片）
- 使用官方 AWS、Kubernetes 和通用 IT 图标绘制架构图
- 遵循可访问性标准，保持专业图表质量
- 排查布局问题或元素重叠

## 工作原理

本技能提供直接 XML 编辑与自动化质量检查，确保图表达到专业标准。工作流程包括：

- **直接 XML 编辑**：将 `.drawio` 文件作为结构化 XML 进行操作
- **自动转换**：通过脚本将图表转换为高分辨率 PNG
- **布局计算**：计算合适的间距、对齐与边距
- **图标集成**：检索并集成官方架构图标（AWS、K8s、网络、通用）
- **质量保障**：应用设计原则与可访问性准则

## 关键：布局系统（必须遵循——避免图表拥挤）

糟糕图表的头号原因是**间距不足**。你必须对每张图表应用此布局系统。拥挤、重叠的图表是不可接受的。

### 0. 根据内容确定元素尺寸（必须计算——不要用固定尺寸）

**每个元素的宽高都必须根据其文本内容计算。**切勿使用任意固定尺寸。放不下的文本会被裁剪或换行得杂乱。

#### 字符宽度规则

| 文字类型 | 字号 | 每字符宽度 | 示例 |
|--------|-----------|---------------|---------|
| CJK（中/日/한） | 12px | **14-16px** | "负载均衡器"（5字）→ 70-80px 文本 |
| 拉丁字母（英文） | 12px | **7-8px** | "Load Balancer"（13 字符）→ 91-104px |
| 数字 | 12px | **7-8px** | "8080" → 28-32px |

**其他字号按比例缩放**：14px 乘以约 1.17，16px 乘以约 1.33。

#### 宽度计算公式

```
textWidth = 各字符宽度之和（CJK 字符 × 15px + 拉丁字符 × 7.5px）
elementWidth = textWidth + paddingL + paddingR
```

| 元素类型 | paddingL + paddingR | 最小宽度 |
|-------------|---------------------|---------------|
| 带文本的矩形 | 32px（每侧 16px） | 100px |
| 带底部标签的图标 | 标签宽度决定包围盒 | 80px（图标主体） |
| 仅文本标签 | 20px | textWidth + 20 |
| 容器/分组 | 120px（每侧 60px，环绕子元素） | 由子元素决定 |

#### 高度计算公式

```
lineHeight = fontSize × 1.4   （如 12px 字体 → 每行 17px）
textHeight = numLines × lineHeight
elementHeight = textHeight + paddingT + paddingB
```

| 元素类型 | paddingT + paddingB | 最小高度 |
|-------------|---------------------|---------------|
| 带文本的矩形 | 24px（上下各 12px） | 50px |
| 带底部标签的图标 | 图标主体 + 标签留白 20px | 80px + labelHeight |
| 文本标签（单行） | 8px | 24px |
| 多行文本块 | 24px | numLines × lineHeight + 24 |

#### 具体示例

```
元素："负载均衡器"（5 个 CJK 字符），12px 字号
  textWidth = 5 × 15 = 75px
  矩形宽度 = 75 + 32 = 107px → 取整为 110px
  矩形高度 = 1 × 17 + 24 = 41px → 取整为 50px

元素："AWS Lambda Function"（19 个拉丁字符），12px 字号
  textWidth = 19 × 7.5 = 142px
  矩形宽度 = 142 + 32 = 174px → 取整为 180px

元素：带底部标签 "EC2 实例" 的 EC2 图标（3 拉丁 + 2 CJK + 空格）
  图标主体 = 80×80（固定）
  标签 textWidth = 3×7.5 + 1×4(空格) + 2×15 = 22.5 + 4 + 30 = 56.5px
  包围盒宽度 = max(80, 56.5 + 20) = 80px  ← 图标占主导
  labelHeight ≈ 17px
  包围盒高度 = 80 + 20（间隙）+ 17 = 117px → 取整为 120px

元素：多行注释 "处理流程：\n1. 接收请求\n2. 校验参数\n3. 返回结果"
  = 4 行，12px 字号
  textHeight = 4 × 17 = 68px
  块高度 = 68 + 24 = 92px → 取整为 100px
  宽度 = 最长行 "处理流程："（5 CJK + 冒号）= 5×15 + 8 = 83px + 32 = 115px → 120px
```

#### 尺寸检查清单（放置任何元素之前）

对于图表中的每个元素：

1. 统计其文本中的字符数（区分 CJK 与拉丁字母）
2. 用上表计算 textWidth
3. 计算 elementWidth = textWidth + padding → **向上取整到最近的 10**
4. 计算 textHeight（行数 × lineHeight）
5. 计算 elementHeight = textHeight + padding → **向上取整到最近的 10**
6. 图标元素：使用固定图标主体（80×80），但要验证标签能放进包围盒

**然后**将这些计算出的尺寸作为下面第 1–3 节网格/画布计算的输入。

### 1. 间距常量（切勿使用更小的值）

| 场景 | 最小值 | 推荐值 |
|---------|---------|-------------|
| 兄弟元素之间（水平） | 80px | **120-160px** |
| 层/级之间（垂直） | 100px | **140-200px** |
| 元素到容器边界 | 50px | **60-80px** |
| 平行边/线之间 | 30px | **40-60px** |
| 边标签与其他元素的间距 | 40px | **60px+** |
| 分组/容器内部留白 | 40px | **60px** |

**经验法则**：拿不准时，间距翻倍。留白多永远好于留白少。

### 2. 画布尺寸（必须计算，不能猜测）

放置任何元素之前，**先从文本内容计算每个元素的尺寸**（见第 0 节），再计算画布：

```
maxElementWidth  = 所有元素中的最大宽度（内容计算得出后）
maxElementHeight = 所有元素中的最大高度

canvasWidth  = marginLeft + (numCols × maxElementWidth)  + ((numCols - 1) × hGap) + marginRight
canvasHeight = marginTop  + (numRows × maxElementHeight) + ((numRows - 1) × vGap) + marginBottom
```

其中：

- `hGap` ≥ 120px（元素间水平间距）
- `vGap` ≥ 140px（行/级间垂直间距）
- `marginLeft/Right` ≥ 60px
- `marginTop/Bottom` ≥ 60px

然后将 `<mxGraphModel>` 中的 `pageWidth` 与 `pageHeight` 设为至少这些值，**向上取整到最近的 200**。

**示例**：一行 5 个元素，宽度随内容变化：

- "用户"（2 CJK）→ 宽度 = 30 + 32 = 62 → 70px
- "API Gateway"（11 拉丁）→ 宽度 = 83 + 32 = 115 → 120px
- "负载均衡器"（5 CJK）→ 宽度 = 75 + 32 = 107 → 110px
- "EC2 Instance"（12 拉丁）→ 宽度 = 90 + 32 = 122 → 130px
- "数据库"（3 CJK）→ 宽度 = 45 + 32 = 77 → 80px
- maxElementWidth = 130px，hGap = 140px

canvasWidth = 60 + (5 × 130) + (4 × 140) + 60 = 60 + 650 + 560 + 60 = 1320 → 取整为 1400

### 3. 基于网格的定位（必须使用）

在放置元素之前先定义逻辑网格。每个元素都对齐到网格交叉点。

**逐步布局算法：**

1. **识别布局模式**：
   - 线性流程：`A → B → C → D`（水平或垂直）
   - 分层/层级：元素按行排列，层级之间有连接
   - 中心辐射：中心元素带放射状连接
   - 树形：根 → 子 → 孙

2. **计算网格尺寸**：
   - 统计任意行最多元素数（`maxCols`）与任意列最多元素数（`maxRows`）
   - 设单元格宽 = 最大元素宽 + hGap（≥ 120px）
   - 设单元格高 = 最大元素高 + vGap（≥ 140px）

3. **分配网格位置**：每个元素获得一个 `(col, row)` 坐标
   - 元素 x = marginLeft + col × cellWidth
   - 元素 y = marginTop + row × cellHeight

4. **验证无重叠**：对每对元素，检查其包围盒（含标签）不相交。

### 4. 边路由（防止连线缠绕）

- **始终使用 `orthogonalEdgeStyle`**（直角转弯，绝不用斜线）
- **设置 `rounded=1`** 获得平滑圆角
- **使用显式出口/入口点**控制连线位置：
  ```xml
  exitX=0.5;exitY=1;exitDx=0;exitDy=0;   <!-- 从底部中心引出 -->
  entryX=0.5;entryY=0;entryDx=0;entryDy=0; <!-- 在顶部中心进入 -->
  ```
- **平行边带偏移路由**：多条边经过相同区域时，用 `<Array as="points">` 中间路径点将其偏移 30-40px
- **绝不让边穿过其他元素**：若边会穿过某框，添加中间点绕行
- **短边**：对直接相邻的元素，保持直线（无需中间点）

### 5. 容器/分组尺寸

绘制容器（VPC、子网、分组框）时：

1. 找出所有子元素 x、y 的最小/最大值
2. 四周加 **60px 留白**：
   ```
   container.x = minX - 60
   container.y = minY - 60
   container.width  = (maxX + childWidth) - minX + 120
   container.height = (maxY + childHeight) - minY + 120
   ```
3. 将容器标题放在容器上边缘**下方 40px** 处

### 6. 标签间距

- 图标标签（`verticalLabelPosition=bottom`）：图标下方需 **30px**
- 边标签：位于边中点，与边线需 **20px** 间距
- 容器标题：容器上边界下方 **20px**
- 绝不让标签与其他元素或边重叠——若重叠则增大间距

### 7. 生成前检查清单

在写任何 XML 之前，先在脑中核对：

- [ ] 画布足够大（计算得出，非猜测）
- [ ] 已定义网格（元素位置为计算值，非估算）
- [ ] 兄弟元素间水平间距至少 120px
- [ ] 层级间垂直间距至少 140px
- [ ] 容器四周留白 ≥ 60px
- [ ] 已规划边路由（无穿过框的线）
- [ ] 标签有间距（不与其他元素重叠）

**若任一检查不通过，增大间距并重新计算。切勿以拥挤布局继续。**

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
<!-- 正确的边标签 -->
<mxCell id="e1l" value="Label" style="edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;points=[];fontSize=11;" connectable="0" vertex="1" parent="e1">

<!-- 错误：使用旧格式且带 fontFamily，可能出错 -->
<mxCell id="e1l" value="Label" style="edgeLabel;fontSize=11;fontFamily=Noto Sans JP;html=1;..." ...>
```

### 6. 自闭合标签

始终使用自闭合格式 `<mxCell ... />` 和 `<mxGeometry ... />`（结尾空格 + `/`）。这是 draw.io 的标准格式。

### 7. 保存前校验

生成 `.drawio` 文件后，始终用以下命令校验：

```bash
xmllint --noout your-diagram.drawio 2>&1 && echo "OK"
```

## 核心特性

本技能的能力确保复杂架构与技术流程的高保真输出。

### 字体管理

通过严格的样式规则保证各图表间的排版一致：

- 不要在 `mxGraphModel` 上设置 `defaultFontFamily`（会导致兼容性问题）
- 通过 style 字符串为单个文本元素应用 `fontFamily`
- 推荐：使用 `"Noto Sans JP"` 支持日文/中文文本

### PNG 转换

转换工具产出面向文档优化的图像：

- 2x 缩放（高分辨率）
- 透明背景
- 适合演示的 PNG 格式

### 布局调整

**强制间距规则见上文“布局系统”一节。**程序化元素定位确保对齐并防止重叠：

- 放置任何元素前**始终根据元素数量计算画布尺寸**（见布局系统 §2）
- **使用基于网格的定位**——每个元素对齐到 `(col, row)` 网格单元（见布局系统 §3）
- 元素中心：`x + (width / 2)`、`y + (height / 2)`——用于对齐检查
- 兄弟元素间**至少 120px** 水平间距，层级间 **140px** 垂直间距
- 子元素与容器边界之间 **60px** 留白
- 平行边之间 **40-60px** 间距
- 使用显式 `exitX/exitY/entryX/entryY` 定位箭头以控制路由
- 放置所有元素后，验证包围盒（含标签区域）无重叠

### 视觉样式（边与图标）

为确保图表在所有平台与 PNG 转换中正确渲染，必须强制执行严格的样式规则：

- **边（连接线）**：始终在 style 中显式定义 `strokeColor` 与 `strokeWidth`（例如 `style="edgeStyle=orthogonalEdgeStyle;rounded=1;strokeColor=#333333;strokeWidth=2;html=1;"`）。否则线可能渲染不可见。
- **边标签**：标签必须是单独的 `<mxCell>` 元素，带 `vertex="1" connectable="0" parent="[edge_id]"`，而不是边自身的属性。
- **标签重叠预防**：图标通常使用 `verticalLabelPosition=bottom`。从底部引出的垂直连接线会穿过并遮挡该文本。为防止重叠，使用 `exitX`、`exitY` 显式从侧面路由连接线（例如左侧用 `exitX=0;exitY=0.5;exitDx=0;exitDy=0`），并在 `mxGeometry` 中定义 `<Array as="points">` 让边清晰绕过文本。
- **图标**：确保 style 中包含 `html=1` 与 `pointerEvents=1`。AWS 4 资源图标**必须**包含与其 AWS 类别匹配的 `fillColor`，以及 `strokeColor=none`。没有 `fillColor`，SVG 路径在 CLI 导出时会渲染为透明/不可见！
  - _计算_（如 EC2、ECS、Lambda）：`fillColor=#F58536`
  - _数据库_（如 RDS、DynamoDB）：`fillColor=#3355CC`
  - _网络_（如 VPC、API Gateway）：`fillColor=#8C4FFF`
  - _存储_（如 S3）：`fillColor=#4F81A1`
  - _通用/默认_：`fillColor=#232F3E`
  - 示例：`style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.ec2;fillColor=#F58536;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;"`

### 架构图标集成

使用内置脚本检索并集成官方架构服务图标。它支持标准 AWS 资源（`mxgraph.aws4.*`）、Kubernetes 对象（`img/lib/kubernetes/*`）、网络拓扑元素（`mxgraph.cisco.*`）以及通用 IT 元素（数据库、角色、云），并自动套用样式。

### 设计原则

每次修改图表都遵循专业标准以保证清晰度：

- **清晰**：简洁、视觉干净的图表
- **一致**：统一的颜色、字体、图标尺寸、线条粗细
- **准确**：精确的技术表达
- **可访问性**：足够的颜色对比度、图案运用
- **渐进式披露**：复杂系统采用分层图表

### 质量检查清单

自动化校验确保图表通过所有基线布局检查：

- **布局间距**：元素间 ≥120px 水平间距、≥140px 垂直间距
- **容器留白**：子元素与容器边缘之间 ≥60px
- **画布尺寸**：pageWidth/pageHeight 足够大（计算值，非猜测）
- **边路由**：无边穿过元素包围盒
- **标签间距**：标签不与其他任何元素或边重叠
- 无背景色（透明）
- 合适的字号（正文 ≥12px，标题为标准 1.5 倍）
- 箭头置于底层（无重叠）
- 官方服务名与最新图标（AWS、K8s、网络、通用）
- 目视检查 PNG 输出

## 使用示例

以下模式演示创建、转换与检索图表组件的标准做法。

### 创建架构图（完整可运行模板）

**重要**：此模板演示布局系统——注意充足的间距（元素间 140px+、容器留白 60px、根据元素数量计算出的 1600×1200 画布）。遵循所有关键规则——无 XML 注释、无特殊 Unicode、完整的 `<mxfile>` 包装、正确的边标签格式。

> **关于注释**：下方模板 XML 中的 `<!-- ... -->` 注释仅用于解释布局计算过程，**实际生成 `.drawio` 文件时必须全部删除**（见「XML 合法性规则 §1」）。

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" modified="2026-08-12" agent="Claude" version="21.0.0" type="device">
  <diagram name="Page-1" id="example-diagram">
    <mxGraphModel dx="1422" dy="794" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1600" pageHeight="1200" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />

        <!--
          布局计算（放置元素前先做这一步）：
          模式：VPC 容器内的 3 层垂直流程
          第 0 层（row=0）：API Gateway         → y=100
          第 1 层（row=1）：EC2、Lambda         → y=300  （与第 0 层间距 200px）
          第 2 层（row=2）：RDS、S3             → y=500  （与第 1 层间距 200px）
          水平间距：兄弟元素间 200px
          容器留白：所有子元素四周 60px
          画布：1600 × 1200（按元素数量 + 间距计算）
        -->

        <!-- VPC 容器：边界按子元素 + 60px 留白计算 -->
        <mxCell id="vpc" value="" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#999999;strokeWidth=2;dashed=1;" vertex="1" parent="1">
          <mxGeometry x="440" y="40" width="720" height="620" as="geometry" />
        </mxCell>

        <!-- 容器标题：容器顶部下方 40px -->
        <mxCell id="title" value="&lt;b&gt;VPC Architecture&lt;/b&gt;" style="text;html=1;align=center;verticalAlign=middle;resizable=0;points=[];strokeColor=none;fillColor=none;fontSize=16;" vertex="1" parent="1">
          <mxGeometry x="460" y="80" width="680" height="35" as="geometry" />
        </mxCell>

        <!-- 第 0 层：API Gateway（col=1, row=0）→ x=720, y=160 -->
        <mxCell id="api_gateway" value="API Gateway" style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.api_gateway;fillColor=#8C4FFF;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="720" y="160" width="80" height="80" as="geometry" />
        </mxCell>

        <!-- 第 1 层：EC2（col=0, row=1）→ x=560, y=360  |  Lambda（col=2, row=1）→ x=880, y=360 -->
        <!-- EC2 中心(600) 与 Lambda 中心(920) 之间 200px 水平间距 = 相距 320px -->
        <mxCell id="ec2" value="EC2 Instance" style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.ec2;fillColor=#F58536;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="560" y="360" width="80" height="80" as="geometry" />
        </mxCell>

        <mxCell id="lambda" value="Lambda" style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.lambda;fillColor=#F58536;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="880" y="360" width="80" height="80" as="geometry" />
        </mxCell>

        <!-- 第 2 层：RDS（col=0, row=2）→ x=560, y=560  |  S3（col=2, row=2）→ x=880, y=560 -->
        <mxCell id="rds" value="RDS Database" style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.rds;fillColor=#3355CC;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="560" y="540" width="80" height="80" as="geometry" />
        </mxCell>

        <mxCell id="s3" value="S3 Bucket" style="shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.s3;fillColor=#4F81A1;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="880" y="540" width="80" height="80" as="geometry" />
        </mxCell>

        <!-- 边：正交、显式出口/入口点、带标签 -->
        <!-- API Gateway → EC2：从底部中心引出，从顶部中心进入 -->
        <mxCell id="e1" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=2;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;" edge="1" parent="1" source="api_gateway" target="ec2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e1l" value="HTTP" style="edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;points=[];fontSize=11;" connectable="0" vertex="1" parent="e1">
          <mxGeometry x="-0.2" relative="1" as="geometry">
            <mxPoint as="offset" />
          </mxGeometry>
        </mxCell>

        <!-- API Gateway → Lambda：同样模式，右侧 -->
        <mxCell id="e2" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=2;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;" edge="1" parent="1" source="api_gateway" target="lambda">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2l" value="Invoke" style="edgeLabel;html=1;align=center;verticalAlign=middle;resizable=0;points=[];fontSize=11;" connectable="0" vertex="1" parent="e2">
          <mxGeometry x="-0.2" relative="1" as="geometry">
            <mxPoint as="offset" />
          </mxGeometry>
        </mxCell>

        <!-- EC2 → RDS：垂直，同一列 -->
        <mxCell id="e3" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=2;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;" edge="1" parent="1" source="ec2" target="rds">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>

        <!-- Lambda → S3：垂直，同一列 -->
        <mxCell id="e4" value="" style="edgeStyle=orthogonalEdgeStyle;rounded=1;orthogonalLoop=1;jettySize=auto;html=1;strokeColor=#333333;strokeWidth=2;exitX=0.5;exitY=1;exitDx=0;exitDy=0;entryX=0.5;entryY=0;entryDx=0;entryDy=0;" edge="1" parent="1" source="lambda" target="s3">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### 将图表转换为 PNG

```bash
# 使用提供的脚本转换为 PNG
bash scripts/drawio-to-png.sh architecture.drawio
# 结果：architecture.png（2x 分辨率，透明背景）
```

### 查找架构图标

```bash
# 检索 EC2 图标字符串引用
python scripts/find-arch-icon.py ec2
# 输出：mxgraph.aws4.ec2

# 检索并获取包含标准类别颜色的完整 style 字符串
python scripts/find-arch-icon.py ec2 --style
# 输出：shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.ec2;fillColor=#F58536;strokeColor=none;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;

# 检索 Kubernetes Pod 样式
python scripts/find-arch-icon.py pod --style
# 输出：shape=image;image=img/lib/kubernetes/compute/pod.svg;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;

# 检索网络路由器样式
python scripts/find-arch-icon.py router --style
# 输出：shape=mxgraph.cisco.routers.router;fillColor=#ffffff;strokeColor=#036897;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;

# 检索通用数据库样式
python scripts/find-arch-icon.py database --style
# 输出：shape=cylinder3;fillColor=#dae8fc;strokeColor=#6c8ebf;html=1;pointerEvents=1;verticalLabelPosition=bottom;verticalAlign=top;align=center;
```

## 最佳实践

### 间距与布局（最高优先级）

**最重要的质量指标是间距。拿不准时，多加留白。**

- **放置任何元素前先计算画布尺寸**——绝不猜测
- **使用基于网格的定位**——为每个元素定义 `(col, row)`，再根据网格坐标计算 `(x, y)`
- 兄弟元素间**至少 120px 水平间距**（复杂图表建议 200px+）
- 层级间**至少 140px 垂直间距**（建议 200px+）
- 子元素与容器边界之间 **60px** 留白
- **复杂图表需要更大画布**：10+ 元素 → 至少使用 2000×1600 页面尺寸
- 若图表显得“局促”，解决办法永远是增大间距和画布尺寸，而不是缩小元素

### 文本宽度计算

中文/日文文本按每个字符约 **15px**（12px 字号）计算宽度，与上文「布局系统 §0」的字符宽度规则一致，避免文本被裁剪：

```xml
# 10 个中文字符（12px 字号）：10 × 15 = 150px 文本宽，加留白后约 180px
<mxGeometry x="140" y="60" width="180" height="40" />
```

### 应避免的常见错误

| 错误 | 修正 |
|---------|-----|
| 靠“目测”坐标放置元素 | 使用网格计算（col × cellWidth） |
| 画布对内容而言太小 | 先按元素数量计算画布 |
| 连线穿过框 | 添加显式出口/入口点 + 路径点 |
| 标签与其他元素重叠 | 增大行/列间距 |
| 容器边缘紧贴子元素 | 四周加 60px 留白 |
| 一行 5+ 个元素且间距 <100px | 至少用 160px 间距，或拆分子分组 |

## 参考

- 布局算法的详细推导（动态间距公式、网格居中公式、布局模式表、3 层架构完整示例）：见 [references/drawio-designer-guide.md](./references/drawio-designer-guide.md)
