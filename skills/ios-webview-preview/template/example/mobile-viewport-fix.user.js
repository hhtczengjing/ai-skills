// ==UserScript==
// @name         Mobile Viewport Fix
// @version      0.1.0
// @description  页面没有 viewport meta 时注入移动端视口，让桌面端 H5 在 iOS WKWebView 里按设备宽度布局。
//                已有 viewport meta 时不动 —— H5 自己的 layout 优先。
// @match        *
// @grant        none
// ==/UserScript==

/*
 * 调试场景：很多 H5 是桌面端布局（fixed 宽度 / 绝对定位），放到 iPhone 模拟器
 * 里直接被压成桌面尺寸，文字挤在一起。注入 `<meta name="viewport" ...>` 让
 * WebView 用设备宽度作为 layout viewport（默认是 980px），CSS 媒体查询、
 * `vw`/`vh` 单位、`rem` 等才会按移动端生效。
 *
 * 注入时机：documentStart。先于用户脚本（documentEnd），保证页面 layout
 * 计算时 viewport 已经就位。
 */
(function() {
  'use strict';

  const VIEWPORT_CONTENT = 'width=device-width, initial-scale=1, viewport-fit=cover';

  function inject() {
    var metas = document.querySelectorAll('meta[name="viewport"]');
    for (var i = 0; i < metas.length; i++) {
      // 已有 viewport meta：不碰，尊重 H5 自己的设置
      return;
    }
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = VIEWPORT_CONTENT;
    // 插到 head 顶部（如果有 head）或 body 顶部
    (document.head || document.documentElement).appendChild(meta);

    // 视觉标记：右上角浮一个小角标，方便在截图里一眼看出脚本跑了。
    // 真生产里不需要这一步（用户关掉就好），只是 demo 调试用。
    var badge = document.createElement('div');
    badge.id = '__mobile-viewport-fix-badge__';
    badge.textContent = '📱 viewport 注入';
    badge.style.cssText = 'position:fixed;top:8px;right:8px;background:#000;color:#fff;' +
      'font:12px -apple-system;padding:4px 8px;border-radius:4px;z-index:2147483647;' +
      'box-shadow:0 2px 6px rgba(0,0,0,.3);pointer-events:none;';
    (document.body || document.documentElement).appendChild(badge);
  }

  if (document.readyState === 'loading') {
    // DOM 还没解析完，documentStart 阶段会走到这里。监听 readystatechange
    // 也行，但 appendChild 到 documentElement 已经足够安全。
    inject();
  } else {
    // 极少见：documentStart 时 DOM 已经 ready（inline script 把所有东西塞完了）
    inject();
  }
})();