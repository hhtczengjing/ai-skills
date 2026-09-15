import Foundation

/// 内置脚本（App 自带、跟用户脚本同一套 Script 模型，但不写沙箱）。
///
/// **架构：**
/// - **source 从 bundle 读** —— 每个 builtin 对应一个 `Resources/Scripts/<name>.user.js`，
///   App 启动时按 id 列表懒加载一次。修改 bundle 里的文件就能更新 builtin。
/// - **不写沙箱** —— `loadAll()` 把 builtin 跟沙箱里的用户脚本合并返回；WKUserScript
///   用同一份 source 路径构造，注入逻辑和用户脚本完全一致。
/// - **用户不能编辑/删除** —— SettingsViewController 检测到 builtin id 会去掉左滑删除和
///   编辑器的「保存」按钮；ScriptEditorViewController 给 Monaco 设 `readOnly: true`。
///
/// **启用状态**：
/// - builtin 的 enabled 状态存在 UserDefaults（key 格式 `builtin-<id>-enabled`），跟
///   用户脚本的 enabled 字段独立。卸载 App 后会丢 —— 内置脚本是调试工具，不应该
///   持久化进生产状态。
/// - 默认 **enabled=false**，需要用户在列表里点 UISwitch 启用。
///
/// **新增内置脚本的步骤：**
/// 1. 在 `Resources/Scripts/` 加一个 `<name>.user.js`（参考 `vconsole.user.js` 格式）
/// 2. 在下面 `all` 数组里加一条 Script entry（id 用 `builtin-<name>`，sourceLoader 写文件 basename）
enum BuiltinScripts {
    /// 内置脚本总览。`loadAll()` 会把它跟用户脚本合并返回。
    /// id 必须以 `builtin-` 开头，SettingsViewController / ScriptEditorViewController 据此判定。
    static let all: [Script] = [
        Script(
            id: "builtin-vconsole",
            name: "vConsole",
            version: "3.15.1",
            source: loadSource(named: "vconsole"),
            enabled: false,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        ),
    ]

    static var allIds: Set<String> { Set(all.map { $0.id }) }

    static func isBuiltin(_ id: String) -> Bool { allIds.contains(id) }

    /// builtin id 在 UserDefaults 里的开关。跟用户脚本的 `script.enabled` 字段独立。
    static func isEnabled(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: enabledKey(for: id))
    }

    static func setEnabled(_ id: String, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey(for: id))
    }

    private static func enabledKey(for id: String) -> String {
        "builtin-\(id)-enabled"
    }

    /// 从 bundle 读 `Resources/Scripts/<name>.user.js`。文件缺失直接挂掉，
    /// 那是构建错误（project.yml 没把 Resources/Scripts 加成 resource，或文件被误删），
    /// 不该静默 fallback。
    private static func loadSource(named name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "user.js", subdirectory: "Scripts"),
              let content = try? String(contentsOf: url, encoding: .utf8),
              !content.isEmpty else {
            fatalError("builtin script `\(name).user.js` missing from bundle (Resources/Scripts/)")
        }
        return content
    }
}
