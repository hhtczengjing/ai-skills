// ==UserScript==
// @name         Foo Bar
// @namespace    http://example.com
// @version      0.2.0
// @description  另一条日志，证明多个用户脚本同时注入到同一页面。
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  'use strict';
  console.log('[foo] running');
})();