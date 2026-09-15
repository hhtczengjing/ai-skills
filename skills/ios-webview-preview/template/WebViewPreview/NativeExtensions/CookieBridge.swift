import Foundation
import WebKit

/// `$app.cookie` 插件 —— 跨域 cookie 桥。详见 SKILL.md "Native 扩展（$app 命名空间）"。
///
/// 通过 `WKHTTPCookieStore`（iOS 11+，本项目 iOS 15+）读写 cookie，对域不做
/// superdomain 校验 —— 这正是前端 `document.cookie` 做不到而我们桥的核心价值。
@MainActor
struct CookieBridgePlugin: AppNativePlugin {
    let name = "cookie"

    func jsAPI() -> String {
        """
        {
          set:    function(c)       { return call('cookie','set',c); },
          get:    function(name, o) { return call('cookie','get',Object.assign({name:name},o||{})); },
          list:   function(o)       { return call('cookie','list',o||{}); },
          delete: function(name, o) { return call('cookie','delete',Object.assign({name:name},o||{})); }
        }
        """
    }

    func handle(action: String,
                payload: [String: Any],
                webView: WKWebView,
                reply: @escaping (AppNativeReply) -> Void) {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        switch action {
        case "set":    handleSet(store: store, payload: payload, reply: reply)
        case "get":    handleGet(store: store, payload: payload, reply: reply)
        case "list":   handleList(store: store, payload: payload, reply: reply)
        case "delete": handleDelete(store: store, payload: payload, reply: reply)
        default:       reply(AppNativeReply(ok: false, error: "unknown_action"))
        }
    }

    // MARK: - helpers

    private func makeCookie(from payload: [String: Any]) -> HTTPCookie? {
        guard let name = payload["name"] as? String,
              let value = payload["value"] as? String,
              let domain = payload["domain"] as? String,
              !name.isEmpty, !domain.isEmpty else { return nil }
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: (payload["path"] as? String) ?? "/"
        ]
        if let secure = payload["secure"] as? Bool, secure {
            props[.secure] = "TRUE"
        }
        if let httpOnly = payload["httpOnly"] as? Bool, httpOnly {
            props[.init("HttpOnly")] = "TRUE"
        }
        if let expires = payload["expires"] as? Double, expires > 0 {
            props[.expires] = Date(timeIntervalSince1970: expires)
        }
        if let sameSite = payload["sameSite"] as? String {
            let policy: HTTPCookieStringPolicy?
            switch sameSite.lowercased() {
            case "strict": policy = .sameSiteStrict
            case "lax":    policy = .sameSiteLax
            case "none":   policy = .none
            default:       policy = nil
            }
            if let policy = policy { props[.sameSitePolicy] = policy }
        }
        return HTTPCookie(properties: props)
    }

    private static func cookieToJSON(_ c: HTTPCookie) -> [String: Any] {
        var d: [String: Any] = [
            "name": c.name,
            "value": c.value,
            "domain": c.domain,
            "path": c.path,
            "isSecure": c.isSecure,
            "isHTTPOnly": c.isHTTPOnly
        ]
        if let exp = c.expiresDate { d["expiresDate"] = exp.timeIntervalSince1970 }
        let sameSite: String
        switch c.sameSitePolicy {
        case .sameSiteStrict: sameSite = "strict"
        case .sameSiteLax:    sameSite = "lax"
        default:              sameSite = "none"
        }
        d["sameSitePolicy"] = sameSite
        return d
    }

    /// cookieDomain 完全等于 target，或 cookieDomain 以 "." 开头且 target 以
    /// cookieDomain 结尾（".example.com" 命中 "api.example.com"）。
    private static func domainMatches(_ cookieDomain: String, target: String) -> Bool {
        if cookieDomain == target { return true }
        if cookieDomain.hasPrefix(".") && target.hasSuffix(cookieDomain) { return true }
        return false
    }

    // MARK: - action handlers

    // setCookie / getAllCookies / deleteCookie 都在 @MainActor（WKHTTPCookieStore
    // 是 WK_SWIFT_UI_ACTOR），所以 completion handler 直接同步执行，不需要
    // DispatchQueue.main.async 嵌套。

    private func handleSet(store: WKHTTPCookieStore,
                           payload: [String: Any],
                           reply: @escaping (AppNativeReply) -> Void) {
        guard let cookie = makeCookie(from: payload) else {
            reply(AppNativeReply(ok: false, error: "invalid_args")); return
        }
        // iOS 17+ SDK：setCookie completion handler 已经不带 Error? 参数；cookie
        // 校验阶段已经拦下大部分非法输入，回调里直接 reply ok。
        store.setCookie(cookie) {
            reply(AppNativeReply(ok: true, value: ["name": cookie.name, "domain": cookie.domain]))
        }
    }

    private func handleGet(store: WKHTTPCookieStore,
                           payload: [String: Any],
                           reply: @escaping (AppNativeReply) -> Void) {
        guard let name = payload["name"] as? String, !name.isEmpty else {
            reply(AppNativeReply(ok: false, error: "invalid_args")); return
        }
        let targetDomain = payload["domain"] as? String
        store.getAllCookies { cookies in
            let pool = cookies ?? []
            let byName = pool.filter { $0.name == name }
            // 优先精确 domain 匹配，回退到后缀匹配
            let pick = byName.first { c in
                guard let td = targetDomain else { return c.domain == c.domain }
                return c.domain == td
            } ?? byName.first { c in
                guard let td = targetDomain else { return false }
                return Self.domainMatches(c.domain, target: td)
            }
            reply(AppNativeReply(ok: true, value: pick.map(Self.cookieToJSON) ?? NSNull()))
        }
    }

    private func handleList(store: WKHTTPCookieStore,
                            payload: [String: Any],
                            reply: @escaping (AppNativeReply) -> Void) {
        let targetDomain = payload["domain"] as? String
        store.getAllCookies { cookies in
            let pool = cookies ?? []
            let filtered = targetDomain == nil ? pool : pool.filter {
                Self.domainMatches($0.domain, target: targetDomain!)
            }
            reply(AppNativeReply(ok: true, value: filtered.map(Self.cookieToJSON)))
        }
    }

    private func handleDelete(store: WKHTTPCookieStore,
                              payload: [String: Any],
                              reply: @escaping (AppNativeReply) -> Void) {
        guard let name = payload["name"] as? String, !name.isEmpty else {
            reply(AppNativeReply(ok: false, error: "invalid_args")); return
        }
        let targetDomain = payload["domain"] as? String
        store.getAllCookies { cookies in
            let pool = cookies ?? []
            let match = pool.first { c in
                guard c.name == name else { return false }
                if let td = targetDomain {
                    return c.domain == td || Self.domainMatches(c.domain, target: td)
                }
                return true
            }
            guard let m = match else {
                reply(AppNativeReply(ok: true, value: ["deleted": false])); return
            }
            store.delete(m) {
                reply(AppNativeReply(ok: true, value: ["deleted": true]))
            }
        }
    }
}