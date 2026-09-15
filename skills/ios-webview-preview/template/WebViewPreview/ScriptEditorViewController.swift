import UIKit

/// 脚本新增 / 编辑器。
///
/// 布局：
/// - 整个可视区填满 `CodeEditorView`（Monaco 编辑器），底边贴在
///   `view.keyboardLayoutGuide.topAnchor`：键盘唤起时编辑器自动收缩腾位，
///   键盘隐藏时填到 safeArea 底部
/// - 右上「保存」barButtonItem；导航栏 title 由源码 `@name` 自动维护
///
/// name 不再是独立输入框；保存前用 `ScriptMetadataParser` 从源码头部
/// `// ==UserScript==` 块提取 `name` 和 `version`，覆盖到 `script`。
final class ScriptEditorViewController: UIViewController {

    enum Mode {
        case create
        case edit
    }

    /// 保存后回调（参数 = 已保存的 Script）。SettingsViewController 用它刷新列表。
    var onSave: ((Script) -> Void)?

    private var script: Script
    private let mode: Mode

    private let codeView = CodeEditorView()

    init(script: Script, mode: Mode) {
        self.script = script
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        switch mode {
        case .create:
            title = "新建脚本"
        case .edit:
            title = script.name.isEmpty ? "编辑脚本" : script.name
        }

        navigationItem.largeTitleDisplayMode = .never

        // 内置脚本：右上换成「关闭」，且 Monaco 设 readOnly 不让改源码
        if BuiltinScripts.isBuiltin(script.id) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "关闭",
                style: .done,
                target: self,
                action: #selector(closeTapped)
            )
            title = "\(script.name)（只读）"
            codeView.loadSource(script.source, readOnly: true)
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "保存",
                style: .done,
                target: self,
                action: #selector(save)
            )
            codeView.loadSource(script.source)
        }

        setupLayout()
        refreshMetadataUI()
    }

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 从其他页面返回时保持 metadata UI 最新。
        refreshMetadataUI()
    }

    // MARK: - 视图配置

    private func setupLayout() {
        codeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(codeView)

        NSLayoutConstraint.activate([
            codeView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            codeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            codeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // 键盘唤起时键盘布局引导把底边顶上去，编辑器自动收缩
            codeView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
        ])
    }

    // MARK: - Metadata UI

    /// 从当前源码解析 metadata，覆盖 `script.name` 并刷新导航栏 title。
    /// 空值时保留旧值（用户删了 `@name` 不会让名字变没）。
    private func refreshMetadataUI() {
        let meta = ScriptMetadataParser.parse(from: codeView.getSource())
        if let name = meta.name {
            script.name = name
            navigationItem.title = name
        }
        if let version = meta.version {
            script.version = version
        }
    }

    // MARK: - Actions

    @objc private func save() {
        let source = codeView.getSource()
        let meta = ScriptMetadataParser.parse(from: source)
        script.source = source
        if let name = meta.name, !name.isEmpty {
            script.name = name
        }
        script.version = meta.version ?? script.version
        script.updatedAt = Date()
        ScriptStore.save(script)
        onSave?(script)
        navigationController?.popViewController(animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
