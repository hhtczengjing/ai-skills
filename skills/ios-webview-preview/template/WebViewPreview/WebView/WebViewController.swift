import UIKit
import WebKit

class WebViewController: UIViewController {
    private var webView: WKWebView!
    private var userContentController: WKUserContentController!
    private let appNativeHandler = AppNativeMessageHandler()
    private var targetURL: URL
    private var backButton: UIBarButtonItem!
    private var canGoBackObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var navBarLongPressGesture: UILongPressGestureRecognizer?
    private var floatingSettingsButton: UIButton?
    private var floatingSettingsTopConstraint: NSLayoutConstraint?
    private var floatingSettingsTrailingConstraint: NSLayoutConstraint?
    private var webViewSafeAreaTopConstraint: NSLayoutConstraint?
    private var webViewScreenTopConstraint: NSLayoutConstraint?

    /// URL 带 `dd_full_screen=true`（query 或 hash 路由均可）时进入全屏模式：
    /// 隐藏导航栏，改为右上角悬浮设置按钮。
    private var isFullScreen: Bool {
        Self.hasFullScreenParam(targetURL)
    }

    init(url: URL) {
        self.targetURL = url
        super.init(nibName: nil, bundle: nil)
    }

    private static func hasFullScreenParam(_ url: URL) -> Bool {
        func match(_ query: String?) -> Bool {
            guard let query = query,
                  let items = URLComponents(string: "?\(query)")?.queryItems else { return false }
            return items.contains { $0.name == "dd_full_screen" && $0.value == "true" }
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        // 1) 普通 query：?dd_full_screen=true
        if match(components?.query) { return true }
        // 2) SPA hash 路由：#/page?dd_full_screen=true
        if let fragment = components?.fragment,
           let qIndex = fragment.firstIndex(of: "?") {
            return match(String(fragment[fragment.index(after: qIndex)...]))
        }
        return false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupNavigationBar()
        if isFullScreen {
            setupFloatingSettingsButton()
        }
        loadURL()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isFullScreen {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 推出设置页前恢复导航栏，返回本页时 viewWillAppear 会再次隐藏
        if isFullScreen {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    /// 现场改 URL 后调用：根据新 URL 是否带 dd_full_screen=true 切换全屏/普通模式。
    private func applyScreenMode() {
        if isFullScreen {
            navigationController?.setNavigationBarHidden(true, animated: true)
            if floatingSettingsButton == nil {
                setupFloatingSettingsButton()
            }
        } else {
            navigationController?.setNavigationBarHidden(false, animated: true)
            floatingSettingsButton?.removeFromSuperview()
            floatingSettingsButton = nil
            floatingSettingsTopConstraint = nil
            floatingSettingsTrailingConstraint = nil
        }
        updateWebViewTopInset()
    }

    /// 全屏模式：webView 顶到屏幕边缘，且关掉 UIScrollView 的自动安全区
    /// 内边距，把刘海/状态栏区域完全交给前端（env(safe-area-inset-*) 会
    /// 返回真实值）。普通模式：顶到 safeArea，保持系统自动内边距。
    private func updateWebViewTopInset() {
        webViewSafeAreaTopConstraint?.isActive = !isFullScreen
        webViewScreenTopConstraint?.isActive = isFullScreen
        webView.scrollView.contentInsetAdjustmentBehavior = isFullScreen ? .never : .automatic
    }

    deinit {
        canGoBackObservation?.invalidate()
        titleObservation?.invalidate()
        if let gesture = navBarLongPressGesture {
            navigationController?.navigationBar.removeGestureRecognizer(gesture)
        }
        webView?.navigationDelegate = nil
        webView?.uiDelegate = nil
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        userContentController = WKUserContentController()
        appNativeHandler.owner = self
        userContentController.add(appNativeHandler, name: "appNative")
        applyUserScripts(to: userContentController)
        config.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Enable debugging inspection in DEBUG builds (iOS 16.4+)
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        view.addSubview(webView)

        // 顶部约束两套：普通模式顶到 safeArea（避开导航栏），全屏模式顶到屏幕
        // 边缘（含刘海/状态栏区域），安全距离由前端 viewport-fit=cover +
        // env(safe-area-inset-*) 自行处理。applyScreenMode() 负责切换。
        webViewSafeAreaTopConstraint = webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        webViewScreenTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        updateWebViewTopInset()

        // Use NSKeyValueObservation instead of raw KVO to avoid the nil-context
        // super-forward crash when the web view fires keyPaths we don't handle.
        canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
            self?.updateBackButtonState()
        }
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] _, _ in
            self?.updateTitle()
        }

        webView.allowsBackForwardNavigationGestures = true
    }

    private func setupNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        let backImage = UIImage(named: "Back")?.withRenderingMode(.alwaysOriginal)
        backButton = UIBarButtonItem(
            image: backImage,
            style: .plain,
            target: self,
            action: #selector(goBack)
        )
        navigationItem.leftBarButtonItem = nil

        let refreshImage = UIImage(named: "Refresh")?.withRenderingMode(.alwaysOriginal)
        let refreshButton = UIBarButtonItem(
            image: refreshImage,
            style: .plain,
            target: self,
            action: #selector(refreshPage)
        )

        // Settings (gear) sits to the right of Refresh. SF Symbol keeps the
        // asset catalog clean — no new PNG needed.
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gearshape"),
            style: .plain,
            target: self,
            action: #selector(openSettings)
        )

