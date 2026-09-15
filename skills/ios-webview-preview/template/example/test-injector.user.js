// ==UserScript==
// @name         Test Injector
// @namespace    http://example.com
// @version      0.1.0
// @description  改 title + 改 DOM 证明注入生效 —— `test-flow.sh` 截图依赖。
//                加载后页面 title 变成 `DEMO:INJECTED`，顶部导航栏立刻能看到；
//                body 背景变粉，#env-check / #marker 文本被替换。
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  'use strict';
  // 改 title —— 顶部导航栏立刻能看到
  document.title = 'DEMO:INJECTED';
  // 也把徽章改了 + 背景变粉，万一脚本真的跑了用户能直观看到
  function setText(sel, value) {
    var el = document.querySelector(sel);
    if (el) el.textContent = value;
  }
  setText('#env-check', 'env: browser-injected');
  setText('#marker', 'marker: injected by test-script');
  document.body && (document.body.style.backgroundColor = '#ffe4ec');
})();