/* Journal — «Что нового»: подтягивает последний релиз с GitHub и рисует его.
   Таблица из описания релиза выводится как настоящая таблица (на телефоне — карточками). */
(function () {
  'use strict';
  var REPO = 'eugggeneee/journal';
  var API = 'https://api.github.com/repos/' + REPO + '/releases/latest';
  var PAGE = 'https://github.com/' + REPO + '/releases/latest';
  var CACHE_KEY = 'journal-release-v2';
  var CACHE_MS = 10 * 60 * 1000;

  var box = document.getElementById('release');
  if (!box) return;

  /* ---------- безопасный мини-markdown ---------- */
  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function safeUrl(u) {
    return /^(https?:\/\/|mailto:)/i.test(u) ? u : '#';
  }
  function inline(s) {
    var codes = [];
    s = esc(s).replace(/`([^`]+)`/g, function (_, c) {
      codes.push(c);
      return '\u0000' + (codes.length - 1) + '\u0000';
    });
    s = s
      .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, function (_, t, u) {
        return '<a href="' + safeUrl(u.replace(/&amp;/g, '&')) + '" target="_blank" rel="noopener">' + t + '</a>';
      })
      .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
      .replace(/(^|[\s(])\*([^*\s][^*]*)\*(?=[\s).,;:!?]|$)/g, '$1<em>$2</em>');
    return s.replace(/\u0000(\d+)\u0000/g, function (_, i) {
      return '<code>' + codes[+i] + '</code>';
    });
  }
  function splitRow(line) {
    line = line.trim().replace(/^\|/, '').replace(/\|$/, '');
    return line.split('|').map(function (c) { return c.trim(); });
  }
  function isSep(line) {
    return /^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/.test(line);
  }

  /* Разбираем описание релиза на блоки */
  function parse(md) {
    var lines = String(md || '').replace(/\r/g, '').split('\n');
    var blocks = [], i = 0;
    while (i < lines.length) {
      var l = lines[i];
      if (!l.trim()) { i++; continue; }
      var m;
      if ((m = /^(#{1,4})\s+(.*)$/.exec(l))) {
        blocks.push({ t: 'h', n: m[1].length, x: m[2].trim() }); i++; continue;
      }
      if (/^```/.test(l)) {
        var code = []; i++;
        while (i < lines.length && !/^```/.test(lines[i])) { code.push(lines[i]); i++; }
        i++;
        blocks.push({ t: 'code', x: code.join('\n') }); continue;
      }
      if (/\|/.test(l) && i + 1 < lines.length && isSep(lines[i + 1])) {
        var head = splitRow(l), rows = [];
        i += 2;
        while (i < lines.length && /\|/.test(lines[i]) && lines[i].trim()) { rows.push(splitRow(lines[i])); i++; }
        blocks.push({ t: 'table', head: head, rows: rows }); continue;
      }
      if (/^\s*[-*+]\s+/.test(l)) {
        var items = [];
        while (i < lines.length && /^\s*[-*+]\s+/.test(lines[i])) { items.push(lines[i].replace(/^\s*[-*+]\s+/, '')); i++; }
        blocks.push({ t: 'ul', items: items }); continue;
      }
      var p = [];
      while (i < lines.length && lines[i].trim() && !/^(#{1,4}\s|```|\s*[-*+]\s+)/.test(lines[i]) &&
             !(/\|/.test(lines[i]) && i + 1 < lines.length && isSep(lines[i + 1]))) { p.push(lines[i].trim()); i++; }
      blocks.push({ t: 'p', x: p.join(' ') });
    }
    return blocks;
  }

  function platformIcon(cell) {
    if (/android|🤖/i.test(cell)) return 'android';
    if (/iphone|ipad|ios|🍎/i.test(cell)) return 'ios';
    return '';
  }
  function stripEmoji(s) {
    return s.replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F]/gu, '').replace(/\s{2,}/g, ' ').trim();
  }

  function renderTable(b) {
    var h = '<div class="rtable-wrap"><table class="rtable"><thead><tr>';
    b.head.forEach(function (c) { h += '<th scope="col">' + inline(stripEmoji(c)) + '</th>'; });
    h += '</tr></thead><tbody>';
    b.rows.forEach(function (r) {
      var plat = platformIcon(r[0] || '');
      h += '<tr' + (plat ? ' class="p-' + plat + '"' : '') + '>';
      b.head.forEach(function (c, ci) {
        var v = r[ci] == null ? '' : r[ci];
        var lab = esc(stripEmoji(c));
        if (ci === 0) {
          h += '<th scope="row" data-label="' + lab + '"><span class="pf">' + inline(stripEmoji(v)) + '</span></th>';
        } else {
          h += '<td data-label="' + lab + '">' + inline(stripEmoji(v)) + '</td>';
        }
      });
      h += '</tr>';
    });
    return h + '</tbody></table></div>';
  }

  function fmtDate(iso) {
    try {
      return new Date(iso).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' });
    } catch (e) { return ''; }
  }

  function render(rel) {
    var tag = rel.tag_name || '';
    var blocks = parse(rel.body);
    var out = '';
    var verifyOpen = false;
    var skipSection = false;
    blocks.forEach(function (b, idx) {
      if (b.t === 'h') {
        /* Первый заголовок — название релиза, оно уже есть в шапке */
        if (idx === 0 && b.n <= 2) return;
        if (verifyOpen) { out += '</div></details>'; verifyOpen = false; }
        skipSection = false;
        if (/подлинност|контрольн|sha-?256|verify/i.test(b.x)) {
          out += '<details class="rverify"><summary>' + inline(b.x) + '</summary><div class="rv-in">';
          verifyOpen = true; return;
        }
        out += '<h4 class="rh">' + inline(b.x) + '</h4>'; return;
      }
      if (skipSection) return;
      if (b.t === 'table') out += renderTable(b);
      else if (b.t === 'ul') out += '<ul class="rlist">' + b.items.map(function (x) { return '<li>' + inline(x) + '</li>'; }).join('') + '</ul>';
      else if (b.t === 'code') out += '<pre class="rcode"><code>' + esc(b.x) + '</code></pre>';
      else out += '<p class="rp">' + inline(b.x) + '</p>';
    });
    if (verifyOpen) out += '</div></details>';

    var date = fmtDate(rel.published_at || rel.created_at);
    var head = '<div class="rhead"><span class="rbadge">' + esc(tag || 'Релиз') + '</span>' +
      (date ? '<span class="rdate">' + esc(date) + '</span>' : '') +
      '<a class="rlink" href="' + safeUrl(rel.html_url || PAGE) + '" target="_blank" rel="noopener">Открыть на GitHub</a></div>';
    box.innerHTML = head + '<div class="rbody">' + out + '</div>';
    box.setAttribute('data-state', 'ready');
    applyAssets(rel);
    var vEls = document.querySelectorAll('[data-version]');
    for (var k = 0; k < vEls.length; k++) vEls[k].textContent = tag;
  }

  /* Прямые ссылки на файлы релиза для кнопок «Скачать» */
  function applyAssets(rel) {
    var apk = '', ipa = '', sums = '';
    (rel.assets || []).forEach(function (a) {
      var n = (a.name || '').toLowerCase();
      if (/\.apk$/.test(n)) apk = a.browser_download_url;
      else if (/\.ipa$/.test(n)) ipa = a.browser_download_url;
      else if (/sha256/.test(n)) sums = a.browser_download_url;
    });
    function set(sel, url) {
      if (!url) return;
      var els = document.querySelectorAll(sel);
      for (var i = 0; i < els.length; i++) els[i].setAttribute('href', url);
    }
    set('[data-dl="android"]', apk);
    set('[data-dl="ios"]', ipa);
    set('[data-dl="sums"]', sums);
  }

  function fail() {
    box.setAttribute('data-state', 'error');
    box.innerHTML =
      '<div class="rfail"><p>Не получилось загрузить описание последней версии.</p>' +
      '<a class="rlink solid" href="' + PAGE + '" target="_blank" rel="noopener">Открыть релиз на GitHub</a></div>';
  }

  function readCache() {
    try {
      var c = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null');
      if (c && Date.now() - c.t < CACHE_MS && c.d && c.d.tag_name) return c.d;
    } catch (e) {}
    return null;
  }
  function writeCache(d) {
    try { sessionStorage.setItem(CACHE_KEY, JSON.stringify({ t: Date.now(), d: d })); } catch (e) {}
  }

  var cached = readCache();
  if (cached) { render(cached); return; }
  if (!window.fetch) { fail(); return; }

  var ctrl = window.AbortController ? new AbortController() : null;
  var timer = setTimeout(function () { if (ctrl) ctrl.abort(); }, 9000);
  fetch(API, { headers: { Accept: 'application/vnd.github+json' }, signal: ctrl ? ctrl.signal : undefined })
    .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function (d) { clearTimeout(timer); writeCache(d); render(d); })
    .catch(function () { clearTimeout(timer); fail(); });
})();
