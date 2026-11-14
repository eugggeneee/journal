(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var REPO = 'eugggeneee/journal';
  var THEMES = window.JOURNAL_THEMES || [];
  var mq = window.matchMedia('(prefers-color-scheme: dark)');

  /* ---------- значки Material (24x24) ---------- */
  var CAL = 'M19 4h-1V3c0-.55-.45-1-1-1s-1 .45-1 1v1H8V3c0-.55-.45-1-1-1s-1 .45-1 1v1H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2z';
  var DOTS = 'M7 12h2v2H7zM11 12h2v2h-2zM15 12h2v2h-2zM7 16h2v2H7zM11 16h2v2h-2z';
  var IC = {
    cal: CAL + 'M5 10h14v10H5z' + DOTS, calF: CAL + DOTS,
    star: 'M12 17.27l4.15 2.51c.76.46 1.69-.22 1.49-1.08l-1.1-4.72 3.67-3.18c.67-.58.31-1.68-.57-1.75l-4.83-.41-1.89-4.46c-.34-.81-1.5-.81-1.84 0L9.19 8.63l-4.83.41c-.88.07-1.24 1.17-.57 1.75l3.67 3.18-1.1 4.72c-.2.86.73 1.54 1.49 1.08l4.15-2.5z',
    busy: CAL + 'M5 10h14v10H5z' + 'M9.4 18.6L12 16l2.6 2.6 1.1-1.1L13.1 14.9l2.6-2.6-1.1-1.1L12 13.8l-2.6-2.6-1.1 1.1 2.6 2.6-2.6 2.6z',
    busyF: CAL + 'M9.4 18.6L12 16l2.6 2.6 1.1-1.1L13.1 14.9l2.6-2.6-1.1-1.1L12 13.8l-2.6-2.6-1.1 1.1 2.6 2.6-2.6 2.6z',
    person: 'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v1c0 .55.45 1 1 1h14c.55 0 1-.45 1-1v-1c0-2.66-5.33-4-8-4z',
    add: 'M18 13h-5v5c0 .55-.45 1-1 1s-1-.45-1-1v-5H6c-.55 0-1-.45-1-1s.45-1 1-1h5V6c0-.55.45-1 1-1s1 .45 1 1v5h5c.55 0 1 .45 1 1s-.45 1-1 1z',
    more: 'M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z',
    editcal: CAL + 'M5 10h14v10H5z' + 'M8 18v-2l5.5-5.5 2 2L10 18z',
    check: 'M9 16.17L5.53 12.7c-.39-.39-1.02-.39-1.41 0-.39.39-.39 1.02 0 1.41l4.18 4.18c.39.39 1.02.39 1.41 0L20.29 7.71c.39-.39.39-1.02 0-1.41-.39-.39-1.02-.39-1.41 0L9 16.17z',
    food: 'M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4z',
    coffee: 'M18.5 3H6c-1.1 0-2 .9-2 2v5.71c0 3.83 2.95 7.18 6.78 7.29 3.96.12 7.22-3.06 7.22-7v-1h.5c1.93 0 3.5-1.57 3.5-3.5S20.43 3 18.5 3zM16 5v3H6V5h10zm2.5 3H18V5h.5c.83 0 1.5.67 1.5 1.5S19.33 8 18.5 8zM4 19h16v2H4z',
    groups: 'M12 12.75c1.63 0 3.07.39 4.24.9 1.08.48 1.76 1.56 1.76 2.73V18H6v-1.61c0-1.18.68-2.26 1.76-2.73 1.17-.52 2.61-.91 4.24-.91zM4 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm1.13 1.1c-.37-.06-.74-.1-1.13-.1-.99 0-1.93.21-2.78.58A2.01 2.01 0 0 0 0 16.43V18h4.5v-1.61c0-.83.23-1.61.63-2.29zM20 13c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm4 3.43c0-.81-.48-1.53-1.22-1.85A6.95 6.95 0 0 0 20 14c-.39 0-.76.04-1.13.1.4.68.63 1.46.63 2.29V18H24v-1.57zM12 6c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3z',
    glass: 'M6 2v6h.01L6 8.01 10 12l-4 4 .01.01H6V22h12v-5.99h-.01L18 16l-4-4 4-3.99-.01-.01H18V2H6zm10 14.5V20H8v-3.5l4-4 4 4zM8 4h8v3.5l-4 4-4-4V4z',
    up: 'M16.85 6.85l1.44 1.44-4.88 4.88-3.29-3.29c-.39-.39-1.02-.39-1.41 0l-6 6.01c-.39.39-.39 1.02 0 1.41.39.39 1.02.39 1.41 0L9.41 12.58l3.29 3.29c.39.39 1.02.39 1.41 0l5.59-5.58 1.44 1.44c.31.31.85.09.85-.35V6.5c.01-.28-.21-.5-.49-.5h-4.29c-.45 0-.67.54-.36.85z',
    down: 'M16.85 17.15l1.44-1.44-4.88-4.88-3.29 3.29c-.39.39-1.02.39-1.41 0l-6-6.01c-.39-.39-.39-1.02 0-1.41.39-.39 1.02-.39 1.41 0L9.41 11.42l3.29-3.29c.39-.39 1.02-.39 1.41 0l5.59 5.58 1.44-1.44c.31-.31.85-.09.85.35v4.29c0 .28-.22.5-.5.5h-4.29c-.45.01-.67-.53-.36-.84z',
    arrow: 'M8.71 11.71l2.59 2.59c.39.39 1.02.39 1.41 0l2.59-2.59c.63-.63.18-1.71-.71-1.71H9.41c-.89 0-1.33 1.08-.7 1.71z',
    palette: 'M12 3a9 9 0 0 0 0 18c1.1 0 2-.9 2-2 0-.52-.2-.99-.52-1.35a1.5 1.5 0 0 1 1.1-2.5H17a4 4 0 0 0 4-4c0-4.42-4.03-8.15-9-8.15zM6.5 12a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm3-4a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm3 4a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z',
    undo: 'M12.5 8c-2.65 0-5.05.99-6.9 2.6L3.71 8.71C3.08 8.08 2 8.52 2 9.41V15c0 .55.45 1 1 1h5.59c.89 0 1.34-1.08.71-1.71l-1.91-1.91c1.39-1.16 3.16-1.88 5.12-1.88 3.16 0 5.89 1.84 7.19 4.5.27.56.91.84 1.5.64.71-.23 1.07-1.04.75-1.72C20.23 10.42 16.65 8 12.5 8z',
    lock: 'M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-6 9c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zM9 8V6c0-1.66 1.34-3 3-3s3 1.34 3 3v2H9z',
    noacc: 'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v1c0 .55.45 1 1 1h14c.55 0 1-.45 1-1v-1c0-2.66-5.33-4-8-4z',
    offline: 'M12 4C7.31 4 3.07 5.9 0 8.98L12 21 24 8.98A16.88 16.88 0 0 0 12 4zM2.92 9.07C5.51 7.08 8.67 6 12 6s6.49 1.08 9.08 3.07L12 18.17l-9.08-9.1z',
    android: 'M6 18c0 .55.45 1 1 1h1v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h2v3.5c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5V19h1c.55 0 1-.45 1-1V8H6v10zM3.5 8C2.67 8 2 8.67 2 9.5v7c0 .83.67 1.5 1.5 1.5S5 17.33 5 16.5v-7C5 8.67 4.33 8 3.5 8zm17 0c-.83 0-1.5.67-1.5 1.5v7c0 .83.67 1.5 1.5 1.5s1.5-.67 1.5-1.5v-7c0-.83-.67-1.5-1.5-1.5zm-4.97-5.84l1.3-1.3c.2-.2.2-.51 0-.71-.2-.2-.51-.2-.71 0l-1.48 1.48A5.84 5.84 0 0 0 12 1c-.96 0-1.86.23-2.66.63L7.85.15c-.2-.2-.51-.2-.71 0-.2.2-.2.51 0 .71l1.31 1.31A5.98 5.98 0 0 0 6 7h12c0-1.99-.97-3.75-2.47-4.84zM10 5H9V4h1v1zm5 0h-1V4h1v1z',
    apple: 'M17.05 12.04c-.03-2.74 2.24-4.06 2.34-4.12-1.28-1.87-3.26-2.12-3.96-2.15-1.69-.17-3.3.99-4.15.99-.86 0-2.18-.97-3.58-.94-1.84.03-3.54 1.07-4.49 2.72-1.92 3.32-.49 8.24 1.38 10.94.91 1.32 2 2.8 3.43 2.75 1.38-.06 1.9-.89 3.57-.89 1.66 0 2.14.89 3.6.86 1.49-.03 2.43-1.34 3.33-2.67 1.05-1.53 1.48-3.01 1.51-3.09-.03-.01-2.9-1.11-2.93-4.4zM14.3 3.9c.76-.92 1.27-2.2 1.13-3.47-1.09.04-2.41.73-3.19 1.64-.7.81-1.31 2.11-1.15 3.36 1.22.09 2.45-.62 3.21-1.53z',
    sun: 'M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zM2 13h2c.55 0 1-.45 1-1s-.45-1-1-1H2c-.55 0-1 .45-1 1s.45 1 1 1zm18 0h2c.55 0 1-.45 1-1s-.45-1-1-1h-2c-.55 0-1 .45-1 1s.45 1 1 1zM11 2v2c0 .55.45 1 1 1s1-.45 1-1V2c0-.55-.45-1-1-1s-1 .45-1 1zm0 18v2c0 .55.45 1 1 1s1-.45 1-1v-2c0-.55-.45-1-1-1s-1 .45-1 1zM5.99 4.58a.996.996 0 1 0-1.41 1.41l1.06 1.06c.39.39 1.03.39 1.41 0s.39-1.03 0-1.41L5.99 4.58zm12.37 12.37a.996.996 0 1 0-1.41 1.41l1.06 1.06c.39.39 1.03.39 1.41 0a.996.996 0 0 0 0-1.41l-1.06-1.06zm1.06-10.96a.996.996 0 1 0-1.41-1.41l-1.06 1.06a.996.996 0 1 0 1.41 1.41l1.06-1.06zM7.05 18.36a.996.996 0 1 0-1.41-1.41l-1.06 1.06a.996.996 0 1 0 1.41 1.41l1.06-1.06z',
    moon: 'M12 3a9 9 0 1 0 9 9c0-.46-.04-.92-.1-1.36a5.389 5.389 0 0 1-4.4 2.26 5.403 5.403 0 0 1-3.14-9.8c-.44-.06-.9-.1-1.36-.1z'
  };
  function svg(name, cls) {
    return '<svg class="' + (cls || 'ico') + '" viewBox="0 0 24 24" aria-hidden="true"><path fill-rule="evenodd" d="' + IC[name] + '"/></svg>';
  }
  $$('[data-ic]').forEach(function (el) { el.innerHTML = svg(el.getAttribute('data-ic'), ''); });

  /* ---------- тема: роли Material 3 из palette.js ---------- */
  var S = { theme: 'default', mode: null };
  try { S.theme = localStorage.getItem('j-theme') || 'default'; S.mode = localStorage.getItem('j-mode'); } catch (e) {}
  function isDark() { return S.mode ? S.mode === 'dark' : mq.matches; }
  function cur() { return THEMES.filter(function (t) { return t.id === S.theme; })[0] || THEMES[0]; }
  var MAP = { sLow: 'surfaceContainerLow', sMid: 'surfaceContainer', sHigh: 'surfaceContainerHigh', sHighest: 'surfaceContainerHighest' };
  function applyTheme() {
    var t = cur(); if (!t) return;
    var root = document.documentElement, c = isDark() ? t.dark : t.light;
    Object.keys(c).forEach(function (k) { root.style.setProperty('--' + k, c[k]); });
    Object.keys(MAP).forEach(function (k) { root.style.setProperty('--' + k, c[MAP[k]]); });
    root.style.colorScheme = isDark() ? 'dark' : 'light';
    var m = $('meta[name=theme-color]'); if (m) m.content = c.surfaceContainer;
    var b = $('#mode'); b.innerHTML = svg(isDark() ? 'sun' : 'moon');
    b.setAttribute('aria-label', isDark() ? 'Включить светлую тему' : 'Включить тёмную тему');
    $$('.theme').forEach(function (el) {
      var selected = el.dataset.id === t.id;
      el.setAttribute('aria-checked', String(selected)); el.tabIndex = selected ? 0 : -1;
    });
    $('#themeCurrent').textContent = 'Выбрана тема: ' + t.name;
    paintBars(); renderPhones();
  }
  $('#mode').addEventListener('click', function () {
    S.mode = isDark() ? 'light' : 'dark';
    try { localStorage.setItem('j-mode', S.mode); } catch (e) {}
    applyTheme();
  });
  mq.addEventListener && mq.addEventListener('change', function () { if (!S.mode) applyTheme(); });
  var grid = $('#themeGrid');
  THEMES.forEach(function (t) {
    var b = document.createElement('button');
    b.className = 'theme'; b.type = 'button'; b.dataset.id = t.id; b.setAttribute('role', 'radio');
    b.innerHTML = '<img src="assets/icons/' + t.id + '.png" width="64" height="64" alt="" loading="lazy"><span>' + t.name + '</span>';
    b.addEventListener('click', function () {
      S.theme = t.id; try { localStorage.setItem('j-theme', t.id); } catch (e) {}
      applyTheme();
    });
    grid.appendChild(b);
  });
  grid.addEventListener('keydown', function (e) {
    var buttons = $$('.theme', grid), index = buttons.indexOf(e.target), next = index;
    if (index < 0) return;
    var columns = getComputedStyle(grid).gridTemplateColumns.split(' ').length;
    if (e.key === 'ArrowRight') next++;
    else if (e.key === 'ArrowLeft') next--;
    else if (e.key === 'ArrowDown') next += columns;
    else if (e.key === 'ArrowUp') next -= columns;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = buttons.length - 1;
    else return;
    e.preventDefault(); next = (next + buttons.length) % buttons.length;
    buttons[next].click(); buttons[next].focus();
  });

  /* Верхнее меню не закрывает страницу прозрачной подложкой. */
  var menu = $('#menuToggle'), header = $('#top'), narrow = window.matchMedia('(max-width: 1000px)');
  function closeMenu() {
    header.classList.remove('menu-open'); menu.setAttribute('aria-expanded', 'false'); menu.setAttribute('aria-label', 'Открыть меню');
  }
  menu.addEventListener('click', function () {
    var open = menu.getAttribute('aria-expanded') !== 'true';
    header.classList.toggle('menu-open', open); menu.setAttribute('aria-expanded', String(open));
    menu.setAttribute('aria-label', open ? 'Закрыть меню' : 'Открыть меню');
    if (open) $('#nav a').focus();
  });
  $('#nav').addEventListener('click', function (e) {
    var link = e.target.closest('a'); if (!link) return;
    closeMenu();
    if (narrow.matches) {
      var section = $(link.getAttribute('href'));
      section.setAttribute('tabindex', '-1'); section.focus({ preventScroll: true });
    }
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && menu.getAttribute('aria-expanded') === 'true') { closeMenu(); menu.focus(); }
  });
  header.addEventListener('focusout', function (e) { if (!header.contains(e.relatedTarget)) closeMenu(); });
  narrow.addEventListener('change', function () {
    var hiddenFocus = narrow.matches && $('#nav').contains(document.activeElement);
    closeMenu(); if (hiddenFocus) menu.focus();
  });

  /* ---------- цвета оценок и статусов (ui/kit/foundation/ctx.dart) ---------- */
  var GS = [1, 3, 4.5, 6, 7.5, 9, 10], GH = [4, 14, 30, 44, 76, 128, 152];
  function gHue(v) {
    var x = Math.min(10, Math.max(1, v));
    for (var i = 0; i < GS.length - 1; i++) if (x <= GS[i + 1]) return GH[i] + (GH[i + 1] - GH[i]) * (x - GS[i]) / (GS[i + 1] - GS[i]);
    return GH[GH.length - 1];
  }
  function hsl(h, s, l) { return 'hsl(' + (h % 360).toFixed(1) + ' ' + s * 100 + '% ' + l * 100 + '%)'; }
  function pastel(h) { return isDark() ? { bg: hsl(h, .66, .76), fg: hsl(h, .70, .16) } : { bg: hsl(h, .90, .86), fg: hsl(h, .75, .20) }; }
  function accent(h) { return isDark() ? hsl(h, .78, .64) : hsl(h, .72, .50); }
  function soft(h) { return isDark() ? hsl(h, .60, .72) : hsl(h, .62, .60); }
  var HR = 4, HG = 140;
  function plural(n, a, b, c) { var m = n % 100, d = n % 10; return (m > 10 && m < 20) ? c : d === 1 ? a : (d > 1 && d < 5) ? b : c; }
  function mix(a, pa, b) { return 'color-mix(in srgb,' + a + ' ' + pa + '%,' + b + ')'; }
  function tone(bg, fg) { return 'background:' + bg + ';color:' + fg; }

  function paintBars() {
    var dist = [0, 1, 1, 1, 3, 3, 4, 7, 8, 5].map(function (v, i, a) { return v; });
    var max = Math.max.apply(null, dist);
    $$('[data-bars]').forEach(function (el) {
      el.innerHTML = dist.map(function (v, i) { return '<i style="background:' + accent(gHue(i + 1)) + ';height:' + (v ? 10 + 46 * v / max : 4) + 'px"></i>'; }).join('');
    });
  }

  /* ---------- экраны приложения ---------- */
  var DATA = [
    { n: 1, t: 'Операционные системы', r: 'ауд. 214', p: 'Иванова А. П.', s: '08:20', e: '10:00', st: 'now', br: ['Перерыв', '09:05–09:15'] },
    { n: 2, t: 'Математика', r: 'ауд. 305', p: 'Петров С. В.', s: '10:10', e: '11:50', st: 'f' },
    { n: 3, t: 'Основы алгоритмизации', r: 'ауд. 118', p: 'Соколова Е. Н.', s: '12:20', e: '14:00', st: 'f' },
    { n: 4, t: 'Иностранный язык', r: 'ауд. 410', p: 'Кузнецова М. А.', s: '14:10', e: '15:45', st: 'f' }
  ];
  var GAPS = [['Перерыв 10 мин', '10:00–10:10', 0], ['Обед 30 мин', '11:50–12:20', 1], ['Перерыв 10 мин', '14:00–14:10', 0]];
  var DAYS = [['Чт', 5], ['Пт', 6], ['Сб', 7], ['Вс', 8], ['Пн', 9], ['Вт', 10], ['Ср', 11], ['Чт', 12], ['Пт', 13]];
  var SUBJ = [['Информатика', [9, 10, 9, 8, 10]], ['Математика', [7, 8, 9, 8, 9, 9]], ['Операционные системы', [7, 6, 8, 7, 8]], ['Иностранный язык', [8, 8, 9, 7]]];
  function avg(a) { return a.reduce(function (x, y) { return x + y; }, 0) / a.length; }
  function fmt(v) { return v.toFixed(2).replace('.', ','); }

  function status(time) {
    return '<div class="island"></div><div class="status"><span>' + time + '</span><span class="sr">' +
      '<svg width="19" height="12" viewBox="0 0 19 12" fill="currentColor"><rect x="0" y="8" width="3.4" height="4" rx="1"/><rect x="5" y="5.5" width="3.4" height="6.5" rx="1"/><rect x="10" y="3" width="3.4" height="9" rx="1"/><rect x="15" y="0" width="3.4" height="12" rx="1"/></svg>' +
      '<svg width="17" height="12" viewBox="0 0 17 12" fill="currentColor"><path d="M8.5 2.3c2.3 0 4.4.9 6 2.4l1-1.1A10.4 10.4 0 0 0 8.5.8 10.4 10.4 0 0 0 1.5 3.6l1 1.1a8.8 8.8 0 0 1 6-2.4zm0 3.6c1.3 0 2.5.5 3.4 1.3l1-1.1a7 7 0 0 0-8.8 0l1 1.1c.9-.8 2.1-1.3 3.4-1.3zm0 3.5c-.6 0-1.2.2-1.6.6L8.5 12l1.6-2c-.4-.4-1-.6-1.6-.6z"/></svg>' +
      '<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.8" fill="none" stroke="currentColor" opacity="1" style="stroke:var(--outline)"/><rect x="2" y="2" width="17" height="9" rx="2.5" fill="currentColor"/><path d="M25 4.5v4c.8-.3 1.5-1.1 1.5-2s-.7-1.7-1.5-2z" style="fill:var(--outline)"/></svg></span></div>';
  }
  function pageHead(title, sub, extra) {
    return '<div class="hd"><div class="tt"><h4>' + title + '</h4><div class="st">' + sub + '</div></div>' + (extra || '') + '</div>';
  }
  function scheduleScreen() {
    var prim = tone('var(--primaryContainer)', 'var(--onPrimaryContainer)');
    var strip = DAYS.map(function (d) {
      var sel = d[1] === 9, sun = d[0] === 'Вс';
      return '<div class="dc' + (sel ? ' sel' : '') + (sun && !sel ? ' sun' : '') + '"><div><small>' + d[0] + '</small><strong>' + d[1] + '</strong><i style="background:' + (sel ? 'var(--onPrimary)' : 'transparent') + '"></i></div></div>';
    }).join('');
    var rows = '', gi = 0;
    DATA.forEach(function (l, i) {
      var now = l.st === 'now', first = i === 0;
      var card = now ? mix('var(--primaryContainer)', 50, 'var(--sLow)') : 'var(--sLow)';
      var nb = now ? tone('var(--primary)', 'var(--onPrimary)') : tone('var(--primaryContainer)', 'var(--onPrimaryContainer)');
      var br = l.br ? '<div class="ibr" style="background:var(--tertiaryContainer);color:var(--onTertiaryContainer);background:' + mix('var(--tertiaryContainer)', 70, 'var(--sLow)') + '">' + svg('coffee') + '<span>' + l.br[0] + '</span><em>' + l.br[1] + '</em></div>' : '';
      rows += '<div class="row' + (first ? ' f' : '') + (now ? ' cur' : '') + '"><div class="rl"><span class="nd' + (now ? ' now' : '') + '"></span></div>' +
        '<div class="tm" style="color:' + (now ? 'var(--primary)' : 'var(--onSurface)') + '">' + l.s + '<small>' + l.e + '</small></div>' +
        '<div class="lc" style="background:' + card + '"><div class="in1" style="padding-bottom:' + (br ? 10 : 14) + 'px"><div class="nb" style="' + nb + '">' + l.n + '</div><div class="tx"><b>' + l.t + '</b><span>' + l.r + '&nbsp;&nbsp;' + l.p + '</span></div><div class="ib">' + svg('busy') + '</div></div>' + br + '</div></div>';
      if (i < DATA.length - 1 && GAPS[gi]) {
        var g = GAPS[gi++], lunch = g[2];
        var gb = lunch ? 'var(--tertiaryContainer)' : 'var(--secondaryContainer)', gf = lunch ? 'var(--onTertiaryContainer)' : 'var(--onSecondaryContainer)';
        rows += '<div class="row"><div class="rl"></div><div class="gp" style="' + tone(gb, gf) + '">' + svg(lunch ? 'food' : 'coffee') + '<span>' + g[0] + '</span><em>' + g[1] + '</em></div></div>';
      }
    });
    return '<div class="pg" data-pg="0">' +
      pageHead('Сегодня', '9 ноября 2026 · Понедельник', '<div class="ab">' + svg('editcal') + '</div><div class="ab">' + svg('more') + '</div>') +
      '<div class="mrow"><b>Ноябрь 2026</b><span class="pill-s" style="' + tone('var(--secondaryContainer)', 'var(--onSecondaryContainer)') + '">' + svg('groups') + 'Группа ИС-21</span></div>' +
      '<div class="strip">' + strip + '</div><div class="day">' +
      '<div class="sumr"><div class="l1"><h5>4 пары</h5><div class="split"><span>' + svg('busy') + 'Весь день</span><span>' + svg('arrow') + '</span></div></div><p>08:20 – 15:45 · осталось 4 пары</p></div>' +
      '<div class="hero-s" style="' + prim + '"><div class="r1"><span>Идёт сейчас · 1 пара</span><span>08:20–09:05</span></div><h6>Операционные системы</h6>' +
      '<div class="sb" style="color:' + mix('var(--onPrimaryContainer)', 85, 'var(--primaryContainer)') + '">ауд. 214 · Иванова А. П.</div>' +
      '<div class="lf"><span>до конца</span><b>17</b><span>мин</span></div>' +
      '<div class="bar" style="background:' + mix('var(--onPrimaryContainer)', 14, 'var(--primaryContainer)') + '"><u data-w="62" style="background:var(--primary);width:62%"></u></div></div>' +
      '<div class="tl">' + rows + '</div></div></div>';
  }
  function gradesScreen() {
    var all = [].concat.apply([], SUBJ.map(function (s) { return s[1]; }));
    var a = avg(all), tn = pastel(gHue(a));
    var dist = [], i; for (i = 1; i <= 10; i++) dist.push(all.filter(function (v) { return v === i; }).length);
    var max = Math.max.apply(null, dist);
    var bars = dist.map(function (c, k) {
      return '<div><i style="height:' + (c ? 10 + 46 * c / max : 4) + 'px;background:' + (c ? accent(gHue(k + 1)) : mix(tn.fg, 20, tn.bg)) + '"></i><small style="color:' + tn.fg + '">' + (k + 1) + '</small></div>';
    }).join('');
    var list = SUBJ.slice().sort(function (x, y) { return x[0] < y[0] ? -1 : 1; }).map(function (s) {
      var av = avg(s[1]), t = pastel(gHue(av)), last = s[1][s[1].length - 1], prev = avg(s[1].slice(0, -1));
      var spark = s[1].map(function (v) { return '<i style="height:' + (6 + 18 * (v - 1) / 9) + 'px;background:' + accent(gHue(v)) + '"></i>'; }).join('');
      var up = av >= prev;
      return '<div class="oc"><div class="m"><b>' + s[0] + '</b><span>' + s[1].length + ' ' + plural(s[1].length, 'оценка', 'оценки', 'оценок') + ' · последняя ' + last + '</span><div class="spark">' + spark + '</div></div>' +
        '<div class="vp"><div class="vpill" style="' + tone(t.bg, t.fg) + '">' + fmt(av) + '</div>' + svg(up ? 'up' : 'down').replace('class="ico"', 'style="color:' + accent(gHue(up ? 9 : 2)) + '"') + '</div></div>';
    }).join('');
    return '<div class="pg" data-pg="1"><div class="lg" style="height:76px"><h4>Оценки</h4><p>20 оценок · 4 предмета</p></div><div class="ins">' +
      '<div class="hs" style="' + tone(tn.bg, tn.fg) + '"><div class="cap">Средний балл</div><div class="big"><b>' + fmt(a) + '</b><div class="as">20 оценок<br>4 предмета</div></div><div class="dist">' + bars + '</div></div>' +
      '<div class="msw"><span class="on">Предметы</span><span>Журнал</span></div>' +
      '<div class="sh"><b>Предметы</b><span>4 предмета</span></div><div class="ocl">' + list + '</div></div></div>';
  }
  function absencesScreen() {
    var r = pastel(HR), red = soft(HR);
    function lim(title, sub, h, lim) {
      var left = lim - h, w = Math.round(h / lim * 100), wa = h / lim > .8;
      var t = wa ? pastel(42) : { bg: 'var(--sLow)', fg: 'var(--onSurface)' };
      return '<div class="lim" style="' + tone(t.bg, t.fg) + '"><div class="t"><b>' + title + '</b><span>' + h + ' из ' + lim + ' ч</span></div>' +
        '<div style="margin-top:2px;color:' + (wa ? t.fg : 'var(--onSurfaceVariant)') + '">' + sub + ' · осталось ' + left + ' ' + plural(left, 'час', 'часа', 'часов') + '</div>' +
        '<div class="bar" style="background:' + mix(wa ? t.fg : 'var(--onSurface)', 12, wa ? t.bg : 'var(--sLow)') + '"><u style="width:' + w + '%;background:' + (wa ? soft(42) : red) + '"></u></div></div>';
    }
    return '<div class="pg" data-pg="2"><div class="lg"><h4>Пропуски</h4><p>14 часов пропущено</p></div><div class="ins">' +
      '<div class="hs" style="' + tone(r.bg, r.fg) + '"><div class="cap">Всего пропущено</div><div class="big"><b>14 ч</b><div class="as">без причины 10 ч<br>по уважительной 4 ч</div></div>' +
      '<div class="bar" style="margin-top:18px;background:' + mix(r.fg, 14, r.bg) + '"><u style="width:71%;background:' + red + '"></u></div></div>' +
      lim('За месяц', 'Ноябрь', 6, 10) + lim('За семестр', 'Осенний семестр', 14, 72) + '</div></div>';
  }
  var TABS = [['cal', 'calF', 'Расписание'], ['star', 'star', 'Оценки'], ['busy', 'busyF', 'Пропуски'], ['person', 'person', 'Профиль']];
  var FAB = ['Добавить', 'Оценка', 'Пропуск'];
  var phones = [];
  function phoneHTML(tab) {
    var nav = TABS.map(function (t, i) {
      return '<button class="nit" type="button" data-t="' + i + '" aria-pressed="' + (i === tab) + '"' + (i === 3 ? ' disabled' : '') + '><span class="pill">' + svg(i === tab ? t[1] : t[0]) + '</span>' + t[2] + '</button>';
    }).join('');
    return '<div class="phone" role="group" aria-label="Витрина Journal"><div class="scr">' + status('8:48') +
      '<div class="pages" role="img" aria-label="Экран приложения Journal">' + scheduleScreen() + gradesScreen() + absencesScreen() + '</div>' +
      '<div class="fab">' + svg('add') + '<span>' + FAB[tab] + '</span></div>' +
      '<div class="nbar" role="group" aria-label="Переключить экран макета">' + nav + '</div><div class="home"></div></div></div>';
  }
  function showTab(p, i) {
    p.tab = i;
    $$('.pg', p.el).forEach(function (pg, k) {
      pg.classList.toggle('hide', k !== i);
    });
    $$('.nit', p.el).forEach(function (b, k) {
      var on = k === i; b.setAttribute('aria-pressed', String(on));
      b.querySelector('.pill').innerHTML = svg(on ? TABS[k][1] : TABS[k][0]);
    });
    $('.pages', p.el).setAttribute('aria-label', 'Экран «' + TABS[i][2] + '» приложения Journal');
    var f = $('.fab', p.el);
    f.style.display = i < 3 ? '' : 'none'; if (i < 3) f.lastChild.textContent = FAB[i];
    if (p.onTab) p.onTab(i);
  }
  function renderPhones() {
    phones.forEach(function (p) {
      p.host.innerHTML = '<div class="pbox">' + phoneHTML(p.tab) + '</div>';
      p.box = $('.pbox', p.host); p.el = $('.phone', p.host);
      $$('.nit', p.el).forEach(function (b) {
        b.addEventListener('click', function () { var i = +b.dataset.t; if (i < 3 && p.interactive) showTab(p, i); if (i < 3 && p.interactive && p.sync) p.sync(i); });
      });
      showTab(p, p.tab); fit(p);
    });
  }
  function fit(p) {
    if (!p.box) return;
    var w = p.host.clientWidth || 417, maxH = p.maxH || 876;
    var k = Math.min(1, w / 417, maxH / 876);
    p.box.style.setProperty('--k', k.toFixed(4));
  }
  var TEXTS = [
    ['Расписание', 'Пары на любую дату', 'Лента дня с временем, перерывами и обедом. Карточка «Сейчас» показывает, что идёт и сколько осталось.'],
    ['Оценки', 'Средний балл под рукой', 'Оценки с пометками, динамика по каждому предмету и распределение по шкале 1-10.'],
    ['Пропуски', 'Лимиты без сюрпризов', 'Отметка у пары или на весь день. Приложение предупредит, когда лимит месяца или семестра близко.']
  ];
  var seg = $('#seg'), showText = $('#showText'), mainP;
  seg.innerHTML = TEXTS.map(function (t, i) { return '<button type="button" role="tab" id="screenTab' + i + '" aria-controls="showText" data-i="' + i + '">' + svg(TABS[i][1]) + t[0] + '<span class="tab-arrow" aria-hidden="true">↗</span></button>'; }).join('');
  function setText(i) {
    $$('button', seg).forEach(function (b, k) { b.setAttribute('aria-selected', String(k === i)); b.tabIndex = k === i ? 0 : -1; });
    showText.setAttribute('aria-labelledby', 'screenTab' + i);
    showText.innerHTML = '<div><h3>' + TEXTS[i][1] + '</h3><p>' + TEXTS[i][2] + '</p></div>';
  }
  $$('[data-phone]').forEach(function (host) {
    var main = host.hasAttribute('data-main');
    var p = { host: host, tab: 0, interactive: main, maxH: main ? 724 : 660 };
    if (main) { mainP = p; p.sync = setText; }
    phones.push(p);
  });
  seg.addEventListener('click', function (e) {
    var b = e.target.closest('button'); if (!b || !mainP) return;
    var i = +b.dataset.i; showTab(mainP, i); setText(i);
  });
  seg.addEventListener('keydown', function (e) {
    var buttons = $$('button', seg), index = buttons.indexOf(e.target), next = index;
    if (index < 0) return;
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') next++;
    else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') next--;
    else if (e.key === 'Home') next = 0;
    else if (e.key === 'End') next = buttons.length - 1;
    else return;
    e.preventDefault(); next = (next + buttons.length) % buttons.length;
    buttons[next].click(); buttons[next].focus();
  });
  setText(0);
  var rt; window.addEventListener('resize', function () { clearTimeout(rt); rt = setTimeout(function () { phones.forEach(fit); }, 60); });
  if (window.ResizeObserver) phones.forEach(function (p) { new ResizeObserver(function () { fit(p); }).observe(p.host); });

  /* Разделы видны сразу; прокрутка меняет только пункт навигации. */
  if ('IntersectionObserver' in window) {
    var links = $$('#nav a'), secs = links.map(function (a) { return $(a.getAttribute('href')); });
    var so = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (!e.isIntersecting) return;
        links.forEach(function (a) {
          var on = a.getAttribute('href') === '#' + e.target.id; a.classList.toggle('on', on);
          if (on) a.setAttribute('aria-current', 'location'); else a.removeAttribute('aria-current');
        });
      });
    }, { rootMargin: '-35% 0px -60% 0px' });
    secs.forEach(function (s) { if (s) so.observe(s); });
  }

  /* ---------- релизы GitHub ---------- */
  var API = 'https://api.github.com/repos/' + REPO + '/releases?per_page=8';
  function el(tag, cls, text) { var n = document.createElement(tag); if (cls) n.className = cls; if (text != null) n.textContent = text; return n; }
  function inline(parent, s) {
    s.split(/(\*\*[^*]+\*\*|`[^`]+`)/).forEach(function (part) {
      if (!part) return;
      if (part.indexOf('**') === 0) parent.appendChild(el('strong', '', part.slice(2, -2)));
      else if (part[0] === '`') parent.appendChild(el('code', '', part.slice(1, -1)));
      else parent.appendChild(document.createTextNode(part.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')));
    });
  }
  function bodyNode(md) {
    var lines = (md || '').replace(/\r/g, '').split('\n'), out = [], i, on = false, found = false;
    for (i = 0; i < lines.length; i++) if (/^#{1,4}\s*Что нового/i.test(lines[i])) { found = true; break; }
    var box = el('div', 'rel-body'), ul = null, code = false;
    for (i = found ? i + 1 : 0; i < lines.length; i++) {
      var l = lines[i].trim();
      if (/^```/.test(l)) { code = !code; continue; }
      if (code || !l) continue;
      if (/^#{1,4}\s/.test(l)) { if (found) break; else continue; }
      if (/^\|/.test(l)) continue;
      if (/^[-*]\s+/.test(l)) { if (!ul) { ul = el('ul'); box.appendChild(ul); } var li = el('li'); inline(li, l.replace(/^[-*]\s+/, '')); ul.appendChild(li); }
      else { ul = null; var p = el('p'); inline(p, l); box.appendChild(p); }
    }
    if (!box.childNodes.length) box.appendChild(el('p', '', 'Описание изменений смотрите на странице релиза.'));
    return box;
  }
  function dateText(s) { try { return new Date(s).toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Minsk' }); } catch (e) { return ''; } }
  function asset(rel, suffix) { return (rel.assets || []).filter(function (a) { return a.name.slice(-suffix.length) === suffix; })[0]; }
  function size(b) { return (b / 1048576).toFixed(0) + ' МБ'; }
  function relHead(r) {
    var h = el('div', 'rel-head'); h.appendChild(el('h3', '', r.name && r.name.length < 40 ? r.name : r.tag_name));
    h.appendChild(el('span', 'tag' + (r.prerelease ? ' beta' : ''), r.prerelease ? 'тестовая версия' : 'стабильная'));
    h.appendChild(el('span', 'rel-date', dateText(r.published_at))); return h;
  }
  function renderReleases(list) {
    var rels = list.filter(function (r) { return !r.draft; });
    if (!rels.length) throw new Error('empty');
    var newest = rels[0], stable = rels.filter(function (r) { return !r.prerelease; })[0] || newest;
    var box = $('#releaseFeed'); box.textContent = ''; box.setAttribute('aria-busy', 'false');
    var c = el('div', 'card news-card'); c.appendChild(relHead(newest)); c.appendChild(bodyNode(newest.body));
    var f = el('div', 'rel-foot'), a = el('a', 'btn btn-tonal', 'Все изменения на GitHub'); a.href = newest.html_url; a.rel = 'noopener'; f.appendChild(a); c.appendChild(f);
    box.appendChild(c);
    var older = rels.slice(1, 5);
    if (older.length) {
      var o = el('div', 'older');
      older.forEach(function (r) {
        var d = el('details'), s = el('summary'); s.appendChild(el('b', '', r.tag_name)); s.appendChild(el('span', 'rel-date', dateText(r.published_at)));
        if (r.prerelease) s.appendChild(el('span', 'tag beta', 'тест'));
        d.appendChild(s); d.appendChild(bodyNode(r.body)); o.appendChild(d);
      });
      box.appendChild(o);
    }
    var chip = $('#verChip'); if (chip) chip.textContent = 'Версия ' + stable.tag_name.replace(/^v/, '');
    [['Android', '-android.apk', '#dlAndroid', '#metaAndroid'], ['iPhone', '-ios.ipa', '#dlIos', '#metaIos']].forEach(function (x) {
      var as = asset(stable, x[1]) || asset(newest, x[1]), btn = $(x[2]), meta = $(x[3]);
      if (as) { btn.href = as.browser_download_url; meta.textContent = (stable.tag_name) + ' · ' + size(as.size) + (newest !== stable && asset(newest, x[1]) ? ' · тестовая ' + newest.tag_name : ''); }
      else { btn.href = stable.html_url; meta.textContent = 'Файл на странице релиза ' + stable.tag_name; }
    });
  }
  function fail() {
    var box = $('#releaseFeed'); box.textContent = ''; box.setAttribute('aria-busy', 'false');
    var c = el('div', 'card news-card'); c.appendChild(el('p', 'sub', 'Не удалось загрузить данные с GitHub. Свежие версии и список изменений всегда на странице релизов.'));
    var a = el('a', 'btn btn-fill', 'Открыть релизы'); a.href = 'https://github.com/' + REPO + '/releases'; a.rel = 'noopener'; c.appendChild(a); box.appendChild(c);
  }
  (function load() {
    var cached = null;
    try { cached = JSON.parse(sessionStorage.getItem('j-rel') || 'null'); } catch (e) {}
    if (cached && Date.now() - cached.t < 600000) { try { renderReleases(cached.d); return; } catch (e) {} }
    fetch(API, { headers: { Accept: 'application/vnd.github+json' } })
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (d) { try { sessionStorage.setItem('j-rel', JSON.stringify({ t: Date.now(), d: d })); } catch (e) {} renderReleases(d); })
      .catch(fail);
  })();

  applyTheme();
})();
