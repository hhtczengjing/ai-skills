import Foundation
import WebKit

/// `$app` 命名空间的中央注册表。负责：
/// 1. **shim 注入**：把所有 `plugins[].jsAPI()` 拼成一个完整 IIFE，注入到
///    `WKUserContentController` 的 `.atDocumentStart` 脚本里。
/// 2. **dispatch**：收到 `{module, action, payload}` 消息时路由到对应插件的
///    `handle(action:payload:webView:reply:)`。
/// 3. **reply**：统一把 `(ok, value, error)` 序列化成 JSON，调
///    `window.__appNativeReply(id, ...)`。
///
/// **新增插件的步骤**：
/// 1. 写一个 `struct XxxPlugin: AppNativePlugin`，填好 `name` / `jsAPI()` /
///    `handle(action:payload:webView:reply:)`。
/// 2. 在 `AppNativeRegistry.plugins` 数组里加一行 `XxxPlugin()`。
/// 3. `WebViewController` 不需要改 —— shim 自动重拼，handler 自动 dispatch。
@MainActor
enum AppNativeRegistry {

    /// 所有已注册插件。**新增插件在这里追加一行**。Plugins are evaluated lazily;
    /// adding/removing here changes the shim on next page load.
    static let plugins: [AppNativePlugin] = [
        CookieBridgePlugin()
    ]

    /// 拼装完整 shim：core（Promise 包装 + $app 命名空间声明）+ 每个插件的 jsAPI。
    /// 注入时机 `.atDocumentStart`，**早于**用户脚本（`.atDocumentEnd`）。
    static let shimSource: String = """
    (function() {
      if (window.__appNativeInstalled) return;
      window.__appNativeInstalled = true;

      var pending = new Map();
      var nextId = 1;
      var TIMEOUT_MS = 30000;

      window.__appNativeReply = function(id, result) {
        var p = pending.get(id);
        if (!p) return;
        pending.delete(id);
        clearTimeout(p.timer);
        if (result && result.ok) p.resolve(result.value);
        else p.reject(new Error((result && result.error) || 'unknown'));
      };

      var native = window.webkit.messageHandlers.appNative;
      var nativePost = native.postMessage.bind(native);

      native.postMessage = function(envelope) {
        return new Promise(function(resolve, reject) {
          var id = nextId++;
          var timer = setTimeout(function() {
            pending.delete(id);
            reject(new Error('timeout'));
          }, TIMEOUT_MS);
          pending.set(id, { resolve: resolve, reject: reject, timer: timer });
          nativePost({
            id: id,
            module: envelope.module,
            action: envelope.action,
            payload: envelope.payload || {}
          });
        });
      };

      function call(module, action, payload) {
        return native.postMessage({ module: module, action: action, payload: payload || {} });
      }

      window.$app = window.$app || {};
    \(pluginShimBody)
    })();
    """

    /// 把每个插件的 `jsAPI()` 拼成 `window.$app.<name> = { ... };`。每个插件
    /// 用一行单独写，避免互相干扰（替换/调试时定位更清楚）。
    private static let pluginShimBody: String = plugins.map { plugin in
        "\n      window.$app.\(plugin.name) = \(plugin.jsAPI());"
    }.joined()

    // MARK: - Dispatch

    /// 收到 native 消息的统一入口。在 `WebViewController.handleAppNativeMessage`
    /// 里调用，plugins 是静态数组所以 lookup 是 O(n)（n 通常 < 10，无所谓）。
    static func dispatch(id: Int,
                         module: String,
                         action: String,
                         payload: [String: Any],
                         webView: WKWebView,
                         reply: @escaping (AppNativeReply) -> Void) {
        guard let plugin = plugins.first(where: { $0.name == module }) else {
            reply(AppNativeReply(ok: false, error: "unknown_module"))
            return
        }
        plugin.handle(action: action, payload: payload, webView: webView, reply: reply)
    }

    /// 把 AppNativeReply 序列化成 JSON，调 `window.__appNativeReply(id, ...)`。
    /// webView 为 nil 时直接放弃（页面已经销毁）。
    static func sendReply(to webView: WKWebView?, id: Int, reply: AppNativeReply) {
        guard let webView = webView else { return }
        var dict: [String: Any] = ["ok": reply.ok]
        if let value = reply.value { dict["value"] = value }
        if let error = reply.error { dict["error"] = error }
        let data = (try? JSONSerialization.data(withJSONObject: dict, options: [])) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{\"ok\":false,\"error\":\"native_error\"}"
        let js = "window.__appNativeReply(\(id), \(json));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

/// 单例 message handler。`owner` 弱引用 WebViewController —— 跟
/// `CodeEditorMessageHandler` 同构，避免 WKUserContentController →
/// handler → owner 的强引用环。
final class AppNativeMessageHandler: NSObject, WKScriptMessageHandler {
    weak var owner: WebViewController?

    func userContentController(_ ucc: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "appNative",
              let body = message.body as? [String: Any],
              let module = body["module"] as? String,
              let action = body["action"] as? String,
              let id = body["id"] as? Int else {
            owner?.handleAppNativeError(id: nil)
            return
        }
        let payload = body["payload"] as? [String: Any] ?? [:]
        owner?.handleAppNativeMessage(id: id, module: module,
                                       action: action, payload: payload)
    }
}