import Foundation

/// 用户脚本的持久化层。所有方法都在调用方所在线程（实际就是 UI 主线程）执行，
/// 不引入串行队列。文件写采用「先写 .tmp 再 rename」的原子写策略。
///
/// 布局：
/// ```
/// Documents/scripts/
///   index.json     // [Script] 的 JSON 数组
///   <id>.js        // 脚本源码（与 index.json 中的 source 字段冗余，便于人读 / 外部修改）
/// ```
enum ScriptStore {
    /// 目录懒创建，返回 Documents/scripts 的绝对 URL。
    static var scriptsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("scripts", isDirectory: true)
    }

    private static var indexURL: URL { scriptsDirectory.appendingPathComponent("index.json") }
    private static func scriptFileURL(id: String) -> URL {
        scriptsDirectory.appendingPathComponent("\(id).js")
    }

    /// 确保目录存在。失败时打印但不抛出 —— UI 层仍可继续运行（只是没有持久化）。
    private static func ensureDirectory() {
        let dir = scriptsDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                print("[ScriptStore] failed to create scripts directory: \(error)")
            }
        }
    }

    // MARK: - CRUD

    /// 读所有脚本。沙箱里的用户脚本 + 内置脚本（BuiltinScripts）合并返回。
    /// index.json 不存在 → 只返回内置脚本。JSON 损坏 → print + 只返回内置。
    /// index 有但对应 .js 文件缺失的条目会被跳过。
    static func loadAll() -> [Script] {
        let userScripts = loadUserScripts()
        return userScripts + BuiltinScripts.all
    }

    /// 只读沙箱里的用户脚本（不含 builtin）。私有，外部通过 loadAll() 走。
    private static func loadUserScripts() -> [Script] {
        ensureDirectory()
        let url = indexURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            print("[ScriptStore] failed to read index.json: \(error)")
            return []
        }

        if data.isEmpty { return [] }

        // 自定义 Date 解码：兼容 epoch Double 和 ISO 8601 字符串。
        // 默认 `.deferredToDate` 只认 Double —— 有人写 ISO 字符串会让整个
        // index.json decode 失败，`loadUserScripts()` catch 后静默返回 []，
        // 用户脚本全部失踪（连「自定义脚本」section 都不显示）。自己吃两种格式，
        // 出错信息也更明确。
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            if let s = try? c.decode(String.self), let d = ISO8601DateFormatter().date(from: s) {
                return d
            }
            let n = try c.decode(Double.self)
            return Date(timeIntervalSince1970: n)
        }

        let all: [Script]
        do {
            all = try decoder.decode([Script].self, from: data)
        } catch {
            print("[ScriptStore] index.json corrupted, treating as empty: \(error)")
            return []
        }

        return all.filter { script in
            FileManager.default.fileExists(atPath: scriptFileURL(id: script.id).path)
        }
    }

    /// 写一个脚本（新增或更新）。先写 .js 再更新 index.json（顺序：源码优先于元数据）。
    /// 内置 builtin id 直接拒绝：source 在 bundle 里，不应该被覆写。
    /// 中途失败不会让 index 指向不存在的 .js。
    @discardableResult
    static func save(_ script: Script) -> Script {
        if BuiltinScripts.isBuiltin(script.id) {
            // 内置脚本不允许「保存」覆写。UI 层会拦截编辑器不让进，但双保险。
            return script
        }
        ensureDirectory()

        // 1) 写源码到 <id>.js（原子写：先 .tmp 再 rename）
        let fileURL = scriptFileURL(id: script.id)
        let tmpURL = fileURL.appendingPathExtension("tmp")
        do {
            try script.source.data(using: .utf8)?.write(to: tmpURL, options: .atomic)
            // .atomic 已经做了 rename 语义；如果目标已存在会被覆盖
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: fileURL)
        } catch {
            print("[ScriptStore] failed to write \(fileURL.lastPathComponent): \(error)")
            try? FileManager.default.removeItem(at: tmpURL)
        }

        // 2) 更新 index.json（只写用户脚本，builtin 不进沙箱）
        var all = loadUserScripts()
        if let idx = all.firstIndex(where: { $0.id == script.id }) {
            all[idx] = script
        } else {
            all.append(script)
        }
        writeIndex(all)
        return script
    }

    /// 删除指定 id 的脚本：删 .js + 从 index.json 移除。
    /// 内置 builtin id 返回 false 让 UI 静默忽略（双保险，UI 层已拦截）。
    @discardableResult
    static func delete(id: String) -> Bool {
        if BuiltinScripts.isBuiltin(id) { return false }
        ensureDirectory()
        let fileURL = scriptFileURL(id: id)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        var all = loadUserScripts()
        all.removeAll { $0.id == id }
        writeIndex(all)
        return true
    }

    /// 翻转 enabled 字段并保存。返回更新后的对象，未找到返回 nil。
    /// builtin id：不写沙箱，只更新 UserDefaults。
    @discardableResult
    static func toggleEnabled(id: String) -> Script? {
        if BuiltinScripts.isBuiltin(id) {
            BuiltinScripts.setEnabled(id, !BuiltinScripts.isEnabled(id))
            return BuiltinScripts.all.first { $0.id == id }
                .map { var s = $0; s.enabled = BuiltinScripts.isEnabled(id); return s }
        }
        var all = loadUserScripts()
        guard let idx = all.firstIndex(where: { $0.id == id }) else { return nil }
        all[idx].enabled.toggle()
        all[idx].updatedAt = Date()
        writeIndex(all)
        return all[idx]
    }

    // MARK: - 私有

    private static func writeIndex(_ scripts: [Script]) {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("[ScriptStore] failed to write index.json: \(error)")
        }
    }
}