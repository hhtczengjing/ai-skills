import UIKit

/// 用户脚本管理列表。两段：
///
/// - **Section 0 内置脚本** —— App 自带（目前就 vConsole），source 从 bundle
///   的 `Resources/Scripts/<name>.user.js` 读。按 `BuiltinScripts.isBuiltin` 标记分组。
/// - **Section 1 自定义脚本** —— 用户在「+」里手动加的脚本。
///
/// 所有脚本在沙箱里都是普通 Script，行为完全一致；区分只是 UI 上的分组。
/// 任何变更通过 `onChange` 回调通知 WebViewController 重新注入 + reload。
final class SettingsViewController: UITableViewController {

    /// 脚本有变更（新增 / 删除 / 启用切换 / 编辑保存）时触发。
    /// WebViewController 用它来 `injectScripts()` + `webView.reload()`。
    var onChange: (() -> Void)?

    private enum Section: Int, CaseIterable {
        case seeded = 0
        case userScripts
        var header: String {
            switch self {
            case .seeded: return "内置脚本"
            case .userScripts: return "自定义脚本"
            }
        }
    }

    /// 内置段（App seed 进去的）。可能为空（用户手动删掉了 seed 的脚本）。
    private var seededScripts: [Script] = []
    /// 用户自己加的脚本。
    private var userScripts: [Script] = []

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "用户脚本"
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addScript)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.allowsSelection = true

        reloadFromStore()
    }

    private func reloadFromStore() {
        let all = ScriptStore.loadAll()
        seededScripts = all.filter { BuiltinScripts.isBuiltin($0.id) }
        userScripts = all.filter { !BuiltinScripts.isBuiltin($0.id) }
        // 空段就不渲染（避免显示空标题）
        tableView.reloadData()
    }

    private func script(at indexPath: IndexPath) -> Script {
        if indexPath.section == Section.seeded.rawValue {
            return seededScripts[indexPath.row]
        }
        return userScripts[indexPath.row]
    }

    // MARK: - Actions

    @objc private func addScript() {
        let draft = Script.newDraft()
        let editor = ScriptEditorViewController(script: draft, mode: .create)
        editor.onSave = { [weak self] _ in
            self?.reloadFromStore()
            self?.onChange?()
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .seeded: return seededScripts.count
        case .userScripts: return userScripts.count
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // 空段不显示标题
        if self.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return nil
        }
        return Section(rawValue: section)?.header
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let script = script(at: indexPath)

        var config = cell.defaultContentConfiguration()
        config.text = script.name
        // 副标题：`name vX.Y.Z` 让用户一眼看到 name + version（自动从源码 metadata 派生）。
        // 老脚本（version 为 nil）只显示 name。
        let v = (script.version?.isEmpty == false) ? "v\(script.version!)" : ""
        let subtitle = v.isEmpty ? script.name : "\(script.name) \(v)"
        config.secondaryText = subtitle
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config

        // 右侧 UISwitch：tag 用「section*1000 + row」编码，唯一标识每一行
        let toggle = UISwitch()
        // 内置脚本的开关读 UserDefaults；用户脚本读 Script.enabled
        toggle.isOn = BuiltinScripts.isBuiltin(script.id)
            ? BuiltinScripts.isEnabled(script.id)
            : script.enabled
        toggle.tag = indexPath.section * 1000 + indexPath.row
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        let script: Script
        if sender.tag >= 1000 {
            let row = sender.tag - 1000
            script = userScripts[row]
        } else {
            script = seededScripts[sender.tag]
        }
        ScriptStore.toggleEnabled(id: script.id)
        onChange?()
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let script = script(at: indexPath)
        let editor = ScriptEditorViewController(script: script, mode: .edit)
        editor.onSave = { [weak self] _ in
            self?.reloadFromStore()
            self?.onChange?()
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let script = script(at: indexPath)
        // 内置脚本不允许左滑删除 —— source 在 bundle 里，删了下次启动又冒出来
        if BuiltinScripts.isBuiltin(script.id) { return nil }
        let delete = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, completion in
            ScriptStore.delete(id: script.id)
            self?.reloadFromStore()
            self?.onChange?()
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
