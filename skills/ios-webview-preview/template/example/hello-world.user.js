// ==UserScript==
// @name         Hello World
// @namespace    http://example.com
// @version      1.0.0
// @description  在 console 打 hello —— 最简单的注入链路验证。
// @match        *
// @grant        none
// ==/UserScript==

(function() {
  'use strict';
  console.log('[hello] injected');
})();