        // rightBarButtonItems is laid out right-to-left: first entry is the rightmost.
        navigationItem.rightBarButtonItems = [settingsButton, refreshButton]

        // Long-press the navigation bar to edit the preview URL.
        // Held in an ivar so deinit can break the gesture's strong reference to self.
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleNavBarLongPress(_:)))
        gesture.minimumPressDuration = 0.5
        navigationController?.navigationBar.addGestureRecognizer(gesture)
        navBarLongPressGesture = gesture

        updateBackButtonState()
    }

    /// 全屏模式下的设置入口：右上角半透明圆形悬浮按钮，可拖拽以避开网页内容。
    private func setupFloatingSettingsButton() {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "gearshape"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        button.addGestureRecognizer(UIPanGestureRecognizer(
            target: self,
            action: #selector(handleFloatingSettingsPan(_:))
        ))
        view.addSubview(button)

        let topConstraint = button.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor,
            constant: 12
        )
        let trailingConstraint = button.trailingAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.trailingAnchor,
            constant: -12
        )
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            trailingConstraint,
            topConstraint
        ])
        floatingSettingsButton = button
        floatingSettingsTopConstraint = topConstraint
        floatingSettingsTrailingConstraint = trailingConstraint
    }

    /// 增量更新约束，并在安全区内保留 12pt 边距，防止按钮被拖出屏幕。
    @objc private func handleFloatingSettingsPan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed,
              let button = floatingSettingsButton,
              let topConstraint = floatingSettingsTopConstraint,
              let trailingConstraint = floatingSettingsTrailingConstraint else { return }

        let translation = gesture.translation(in: view)
        let margin: CGFloat = 12
        let safeArea = view.safeAreaLayoutGuide.layoutFrame
        let maxTop = max(margin, safeArea.height - button.bounds.height - margin)
        let minTrailing = min(-margin, margin + button.bounds.width - safeArea.width)

        topConstraint.constant = min(
            max(topConstraint.constant + translation.y, margin),
            maxTop
        )
        trailingConstraint.constant = min(
            max(trailingConstraint.constant - translation.x, minTrailing),
            -margin
        )
        gesture.setTranslation(.zero, in: view)
    }

    private func loadURL() {
        let request = URLRequest(url: targetURL)
        webView.load(request)
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc private func refreshPage() {
        webView.reloadFromOrigin()
    }

    @objc private func openSettings() {
        let vc = SettingsViewController()
        vc.onChange = { [weak self] in
            self?.scriptsDidChange()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    /// Settings 回调用：脚本列表有变更，重新注入并 reload 当前页。
    /// reload 会清掉 history stack —— 对调试油猴脚本是期望行为。
    private func scriptsDidChange() {
        injectScripts()
        webView.reload()
    }

    /// 清空 + 按当前 ScriptStore 里的 enabled 列表重新塞回 userContentController。
    /// 必须在主线程调用（WKUserContentController 的 API 约束；我们天然在主线程）。
    private func injectScripts() {
        guard let ucc = userContentController else { return }
        ucc.removeAllUserScripts()
        applyUserScripts(to: ucc)
    }

    private func applyUserScripts(to ucc: WKUserContentController) {
        // 1) $app native 扩展 shim（AppNativeRegistry 自动拼装所有已注册插件）：
        //    必须在所有用户脚本之前注入 (.atDocumentStart 早于 .atDocumentEnd，
        //    且 WKUserScript 按数组顺序执行)。
        ucc.addUserScript(WKUserScript(
            source: AppNativeRegistry.shimSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        // 2) 用户/内置脚本（原逻辑不变）
        for script in ScriptStore.loadAll() {
            // 用户脚本：enabled 字段就是真实状态
            // 内置脚本：状态在 UserDefaults 里（builtin-<id>-enabled）
            let enabled = BuiltinScripts.isBuiltin(script.id)
                ? BuiltinScripts.isEnabled(script.id)
                : script.enabled
            guard enabled else { continue }
            ucc.addUserScript(WKUserScript(
                source: ScriptInjector.wrappedSource(script.source),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            ))
        }
    }

    // MARK: - $app native 扩展 dispatch（纯 plumbing，转发给 AppNativeRegistry）

    /// AppNativeMessageHandler 入口。`internal`（非 `fileprivate`）以便另一个文件的
    /// `AppNativeMessageHandler` 调用。在主线程上调用（WKScriptMessageHandler 文档约束）。
    func handleAppNativeMessage(id: Int,
                                module: String,
                                action: String,
                                payload: [String: Any]) {
        guard let webView = self.webView else {
            AppNativeRegistry.sendReply(to: nil, id: id,
                                        reply: AppNativeReply(ok: false, error: "no_webview"))
            return
        }
        AppNativeRegistry.dispatch(
            id: id, module: module, action: action, payload: payload,
            webView: webView,
            reply: { [weak self] appReply in
                AppNativeRegistry.sendReply(to: self?.webView, id: id, reply: appReply)
            }
        )
    }

    /// 消息 body 解析失败时的兜底入口。`internal` 以便 AppNativeMessageHandler 调用。
    func handleAppNativeError(id: Int?) {
        guard let id = id else { return }
        AppNativeRegistry.sendReply(to: webView, id: id,
                                    reply: AppNativeReply(ok: false, error: "invalid_args"))
    }

    @objc private func handleNavBarLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        promptForNewURL()
    }

    private func promptForNewURL() {
        let alert = UIAlertController(
            title: "修改预览 URL",
            message: "当前：\(AppConfig.targetURL)",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.text = AppConfig.targetURL
            tf.placeholder = "http://localhost:3000"
            tf.keyboardType = .URL
            tf.clearButtonMode = .whileEditing
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self] _ in
            guard let self = self,
                  let text = alert.textFields?.first?.text,
                  let url = URL(string: text),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else {
                self?.showAlert(title: "URL 无效", message: "URL 必须以 http:// 或 https:// 开头")
                return
            }
            self.targetURL = url
            AppConfig.targetURL = text
            self.applyScreenMode()
            self.loadURL()
        })
        present(alert, animated: true)
    }

    private func updateBackButtonState() {
        navigationItem.leftBarButtonItem = webView.canGoBack ? backButton : nil
    }

    private func updateTitle() {
        if let title = webView.title, !title.isEmpty {
            navigationItem.title = title
        } else {
            navigationItem.title = nil
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateTitle()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showAlert(title: "加载失败", message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showAlert(title: "加载失败", message: error.localizedDescription)
    }

    // Hand off non-web schemes (mailto:, tel:, itms-apps:, sms:, etc.) to the system
    // instead of letting the web view swallow them silently.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           let scheme = url.scheme?.lowercased() {
            let webSchemes: Set<String> = ["http", "https", "about", "data"]
            if !webSchemes.contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate
extension WebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
