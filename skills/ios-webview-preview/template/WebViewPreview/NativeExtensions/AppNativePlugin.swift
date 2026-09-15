import Foundation
import WebKit

/// 插件回送结果的结构化包装。封装 `(ok, value, error)` 三元组，避免 closure
/// 位置参数默认值的歧义。构造方式：
///
/// ```
/// reply(AppNativeReply(ok: true, value: cookieDict))
/// reply(AppNativeReply(ok: false, error: "invalid_args"))
/// ```
struct AppNativeReply {
    let ok: Bool
    var value: Any?
    var error: String?

    init(ok: Bool, value: Any? = nil, error: String? = nil) {
        self.ok = ok
        self.value = value
        self.error = error
    }
}

/// Native 扩展插件协议。所有挂在 `window.$app.<name>` 上的子模块都要 conform
/// 这个协议，并在 `AppNativeRegistry.plugins` 数组里登记一行。
///
/// Registry 启动时会自动：
/// 1. 把 `jsAPI()` 拼成 `window.$app.<name> = { ... };`，注入到
///    `WKUserContentController` 的 `.atDocumentStart` 脚本里。
/// 2. 在 native 侧收到 `{module, action, payload}` 消息时 dispatch 到对应插件
///    的 `handle(action:payload:webView:reply:)`。
///
/// **线程**：协议标 `@MainActor`，所有方法都在主线程上调用（`WKScriptMessageHandler`
/// 文档约束 + `WebViewController` 的 `@MainActor` 隔离）。插件里直接同步访问
/// UI / `WKHTTPCookieStore` 等 `@MainActor` API 即可，不需要
/// `DispatchQueue.main.async` 嵌套。
@MainActor
protocol AppNativePlugin {
    /// 子模块名。同时作为 JS 端的 `$app.<name>` 命名空间和消息 envelope 的 `module` 字段。
    /// 全局唯一，建议单段小写英文（cookie / device / storage）。
    var name: String { get }

    /// 返回 JS 端要挂到 `window.$app.<name>` 上的对象字面量（**只含属性赋值表达式**，
    /// 不要包外层 `{}`——registry 会替你拼）。属性方法**必须**用
    /// `call('<name>', '<action>', payload)` 把消息发出去（`call` 由
    /// `AppNativeRegistry.shimSource` 在外层 IIFE 里定义）。
    ///
    /// 示例：
    /// ```
    /// {
    ///   set:    function(c)       { return call('cookie','set',c); },
    ///   get:    function(name, o) { return call('cookie','get',Object.assign({name:name},o||{})); }
    /// }
    /// ```
    func jsAPI() -> String

    /// native 侧 action 入口。插件自己负责 `switch action` 分发到具体 handler。
    /// 完成/失败时调用 `reply(AppNativeReply(...))` 回送结果。
    ///
    /// - Parameters:
    ///   - action: 子动作名（JS envelope 的 `action` 字段）
    ///   - payload: 参数 dict（envelope 的 `payload` 字段，原样转发）
    ///   - webView: 当前 WKWebView；插件用它拿 `WKHTTPCookieStore`、
    ///     `WKWebsiteDataStore` 等 per-webView 资源。
    ///   - reply: 回送 helper。`reply(AppNativeReply(ok: true, value: ...))` 或
    ///     `reply(AppNativeReply(ok: false, error: "..."))`。调用多次以最后一次为准；
    ///     不调用视为超时（JS 侧 30 s 后 reject）。
    func handle(action: String,
                payload: [String: Any],
                webView: WKWebView,
                reply: @escaping (AppNativeReply) -> Void)
}