/* Journal — общий скрипт сайта (desktop + mobile). Без зависимостей. */
(function () {
  'use strict';
  var root = document.documentElement;
  root.classList.add('js');
  var me = document.currentScript;
  var BASE = me && me.src ? me.src.replace(/[^\/]*$/, '') : '../assets/';
  var reduce = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function $(s, c) { return (c || document).querySelector(s); }
  function $$(s, c) { return Array.prototype.slice.call((c || document).querySelectorAll(s)); }
  function ls(k, v) {
    try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) {}
    return null;
  }
  function plural(n, f) {
    var a = Math.abs(n) % 100, b = a % 10;
    if (a > 10 && a < 20) return f[2];
    if (b > 1 && b < 5) return f[1];
    if (b === 1) return f[0];
    return f[2];
  }
  function comma(n, d) { return n.toFixed(d).replace('.', ','); }

  /* ================= ТЕМЫ ================= */
  var THEMES = [
    { id: 'default', n: 'Стандартная', h: 234, s: 92 },
    { id: 'mono', n: 'Чёрно-белая', h: 0, s: 0 },
    { id: 'red', n: 'Красная', h: 5, s: 88 },
    { id: 'pink', n: 'Розовая', h: 335, s: 88 },
    { id: 'purple', n: 'Пурпурная', h: 292, s: 78 },
    { id: 'deepPurple', n: 'Фиолетовая', h: 266, s: 82 },
    { id: 'indigo', n: 'Индиго', h: 226, s: 88 },
    { id: 'blue', n: 'Синяя', h: 205, s: 95 },
    { id: 'lightBlue', n: 'Голубая', h: 192, s: 95 },
    { id: 'cyan', n: 'Бирюзовая', h: 180, s: 92 },
    { id: 'teal', n: 'Морская волна', h: 170, s: 80 },
    { id: 'green', n: 'Зелёная', h: 125, s: 70 },
    { id: 'lightGreen', n: 'Салатовая', h: 85, s: 75 },
    { id: 'lime', n: 'Лаймовая', h: 64, s: 85 },
    { id: 'yellow', n: 'Жёлтая', h: 54, s: 95 },
    { id: 'amber', n: 'Янтарная', h: 44, s: 95 },
    { id: 'orange', n: 'Оранжевая', h: 34, s: 95 },
    { id: 'deepOrange', n: 'Тыквенная', h: 14, s: 92 },
    { id: 'brown', n: 'Коричневая', h: 18, s: 38 },
    { id: 'blueGrey', n: 'Серо-голубая', h: 200, s: 32 }
  ];

  function hex(h, s, l) {
    h = ((h % 360) + 360) % 360; s = Math.max(0, Math.min(100, s)) / 100; l = Math.max(0, Math.min(100, l)) / 100;
    var a = s * Math.min(l, 1 - l);
    function f(n) {
      var k = (n + h / 30) % 12, c = l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1));
      var v = Math.round(255 * c).toString(16);
      return v.length < 2 ? '0' + v : v;
    }
    return '#' + f(0) + f(8) + f(4);
  }

  function palette(t, dark) {
    var h = t.h, s = t.s, bump = Math.max(0, 1 - Math.abs(h - 65) / 50);
    var h2 = h + 48, h3 = h - 52;
    if (dark) {
      return {
        '--bg': hex(h, s * .16, 7.5), '--surface': hex(h, s * .15, 11.5), '--surface-2': hex(h, s * .15, 15.5),
        '--surface-3': hex(h, s * .15, 20), '--outline': hex(h, s * .12, 27),
        '--text': hex(h, 14, 91), '--muted': hex(h, 9, 74),
        '--primary': hex(h, Math.min(100, s * 1.1), 85), '--on-primary': hex(h, s * .75, 19),
        '--tonal': hex(h, s * .42, 29), '--on-tonal': hex(h, Math.min(100, s * 1.1), 91),
        '--t2': hex(h2, s * .3, 26), '--on-t2': hex(h2, Math.min(100, s), 90),
        '--t3': hex(h3, s * .34, 26), '--on-t3': hex(h3, Math.min(100, s), 90)
      };
    }
    var pl = 40 - 9 * bump;
    return {
      '--bg': hex(h, s * .7, 98.4), '--surface': hex(h, s * .45, 95.5), '--surface-2': hex(h, s * .4, 92),
      '--surface-3': hex(h, s * .36, 88.5), '--outline': hex(h, s * .25, 78),
      '--text': hex(h, 14, 10), '--muted': hex(h, 10, 30),
      '--primary': hex(h, s * .62, pl), '--on-primary': '#ffffff',
      '--tonal': hex(h, Math.min(100, s * 1.2), 90.5), '--on-tonal': hex(h, s * .8, 17),
      '--t2': hex(h2, Math.min(100, s * 1.1), 91), '--on-t2': hex(h2, s * .75, 17),
      '--t3': hex(h3, Math.min(100, s * 1.1), 91), '--on-t3': hex(h3, s * .75, 17)
    };
  }

  var mq = window.matchMedia ? matchMedia('(prefers-color-scheme: dark)') : null;
  var state = { mode: 'system', theme: 'default' };
  (function load() {
    var m = ls('journal-theme'), t = ls('journal-color');
    if (m === 'light' || m === 'dark' || m === 'system') state.mode = m;
    for (var i = 0; i < THEMES.length; i++) if (THEMES[i].id === t) state.theme = t;
  })();

  function isDark() { return state.mode === 'dark' || (state.mode === 'system' && mq && mq.matches); }
  function current() { for (var i = 0; i < THEMES.length; i++) if (THEMES[i].id === state.theme) return THEMES[i]; return THEMES[0]; }

  function applyTheme() {
    var dark = isDark(), t = current(), p = palette(t, dark);
    root.dataset.theme = dark ? 'dark' : 'light';
    root.dataset.mode = state.mode;
    root.style.colorScheme = dark ? 'dark' : 'light';
    for (var k in p) root.style.setProperty(k, p[k]);
    var meta = $('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', p['--bg']);
    $$('[data-mode]').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.mode === state.mode)); });
    $$('[data-color]').forEach(function (b) { b.setAttribute('aria-pressed', String(b.dataset.color === state.theme)); });
    $$('[data-theme-name]').forEach(function (e) { e.textContent = t.n; });
    $$('[data-theme-icon]').forEach(function (e) { e.src = BASE + 'icons/' + t.id + '.webp'; });
  }
  function setMode(m) { state.mode = m; ls('journal-theme', m); applyTheme(); }
  function setColor(c) { state.theme = c; ls('journal-color', c); applyTheme(); }
  if (mq) {
    var onMq = function () { if (state.mode === 'system') applyTheme(); };
    if (mq.addEventListener) mq.addEventListener('change', onMq); else if (mq.addListener) mq.addListener(onMq);
  }
  applyTheme();

  function buildThemeGrid() {
    var grid = $('#themeGrid');
    if (grid) {
      grid.innerHTML = THEMES.map(function (t) {
        return '<button type="button" class="tswatch" data-color="' + t.id + '" aria-pressed="false" aria-label="' + t.n + '">' +
          '<img src="' + BASE + 'icons/' + t.id + '.webp" alt="" width="96" height="96" decoding="async"></button>';
      }).join('');
    }
    $$('[data-color]').forEach(function (b) { b.addEventListener('click', function () { setColor(b.dataset.color); }); });
    $$('[data-mode]').forEach(function (b) { b.addEventListener('click', function () { setMode(b.dataset.mode); }); });
    var cyc = $$('[data-cycle-mode]');
    cyc.forEach(function (b) {
      b.addEventListener('click', function () {
        var order = ['system', 'light', 'dark'];
        setMode(order[(order.indexOf(state.mode) + 1) % 3]);
      });
    });
    var rnd = $('#themeRandom');
    if (rnd) rnd.addEventListener('click', function () {
      var c; do { c = THEMES[Math.floor(Math.random() * THEMES.length)].id; } while (c === state.theme);
      setColor(c);
    });
    applyTheme();
  }

  /* ================= SNACKBAR (отмена) ================= */
  var snackEl = $('#snack'), snackTimer = 0, snackUndo = null;
  function snack(msg, undo) {
    if (!snackEl) return;
    clearTimeout(snackTimer);
    snackUndo = undo || null;
    $('.sm', snackEl).textContent = msg;
    var btn = $('button', snackEl);
    btn.hidden = !undo;
    snackEl.classList.add('on');
    snackTimer = setTimeout(function () { snackEl.classList.remove('on'); snackUndo = null; }, 4800);
  }
  if (snackEl) {
    $('button', snackEl).addEventListener('click', function () {
      var f = snackUndo; snackUndo = null; snackEl.classList.remove('on'); clearTimeout(snackTimer);
      if (f) f();
    });
  }

  /* ================= ДЕМО: РАСПИСАНИЕ ================= */
  function demoWeek() {
    var week = $('#week'); if (!week) return;
    var list = $('#wlist'), txt = $('#wtxt');
    var DAYS = {
      '5': { n: 'Четверг, 5 ноября', l: [['Математика', '1 пара · ауд. 214', 'a'], ['Английский язык', '2 пара · ауд. 308', 'b'], ['Информатика', '3 пара · ауд. 105', 'c']] },
      '6': { n: 'Пятница, 6 ноября', l: [['Базы данных', '1 пара · ауд. 301', 'c'], ['Математика', '2 пара · ауд. 214', 'a']] },
      '7': { n: 'Суббота, 7 ноября', l: [['Информатика', '1 пара · ауд. 105', 'c'], ['Английский язык', '2 пара · ауд. 308', 'b']] },
      '8': { n: 'Воскресенье, 8 ноября', l: [] },
      '9': { n: 'Понедельник, 9 ноября', l: [['Математика', '1 пара · ауд. 214', 'a'], ['Базы данных', '2 пара · ауд. 301', 'c'], ['Английский язык', '3 пара · ауд. 308', 'b']] },
      '10': { n: 'Вторник, 10 ноября', l: [['Информатика', '1 пара · ауд. 105', 'c'], ['Математика', '2 пара · ауд. 214', 'a']] },
      '11': { n: 'Среда, 11 ноября', l: [['Английский язык', '1 пара · ауд. 308', 'b'], ['Базы данных', '2 пара · ауд. 301', 'c'], ['Информатика', '3 пара · ауд. 105', 'c']] }
    };
    function show(d) {
      var o = DAYS[d];
      if (!o) return;
      txt.textContent = o.n + (o.l.length ? ' · ' + o.l.length + ' ' + plural(o.l.length, ['пара', 'пары', 'пар']) : ' · выходной');
      if (!o.l.length) {
        list.innerHTML = '<li class="lz-empty"><span class="sun"><svg class="i"><use href="#i-sun"/></svg></span><b>Выходной</b><small>В этот день пар нет</small></li>';
        return;
      }
      list.innerHTML = o.l.map(function (x, i) {
        return '<li class="lz lz-' + x[2] + '"><span class="no">' + (i + 1) + '</span><span class="tx"><b>' + x[0] + '</b><small>' + x[1] + '</small></span></li>';
      }).join('');
      if (!reduce) {
        $$('li', list).forEach(function (li, i) {
          li.animate([{ transform: 'translateY(14px) scale(.96)' }, { transform: 'none' }], { duration: 320, delay: i * 55, easing: 'cubic-bezier(.2,.9,.2,1.1)', fill: 'backwards' });
        });
      }
    }
    var btns = $$('button', week);
    btns.forEach(function (b) {
      b.addEventListener('click', function () {
        btns.forEach(function (x) { x.setAttribute('aria-pressed', String(x === b)); });
        show(b.dataset.day);
      });
    });
    var start = btns.filter(function (b) { return b.getAttribute('aria-pressed') === 'true'; })[0] || btns[0];
    show(start.dataset.day);
  }

  /* ================= ДЕМО: ОЦЕНКИ ================= */
  function demoGrades() {
    var hist = $('#hist'); if (!hist) return;
    var avgEl = $('#avg'), nEl = $('#avgn'), undoBtn = $('#gundo'), clearBtn = $('#gclear');
    var grades = [7, 8, 9, 8, 10, 9, 6, 8], last = [];
    function col(v) { return 'hsl(' + Math.round((v - 1) / 9 * 118) + ',68%,64%)'; }
    var cols = [];
    for (var v = 1; v <= 10; v++) {
      var b = document.createElement('button');
      b.type = 'button'; b.className = 'hcol'; b.setAttribute('aria-label', 'Добавить оценку ' + v);
      b.innerHTML = '<span class="bar"><i style="background:' + col(v) + '"></i></span><b>' + v + '</b>';
      b.dataset.v = v;
      hist.appendChild(b); cols.push(b);
    }
    var shown = 0;
    function animateNum(to) {
      if (reduce) { avgEl.textContent = comma(to, 2); shown = to; return; }
      var from = shown, t0 = performance.now(), dur = 420;
      (function step(t) {
        var k = Math.min(1, (t - t0) / dur), e = 1 - Math.pow(1 - k, 3);
        avgEl.textContent = comma(from + (to - from) * e, 2);
        if (k < 1) requestAnimationFrame(step); else shown = to;
      })(t0);
    }
    function paint(bump) {
      var cnt = []; for (var i = 0; i <= 10; i++) cnt[i] = 0;
      grades.forEach(function (g) { cnt[g]++; });
      var max = Math.max.apply(null, cnt.slice(1).concat([3]));
      cols.forEach(function (c, i) {
        var n = cnt[i + 1];
        $('i', c).style.height = (n ? 14 + (n / max) * 86 : 6) + '%';
        c.classList.toggle('has', n > 0);
      });
      var sum = grades.reduce(function (a, b) { return a + b; }, 0);
      var avg = grades.length ? sum / grades.length : 0;
      animateNum(avg);
      nEl.textContent = grades.length + ' ' + plural(grades.length, ['оценка', 'оценки', 'оценок']);
      if (undoBtn) undoBtn.disabled = !last.length;
      if (bump != null && !reduce) {
        cols[bump - 1].animate([{ transform: 'scale(1)' }, { transform: 'scale(1.18)' }, { transform: 'scale(1)' }], { duration: 300, easing: 'ease-out' });
      }
    }
    hist.addEventListener('click', function (e) {
      var b = e.target.closest('.hcol'); if (!b) return;
      var v = +b.dataset.v;
      if (grades.length >= 60) return;
      grades.push(v); last.push(v); paint(v);
      snack('Оценка ' + v + ' добавлена', function () { grades.pop(); last.pop(); paint(); });
    });
    if (undoBtn) undoBtn.addEventListener('click', function () {
      if (!last.length) return; last.pop(); grades.pop(); paint();
    });
    if (clearBtn) clearBtn.addEventListener('click', function () {
      var backup = grades.slice(), lb = last.slice();
      grades = []; last = []; paint();
      snack('Все оценки удалены', function () { grades = backup; last = lb; paint(); });
    });
    avgEl.textContent = '0,00'; paint();
  }

  /* ================= ДЕМО: ПРОПУСКИ ================= */
  function demoAbsences() {
    var list = $('#absList'); if (!list) return;
    var LIMIT = 10, uid = 0;
    var SUBJ = ['Математика', 'Базы данных', 'Английский язык', 'Информатика', 'Физика', 'История'];
    var items = [
      mk('Математика', '2 пара', 2, false), mk('Базы данных', '1 пара', 2, false),
      mk('Английский язык', '3 пара', 2, false), mk('Информатика', '2 пара', 2, false), mk('История', '1 пара', 2, true)
    ];
    var cycle = 0;
    function mk(s, p, h, ex) { return { id: ++uid, s: s, p: p, hours: h, ex: ex }; }
    var elTot = $('#absTotal'), elBar = $('#absBar'), elNo = $('#absNo'), elYes = $('#absYes'), elPairs = $('#absPairs');
    var limit = $('#absLimit'), limitMsg = $('#absLimitMsg'), limitTitle = $('#absLimitTitle'), ringArc = $('#absRing'), ringTxt = $('#absRingTxt'), ringBox = $('#absRingBox');
    var CIRC = 2 * Math.PI * 34;

    function totals() {
      var no = 0, yes = 0;
      items.forEach(function (x) { if (x.ex) yes += x.hours; else no += x.hours; });
      return { no: no, yes: yes };
    }
    function sync() {
      var t = totals(), all = t.no + t.yes;
      elTot.textContent = all;
      $('#absTotalWord').textContent = plural(all, ['час', 'часа', 'часов']);
      elPairs.textContent = '≈ ' + Math.round(all / 2) + ' ' + plural(Math.round(all / 2), ['пара', 'пары', 'пар']);
      elNo.textContent = t.no + ' ч'; elYes.textContent = t.yes + ' ч';
      elBar.innerHTML = all ? '<i class="no" style="flex:' + t.no + '"></i><i class="yes" style="flex:' + t.yes + '"></i>' : '<i class="none"></i>';
      var over = t.no >= LIMIT, near = t.no >= 7;
      limit.classList.toggle('over', over);
      limit.hidden = !near;
      if (near) {
        if (over) {
          limitTitle.textContent = 'Лимит пропусков';
          limitMsg.textContent = 'Набрано ' + t.no + ' ' + plural(t.no, ['час', 'часа', 'часов']) + ' без уважительной причины — лимит ' + LIMIT + ' ч превышен';
          ringTxt.textContent = '!';
          ringArc.style.strokeDashoffset = 0;
        } else {
          limitTitle.textContent = 'Приближаетесь к лимиту';
          var left = LIMIT - t.no;
          limitMsg.textContent = 'Без уважительной ' + t.no + ' из ' + LIMIT + ' ч · осталось ' + left + ' ' + plural(left, ['час', 'часа', 'часов']);
          ringTxt.textContent = t.no + ' из ' + LIMIT;
          ringArc.style.strokeDashoffset = CIRC * (1 - t.no / LIMIT);
        }
      }
      $('#absEmpty').hidden = items.length > 0;
    }
    function row(x) {
      var li = document.createElement('li');
      li.className = 'aw'; li.dataset.id = x.id;
      li.innerHTML =
        '<div class="aw-bg l"><svg class="i"><use href="#i-check"/></svg><span>По уважительной</span></div>' +
        '<div class="aw-bg r"><span>Удалить</span><svg class="i"><use href="#i-trash"/></svg></div>' +
        '<div class="arow ' + (x.ex ? 'ex' : 'no') + '"><span class="hrs">' + x.hours + '</span>' +
        '<span class="tx"><b>' + x.s + '</b><small>' + x.p + ' · ' + x.hours + ' ' + plural(x.hours, ['час', 'часа', 'часов']) + ' · ' + (x.ex ? 'по уважительной' : 'без уважительной') + '</small></span>' +
        '<span class="acts"><button type="button" class="ab" data-a="swap" aria-label="Сменить причину"><svg class="i"><use href="#i-swap"/></svg></button>' +
        '<button type="button" class="ab" data-a="del" aria-label="Удалить пропуск"><svg class="i"><use href="#i-trash"/></svg></button></span></div>';
      return li;
    }
    function render(newId) {
      list.innerHTML = '';
      items.forEach(function (x) { list.appendChild(row(x)); });
      if (newId && !reduce) {
        var el = $('[data-id="' + newId + '"]', list);
        if (el) el.animate([{ transform: 'translateY(-16px) scale(.96)' }, { transform: 'none' }], { duration: 360, easing: 'cubic-bezier(.2,.9,.2,1.1)' });
      }
      sync();
    }
    function swap(id) {
      var x = items.filter(function (i) { return i.id === id; })[0]; if (!x) return;
      x.ex = !x.ex; render();
      snack(x.ex ? 'Теперь по уважительной причине' : 'Теперь без уважительной причины', function () { x.ex = !x.ex; render(); });
    }
    function del(id) {
      var idx = -1; items.forEach(function (i, k) { if (i.id === id) idx = k; });
      if (idx < 0) return;
      var x = items.splice(idx, 1)[0]; render();
      snack('Пропуск удалён', function () { items.splice(Math.min(idx, items.length), 0, x); render(x.id); });
    }
    list.addEventListener('click', function (e) {
      var b = e.target.closest('.ab'); if (!b) return;
      var id = +b.closest('.aw').dataset.id;
      if (b.dataset.a === 'swap') swap(id); else del(id);
    });

    /* свайп */
    var drag = null;
    list.addEventListener('pointerdown', function (e) {
      if (e.target.closest('.ab')) return;
      var r = e.target.closest('.arow'); if (!r) return;
      drag = { r: r, w: r.closest('.aw'), x: e.clientX, y: e.clientY, dx: 0, on: false, id: e.pointerId };
    });
    list.addEventListener('pointermove', function (e) {
      if (!drag || e.pointerId !== drag.id) return;
      var dx = e.clientX - drag.x, dy = e.clientY - drag.y;
      if (!drag.on) {
        if (Math.abs(dy) > 10 && Math.abs(dy) > Math.abs(dx)) { drag = null; return; }
        if (Math.abs(dx) < 8) return;
        drag.on = true;
        try { drag.r.setPointerCapture(e.pointerId); } catch (x) {}
        drag.r.style.transition = 'none';
      }
      drag.dx = dx;
      drag.r.style.transform = 'translateX(' + dx + 'px)';
      drag.w.classList.toggle('sr', dx > 6); drag.w.classList.toggle('sl', dx < -6);
    });
    function end(e) {
      if (!drag || (e && e.pointerId !== drag.id)) return;
      var d = drag; drag = null;
      d.r.style.transition = '';
      if (!d.on) return;
      var th = Math.min(110, d.w.offsetWidth * .28);
      var id = +d.w.dataset.id;
      if (d.dx > th) { d.r.style.transform = ''; swap(id); }
      else if (d.dx < -th) { d.r.style.transform = ''; del(id); }
      else { d.r.style.transform = ''; d.w.classList.remove('sr', 'sl'); }
    }
    list.addEventListener('pointerup', end); list.addEventListener('pointercancel', end);
    list.addEventListener('click', function (e) { if (drag && drag.on) e.stopPropagation(); }, true);

    var add = $('#absAdd');
    if (add) add.addEventListener('click', function () {
      if (items.length >= 14) { snack('Для примера достаточно — удалите пару пропусков'); return; }
      var s = SUBJ[cycle++ % SUBJ.length];
      var x = mk(s, ((cycle % 3) + 1) + ' пара', 2, false);
      items.unshift(x); render(x.id);
      snack('Пропуск добавлен', function () { var k = items.indexOf(x); if (k > -1) items.splice(k, 1); render(); });
    });
    var reset = $('#absReset');
    if (reset) reset.addEventListener('click', function () { uid = 0; cycle = 0; items = [mk('Математика', '2 пара', 2, false), mk('Базы данных', '1 пара', 2, false), mk('Английский язык', '3 пара', 2, false), mk('Информатика', '2 пара', 2, false), mk('История', '1 пара', 2, true)]; render(); });
    ringArc.style.strokeDasharray = CIRC;
    render();
  }


  /* ================= МЕЛКИЕ ДЕМО: отмена, переключатели, сегменты ================= */
  function demoMisc() {
    var b = $('#undoDemo'), r = $('#undoRow');
    if (b && r) {
      var gone = false;
      function setGone(g) {
        gone = g; r.classList.toggle('gone', g);
        b.querySelector('span').textContent = g ? 'Вернуть вручную' : 'Удалить оценку';
        b.setAttribute('aria-pressed', String(g));
      }
      b.addEventListener('click', function () {
        if (gone) { setGone(false); return; }
        setGone(true);
        snack('Оценка удалена', function () { setGone(false); });
      });
    }
    $$('.tg').forEach(function (t) {
      t.addEventListener('click', function () {
        var on = t.getAttribute('aria-checked') !== 'true';
        t.setAttribute('aria-checked', String(on));
        var lab = t.parentNode.querySelector('.tl'); if (lab) lab.textContent = on ? 'Вкл' : 'Выкл';
      });
    });
    $$('[data-seg]').forEach(function (g) {
      var bs = $$('button', g);
      bs.forEach(function (x) { x.addEventListener('click', function () { bs.forEach(function (y) { y.setAttribute('aria-pressed', String(y === x)); }); }); });
    });
  }

  /* ================= ПОЯВЛЕНИЕ ПРИ ПРОКРУТКЕ ================= */
  function reveal() {
    var els = $$('.rv');
    if (!('IntersectionObserver' in window) || reduce) { els.forEach(function (e) { e.classList.add('in'); }); return; }
    var io = new IntersectionObserver(function (en) {
      en.forEach(function (x) { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } });
    }, { rootMargin: '0px 0px -8% 0px', threshold: .08 });
    els.forEach(function (e) { io.observe(e); });
  }

  /* ================= АКТИВНЫЙ РАЗДЕЛ В МЕНЮ ================= */
  function navSpy() {
    var links = $$('[data-spy]'); if (!links.length || !('IntersectionObserver' in window)) return;
    var map = {};
    links.forEach(function (a) { var id = a.dataset.spy; (map[id] = map[id] || []).push(a); });
    var ids = Object.keys(map), vis = {};
    var io = new IntersectionObserver(function (en) {
      en.forEach(function (x) { vis[x.target.id] = x.isIntersecting ? x.intersectionRatio : 0; });
      var best = null, bv = 0;
      ids.forEach(function (id) { if (vis[id] > bv) { bv = vis[id]; best = id; } });
      if (!best) return;
      links.forEach(function (a) {
        var on = a.dataset.spy === best;
        a.classList.toggle('on', on);
        if (on) a.setAttribute('aria-current', 'true'); else a.removeAttribute('aria-current');
      });
    }, { rootMargin: '-35% 0px -45% 0px', threshold: [0, .01, .1, .3, .6, 1] });
    ids.forEach(function (id) { var el = document.getElementById(id); if (el) io.observe(el); });
  }

  /* ================= ПЛАТФОРМА ================= */
  (function platform() {
    var ua = navigator.userAgent || '', p = 'other';
    if (/Android/i.test(ua)) p = 'android';
    else if (/iPhone|iPad|iPod/i.test(ua) || (/Macintosh/i.test(ua) && navigator.maxTouchPoints > 1)) p = 'ios';
    root.dataset.plat = p;
  })();

  /* ================= ВКЛАДКИ УСТАНОВКИ ================= */
  function installTabs() {
    var tabs = $$('[data-tab]'); if (!tabs.length) return;
    function pick(id, focus) {
      tabs.forEach(function (t) {
        var on = t.dataset.tab === id;
        t.setAttribute('aria-selected', String(on)); t.tabIndex = on ? 0 : -1;
        if (on && focus) t.focus();
      });
      $$('[data-panel]').forEach(function (p) { p.hidden = p.dataset.panel !== id; });
    }
    tabs.forEach(function (t, i) {
      t.addEventListener('click', function () { pick(t.dataset.tab); });
      t.addEventListener('keydown', function (e) {
        var k = e.key, j = -1;
        if (k === 'ArrowRight') j = (i + 1) % tabs.length; else if (k === 'ArrowLeft') j = (i - 1 + tabs.length) % tabs.length;
        if (j > -1) { e.preventDefault(); pick(tabs[j].dataset.tab, true); }
      });
    });
    pick(root.dataset.plat === 'ios' ? 'ios' : 'android');
    $$('[data-goto-tab]').forEach(function (a) {
      a.addEventListener('click', function () { pick(a.dataset.gotoTab); });
    });
  }

  /* ================= FAB (мобильная версия) ================= */
  function fab() {
    var f = $('#fab'); if (!f || !('IntersectionObserver' in window)) return;
    var hide = {};
    var io = new IntersectionObserver(function (en) {
      en.forEach(function (x) { hide[x.target.id] = x.isIntersecting; });
      var any = Object.keys(hide).some(function (k) { return hide[k]; });
      f.classList.toggle('off', any);
    });
    ['heroActions', 'download', 'install'].forEach(function (id) { var el = document.getElementById(id); if (el) io.observe(el); });
  }

  /* ================= ПОЯВЛЕНИЕ ШАПКИ ПРИ СКРОЛЛЕ ================= */
  function scrolled() {
    var bar = $('[data-scroll-bar]'); if (!bar) return;
    var on = false;
    function f() { var s = (window.scrollY || root.scrollTop) > 8; if (s !== on) { on = s; bar.classList.toggle('scrolled', s); } }
    window.addEventListener('scroll', f, { passive: true }); f();
  }

  /* ================= КАРУСЕЛЬ (точки) ================= */
  function carousels() {
    $$('[data-carousel]').forEach(function (c) {
      var track = $('.ctrack', c), dots = $$('.cdot', c);
      if (!track || !dots.length) return;
      var slides = $$('.cslide', track), tick = 0;
      function update() {
        var mid = track.scrollLeft + track.clientWidth / 2, best = 0, bd = 1e9;
        slides.forEach(function (s, i) {
          var d = Math.abs(s.offsetLeft + s.offsetWidth / 2 - mid);
          if (d < bd) { bd = d; best = i; }
        });
        dots.forEach(function (d, i) { d.classList.toggle('on', i === best); });
      }
      track.addEventListener('scroll', function () { cancelAnimationFrame(tick); tick = requestAnimationFrame(update); }, { passive: true });
      dots.forEach(function (d, i) {
        d.addEventListener('click', function () {
          var s = slides[i];
          track.scrollTo({ left: s.offsetLeft - (track.clientWidth - s.offsetWidth) / 2, behavior: reduce ? 'auto' : 'smooth' });
        });
      });
      update();
    });
  }

  function init() {
    buildThemeGrid(); demoWeek(); demoGrades(); demoAbsences(); demoMisc();
    reveal(); navSpy(); installTabs(); fab(); scrolled(); carousels();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init); else init();
})();
