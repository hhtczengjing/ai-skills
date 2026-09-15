// ==UserScript==
// @name         $app.cookie e2e
// @version      0.1.0
// @description  端到端测试 $app.cookie.{set,get,list,delete}：同源 + 跨域 + domain 后缀匹配 + 参数错误。
// @author       ios-webview-preview
// @match        *
// @grant        none
// ==/UserScript==

/*
 * 在 Settings → 用户脚本里点启用后，每次 WebView 加载页面都会跑一次。
 * 所有检查结果打到 console（Xcode → Devices and Simulators → Open Console，
 * 过滤进程名 `壹定橙`）。最后一行是 `SUMMARY: <pass>/<fail>`，整段 `[cookieBridge-e2e] FAILURES: <n>`
 * 出现表示有失败。
 *
 * 跨域 cookie（`example.com`）写进 WKWebView 的存储后，下次打开 `localhost` 页面也能 list 出来——
 * 跨域读写的核心能力跑这一条就够了。
 */
(async () => {
  'use strict';

  const TAG = '[cookieBridge-e2e]';
  const log = (...a) => console.log(TAG, ...a);

  let pass = 0, fail = 0;
  const assert = (cond, label) => {
    if (cond) { pass++; log('✓', label); }
    else      { fail++; log('✗', label); }
  };

  try {
    // -------- 同源 set + get --------
    log('--- same-origin set+get ---');
    await $app.cookie.set({
      name: '__cb_so', value: 'so_val',
      domain: 'localhost', path: '/'
    });
    const so = await $app.cookie.get('__cb_so', { domain: 'localhost' });
    assert(so && so.name === '__cb_so' && so.value === 'so_val',
           'same-origin get returns set value');
    assert(so && so.path === '/', 'same-origin path preserved');

    // -------- 跨域 set + get（核心能力） --------
    log('--- cross-domain set+get ---');
    await $app.cookie.set({
      name: '__cb_xd', value: 'xd_val',
      domain: 'example.com', path: '/',
      expires: 1735689600, secure: true, httpOnly: true, sameSite: 'lax'
    });
    const xd = await $app.cookie.get('__cb_xd', { domain: 'example.com' });
    assert(xd && xd.name === '__cb_xd' && xd.value === 'xd_val',
           'cross-domain get returns set value');
    assert(xd && xd.isSecure === true, 'secure flag preserved');
    assert(xd && xd.isHTTPOnly === true, 'httpOnly flag preserved');
    assert(xd && xd.sameSitePolicy === 'lax', 'sameSite=lax preserved');

    // -------- list all + filter by domain --------
    log('--- list all + filter ---');
    const all = await $app.cookie.list();
    assert(Array.isArray(all) && all.length >= 2,
           `list() returns >=2 cookies (got ${all.length})`);
    const sub = await $app.cookie.list({ domain: 'example.com' });
    assert(sub.every(c => c.domain === 'example.com' || c.domain === '.example.com'),
           'list({domain}) filters by domain / suffix');

    // -------- domain 后缀匹配（.example.com 命中 api.example.com） --------
    log('--- domain suffix match ---');
    await $app.cookie.set({
      name: '__cb_sf', value: 'sf_val',
      domain: '.example.com', path: '/'
    });
    const sf = await $app.cookie.get('__cb_sf', { domain: 'api.example.com' });
    assert(sf && sf.name === '__cb_sf' && sf.value === 'sf_val',
           '.example.com cookie matches api.example.com request');

    // -------- delete --------
    log('--- delete ---');
    const del = await $app.cookie.delete('__cb_so', { domain: 'localhost' });
    assert(del && del.deleted === true, 'delete returns {deleted:true}');
    const after = await $app.cookie.get('__cb_so', { domain: 'localhost' });
    assert(after == null, 'deleted cookie no longer returned by get');

    // -------- invalid args --------
    log('--- invalid args ---');
    try {
      await $app.cookie.set({ name: '', value: 'x', domain: 'localhost' });
      log('✗', 'empty name should reject (did not throw)');
      fail++;
    } catch (e) {
      assert(/invalid_args/.test(e.message),
             `empty name rejects with invalid_args (got: ${e.message})`);
    }

    // -------- 汇总 --------
    log(`SUMMARY: ${pass} passed, ${fail} failed`);
    if (fail > 0) console.error(TAG, 'FAILURES:', fail);
  } catch (e) {
    log('FATAL', e && e.message);
  }
})();