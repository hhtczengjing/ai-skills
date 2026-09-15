import Foundation

/// 用户脚本的元数据 + 源码。持久化到 `Documents/scripts/index.json`，
/// 源码同时落到 `<id>.js` 便于人读和外部修改。
///
/// `name` 和 `version` 是**派生字段**：每次通过编辑器保存时，
/// `ScriptEditorViewController` 用 `ScriptMetadataParser` 从 `source`
/// 头部解析出来再覆盖。老 `index.json` 没有 `version` 字段时 JSONDecoder
/// 自动 nil，向后兼容。
struct Script: Codable, Equatable, Identifiable {
    /// 稳定的字符串 UUID，用作文件名 & JSON 字段。
    let id: String
    /// 显示名。优先来自源码 `// @name`，缺失时保留旧值。
    var name: String
    /// 来自源码 `// @version`，可空。
    var version: String?
    /// 完整 JS / CSS 源码。
    var source: String
    /// 是否注入到所有加载的页面。
    var enabled: Bool
    var createdAt: Date
    var updatedAt: Date

    /// 创建一个油猴风格空白草稿，供「新增」入口使用。
    static func newDraft() -> Script {
        let now = Date()
        return Script(
            id: UUID().uuidString,
            name: "New Script",
            version: "0.1.0",
            source: defaultTemplate,
            enabled: true,
            createdAt: now,
            updatedAt: now
        )
    }

    /// 油猴官方推荐的最小可用头部 + IIFE 占位实现。
    /// 用户基于此修改 `// @name` / `// @version` 等字段，保存即可。
    static let defaultTemplate: String = """
    // ==UserScript==
    // @name         New Script
    // @namespace    https://example.com
    // @version      0.1.0
    // @description  try to take over the world!
    // @author       You
    // @match        http://localhost:3000/*
    // @grant        none
    // ==/UserScript==

    (function() {
      'use strict';
      // your code here
    })();
    """
}
