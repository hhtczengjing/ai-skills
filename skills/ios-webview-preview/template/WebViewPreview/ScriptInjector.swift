import Foundation

/// 用户脚本的 IIFE + try/catch 包装。
///
/// 油猴脚本的代码来自不可信的 H5 页面输入（用户自写 / URL 拉取），如果直接
/// 注入页面，一个 throw 会让页面后续 JS 整体挂掉。这里给所有用户脚本套一层
/// 错误隔离，错误统一打到 console（Xcode console 可见），不影响宿主页面。
enum ScriptInjector {
    static func wrappedSource(_ userCode: String) -> String {
        return "(function(){\ntry{\n\(userCode)\n}catch(e){console.error('[userscript error]',e)}})();"
    }
}