import Foundation

/// 油猴风格的脚本元数据，从源码头部 `// ==UserScript== ... // ==/UserScript==`
/// 块解析得到。持久化（`Script`）只消费 `name` 和 `version`；其余字段
/// 是为以后扩展（运行时匹配、注入时机等）预留的解析结果。
struct ScriptMetadata: Equatable {
    var name: String?
    var version: String?
    var description: String?
    var author: String?
    var namespace: String?
    var `match`: [String] = []
    var grant: [String] = []
    /// 未识别的 `@key` 原样保留，方便以后扩展不丢字段。
    var raw: [String: String] = [:]

    static let empty = ScriptMetadata()
}

/// `// ==UserScript== ... // ==/UserScript==` 头部解析器。纯静态、无状态、线程安全。
///
/// 规则：
/// - 只看源码前 60 行，性能与对超大脚本友好。
/// - 只识别 `// @key value` 这种行（`//` 与 `@` 之间可有空格）。
/// - 没找到 `==UserScript==` 块 → 返回 `.empty`。
/// - 块内没 `@name` → `.name == nil`，调用方按需 fallback。
enum ScriptMetadataParser {
    /// 解析 `source` 头部的元数据块。
    static func parse(from source: String) -> ScriptMetadata {
        var meta = ScriptMetadata.empty
        let lines = source.components(separatedBy: .newlines).prefix(60)

        var inBlock = false
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("//") else {
                // 在块外遇到非注释行直接放弃扫描
                if !inBlock { continue } else { break }
            }
            let body = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)

            if body == "==UserScript==" { inBlock = true; continue }
            if body == "==/UserScript==" { break }
            guard inBlock, body.hasPrefix("@") else { continue }

            // 切分 @key 与 value（value 可空）
            let parts = body.split(separator: " ", maxSplits: 1,
                                   omittingEmptySubsequences: true)
            guard let keyToken = parts.first else { continue }
            let key = String(keyToken).lowercased()
            let value = parts.count > 1
                ? String(parts[1]).trimmingCharacters(in: .whitespaces)
                : ""

            meta.raw[key] = value
            switch key {
            case "@name":         meta.name = nonEmpty(value)
            case "@version":      meta.version = nonEmpty(value)
            case "@description":  meta.description = nonEmpty(value)
            case "@author":       meta.author = nonEmpty(value)
            case "@namespace":    meta.namespace = nonEmpty(value)
            case "@match":        if let v = nonEmpty(value) { meta.match.append(v) }
            case "@grant":        if let v = nonEmpty(value) { meta.grant.append(v) }
            default: break
            }
        }
        return meta
    }

    private static func nonEmpty(_ s: String) -> String? {
        s.isEmpty ? nil : s
    }
}
