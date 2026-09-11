import UIKit
import WebKit

class WebViewController: UIViewController {
    private var webView: WKWebView!
    private var targetURL: URL
    private var backButton: UIBarButtonItem!
    private var canGoBackObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    private var navBarLongPressGesture: UILongPressGestureRecognizer?

    init(url: URL) {
        self.targetURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupNavigationBar()
        loadURL()
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

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

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
        navigationItem.rightBarButtonItem = refreshButton

        // Long-press the navigation bar to edit the preview URL.
        // Held in an ivar so deinit can break the gesture's strong reference to self.
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleNavBarLongPress(_:)))
        gesture.minimumPressDuration = 0.5
        navigationController?.navigationBar.addGestureRecognizer(gesture)
        navBarLongPressGesture = gesture

        updateBackButtonState()
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
