import UIKit
import WebKit

/// 基于 Monaco Editor 的源码编辑器。WKWebView 通过 `loadFileURL` +
/// `allowingReadAccessTo: Monaco/` 加载 bundle 内 `Monaco/editor.html`
/// （AMD loader + `monaco.editor.create`），编辑结果通过
/// `webkit.messageHandlers.sourceChanged` 回传到 Swift。
///
/// 对外 API：
/// - `loadSource(_:)`：异步设置源码，Monaco 还没 ready 时缓存到 pendingSource。
/// - `getSource()`：同步返回 `currentSource`（input 事件持续刷新）。
/// - `focus()` / `resignFocus()`：把焦点交给 Monaco 或从编辑器拿开。
///
/// 已知限制：
/// 1. file:// 下不能创建 Web Worker，所以 `MonacoEnvironment.getWorker`
///    返回 resolve 成 noop worker 的 Promise，让 Monaco 走主线程同步跑 JS
///    词法（够用），TS/JSON/HTML 智能提示不可用。**必须**返回 Promise 而不是
///    同步 null，否则 Monaco 的 WorkerManager 直接 `null.then(...)` 会抛
///    "null is not an object"，把初始化链路搞坏，导致编辑器无法输入。
/// 2. 早期实现用 `loadHTMLString + file:// baseURL`，但 WKWebView 在
///    `loadHTMLString` 下会让页面拿到 opaque origin，AMD loader 抛错时
///    只能报 "Script error. :0"（跨域细节被吞），调试很难定位。`loadFileURL`
///    保留真正的 file:// origin，相对路径下 Monaco 资源全部同源加载，
///    错误信息完整可见。（原来注释里写的"loadFileURL 让 Monaco 不可见"
///    实际是 worker 链路炸了之后的误判。）
/// 3. Monaco 首次 layout 在 WKWebView 下计算高度异常，需要多次 reflow 才能
///    填满容器（详见 editor.html）。
final class CodeEditorView: UIView {

    /// Swift 侧缓存的当前源码。每次 JS 端 input 事件都同步刷新。
    private(set) var currentSource: String = ""

    private let webView: NoAccessoryWebView
    private let messageHandler = CodeEditorMessageHandler()

    /// Monaco 是否已经创建好、能响应 `setSource` 调用。
    private var ready = false
    private var pendingSource: String?
    private var pendingReadOnly = false

    override init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(messageHandler, name: "sourceChanged")
        config.userContentController = ucc
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = NoAccessoryWebView(frame: .zero, configuration: config)
        super.init(frame: frame)

        backgroundColor = .systemBackground

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.minimumZoomScale = 1
        webView.scrollView.maximumZoomScale = 1
        webView.scrollView.keyboardDismissMode = .interactive

        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        messageHandler.editor = self
        loadMonaco()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - 公开 API

    /// 加载初始源码。如果 Monaco 还没准备好，会缓存到 `pendingSource`，
    /// ready 后再注入。
    /// - readOnly: true 时 Monaco editor 设 readOnly 模式，用户无法编辑源码
    ///   （用于展示内置脚本）。
    func loadSource(_ source: String, readOnly: Bool = false) {
        currentSource = source
        if ready {
            applySourceToWebView(source, readOnly: readOnly)
        } else {
            pendingSource = source
            pendingReadOnly = readOnly
        }
    }

    /// 同步读取当前源码。`currentSource` 由 Monaco onDidChangeModelContent
    /// 持续更新，保存时可直接用。
    func getSource() -> String { currentSource }

    func focus() {
        webView.evaluateJavaScript("window.__editor && window.__editor.focus();")
    }

    func resignFocus() {
        webView.evaluateJavaScript(
            "window.__editor && window.__editor.getContainerDomNode().blur();"
        )
        webView.resignFirstResponder()
    }

    // MARK: - 内部（供 messageHandler 调用）

    fileprivate func handleSourceChanged(_ source: String) {
        currentSource = source
    }

    fileprivate func markReady() {
        ready = true
        if let pending = pendingSource {
            pendingSource = nil
            applySourceToWebView(pending, readOnly: pendingReadOnly)
            pendingReadOnly = false
        }
        // 不主动 becomeFirstResponder —— 让用户自己 tap 编辑器来进入输入
        // 状态。WKWebView 自己不抢焦点时，iOS Simulator 的「Show Keyboard」
        // 悬浮按钮不会出现；用户一点，WKWebView 自然成为 first responder，
        // 硬件键盘事件顺着派发到 Monaco。
    }

    // MARK: - 私有

    private func loadMonaco() {
        // 用 loadFileURL（而不是 loadHTMLString）加载 Monaco：
        // - loadFileURL 让页面拿到真正的 file:// origin，相对路径下
        //   Monaco/loader.js 和 AMD 模块全部同源加载，错误信息完整可见。
        //   旧实现用 loadHTMLString 时页面拿到的是 opaque origin，AMD 报错
        //   只能拿到 "Script error. :0"，根本没法定位。
        // - allowingReadAccessTo 给到 Monaco/，允许 WKWebView 读取
        //   Monaco/js/vs/... 等相对路径下的 AMD 模块。
        guard let htmlURL = Bundle.main.url(
            forResource: "editor",
            withExtension: "html",
            subdirectory: "Monaco"
        ) else {
            fatalError("Monaco/editor.html not found in app bundle")
        }
        let accessURL = htmlURL.deletingLastPathComponent()
        webView.loadFileURL(htmlURL, allowingReadAccessTo: accessURL)
    }

    private func applySourceToWebView(_ source: String, readOnly: Bool = false) {
        guard let data = try? JSONEncoder().encode(source),
              let json = String(data: data, encoding: .utf8) else { return }
        // 先写源码，再切 readOnly 模式（顺序很重要：setValue 期间 Monaco 内部
        // 可能改 model 状态，先 readOnly 反而会让某些 input handler 被跳过）
        let js = """
        window.__editor && (function() {
          window.__editor.setValue(\(json));
          window.__editor.updateOptions({ readOnly: \(readOnly ? "true" : "false") });
        })();
        """
        webView.evaluateJavaScript(js)
    }
}

/// 单独成类，避免 CodeEditorView 直接 conform WKScriptMessageHandler 时被
/// WKUserContentController 强引用形成循环。CodeEditorView 由视图层级持有，
/// VC dismiss 时整条链释放，无循环。
private final class CodeEditorMessageHandler: NSObject, WKScriptMessageHandler {
    weak var editor: CodeEditorView?

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }
        if body == "__READY__" {
            editor?.markReady()
        } else {
            editor?.handleSourceChanged(body)
        }
    }
}

/// 把 inputAccessoryView 返回成空 UIView，屏蔽 WKWebView 聚焦时 iOS 在键盘
/// 顶部弹出的系统附件栏（地球键 / 听写键 / 键盘切换键等）。
/// 注意：iOS Simulator 在「连接硬件键盘」模式下还会在屏幕右下角显示一个
/// 模拟器自身的「切换软键盘」悬浮按钮，那是模拟器的系统层 UI，App 无法
/// 拦截 —— 关闭路径：Simulator 菜单 I/O > Keyboard > Connect Hardware Keyboard。
private final class NoAccessoryWebView: WKWebView {
    override var inputAccessoryView: UIView? {
        get { UIView() }
        set { /* ignore */ }
    }
}
