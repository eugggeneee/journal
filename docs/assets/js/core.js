/* Journal landing · shared behaviour (theme, palette, widgets, live demo) */
(function(){
'use strict';
var $=function(s,r){return (r||document).querySelector(s)},$$=function(s,r){return [].slice.call((r||document).querySelectorAll(s))};
var root=document.documentElement;
var reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
var KV={get:function(k){try{return localStorage.getItem(k)}catch(e){return null}},set:function(k,v){try{localStorage.setItem(k,v)}catch(e){}}};
function plural(n,f){var a=Math.abs(n)%100,b=a%10;return (a>10&&a<20)?f[2]:b>1&&b<5?f[1]:b===1?f[0]:f[2]}
function icon(n,c){return '<svg class="i '+(c||'')+'"><use href="#i-'+n+'"/></svg>'}
var HUES=[];for(var hk=0;hk<20;hk++)HUES.push({n:'Цвет '+(hk+1),h:(277+18*hk)%360});
var THEMES=[['system','Системная'],['light','Светлая'],['dark','Тёмная']];
var S={theme:KV.get('journal-theme')||'system',hue:+(KV.get('journal-hue')||277),quick:+(KV.get('journal-quick')||2),vib:KV.get('journal-vib')!=='0',auto:KV.get('journal-auto')!=='0'};
if(!THEMES.some(function(t){return t[0]===S.theme}))S.theme='system';
if(!HUES.some(function(x){return x.h===S.hue}))S.hue=277;
if(S.quick!==1&&S.quick!==2)S.quick=2;

/* ── theme / palette ── */
function toHex(c){try{var x=document.createElement('canvas').getContext('2d');x.fillStyle='#000';x.fillStyle=c;return x.fillStyle}catch(e){return c}}
function themeColor(){
  var c=getComputedStyle(document.body).backgroundColor;
  $$('meta[name=theme-color]').forEach(function(m,i){if(i)m.remove()});
  var m=$('meta[name=theme-color]');if(!m){m=document.createElement('meta');m.name='theme-color';document.head.appendChild(m)}
  m.removeAttribute('media');m.content=toHex(c);
}
function syncControls(){
  $$('[data-t]').forEach(function(b){b.setAttribute('aria-pressed',b.dataset.t===S.theme)});
  $$('[data-hue]').forEach(function(b){b.setAttribute('aria-pressed',+b.dataset.hue===S.hue)});
  $$('[data-q]').forEach(function(b){b.setAttribute('aria-pressed',+b.dataset.q===S.quick)});
  $$('.switch[data-key]').forEach(function(b){b.setAttribute('aria-checked',!!S[b.dataset.key])});
}
function setTheme(t){S.theme=t;root.dataset.theme=t;KV.set('journal-theme',t);syncControls();themeColor()}
function setHue(h){S.hue=h;root.style.setProperty('--h',h);KV.set('journal-hue',h);syncControls();themeColor()}
function setQuick(q){S.quick=q;KV.set('journal-quick',q);syncControls()}
function fillControls(scope){
  $$('[data-theme-seg]',scope).forEach(function(el){el.classList.add('seg');el.setAttribute('role','group');el.innerHTML=THEMES.map(function(t){return '<button type="button" data-t="'+t[0]+'" aria-pressed="false">'+icon('check')+t[1]+'</button>'}).join('')});
  $$('[data-quick-seg]',scope).forEach(function(el){el.classList.add('seg');el.setAttribute('role','group');el.innerHTML='<button type="button" data-q="2" aria-pressed="false">'+icon('check')+'2 часа (пара)</button><button type="button" data-q="1" aria-pressed="false">'+icon('check')+'1 час</button>'});
  $$('[data-swatches]',scope).forEach(function(el){el.classList.add('swatches');el.setAttribute('role','group');el.innerHTML=HUES.map(function(x){return '<button type="button" class="sw-dot" data-hue="'+x.h+'" aria-label="'+x.n+'" aria-pressed="false" style="--sw:oklch(.78 .12 '+x.h+');--hh:'+x.h+'">'+icon('check')+'</button>'}).join('')});
}
document.addEventListener('click',function(e){
  var b=e.target.closest('[data-t],[data-hue],[data-q],.switch[data-key]');if(!b)return;
  if(b.dataset.t)setTheme(b.dataset.t);
  else if(b.dataset.hue)setHue(+b.dataset.hue);
  else if(b.dataset.q)setQuick(+b.dataset.q);
  else if(b.dataset.key){var k=b.dataset.key;S[k]=!S[k];KV.set('journal-'+k,S[k]?'1':'0');syncControls();buzz(10)}
});
function buzz(ms){if(S.vib&&navigator.vibrate){try{navigator.vibrate(ms)}catch(e){}}}

/* ── popover menu (origin-aware) ── */
var menu=$('#menu');
if(menu){
  var trig=null;
  var close=function(){menu.removeAttribute('data-open');if(trig){trig.setAttribute('aria-expanded','false');trig=null}};
  $$('[data-menu-btn]').forEach(function(btn){btn.addEventListener('click',function(ev){
    ev.stopPropagation();
    if(trig===btn){close();return}
    trig=btn;btn.setAttribute('aria-expanded','true');
    var r=btn.getBoundingClientRect();
    menu.style.top=menu.style.bottom=menu.style.left=menu.style.right='auto';
    if(btn.dataset.place==='right'){menu.style.left=(r.right+14)+'px';menu.style.bottom=Math.max(12,innerHeight-r.bottom)+'px';menu.style.setProperty('--ox','0 100%')}
    else{menu.style.top=(r.bottom+10)+'px';menu.style.right=Math.max(12,innerWidth-r.right)+'px';menu.style.setProperty('--ox','100% 0')}
    menu.setAttribute('data-open','');
  })});
  document.addEventListener('pointerdown',function(e){if(menu.hasAttribute('data-open')&&!menu.contains(e.target)&&!e.target.closest('[data-menu-btn]'))close()});
  document.addEventListener('keydown',function(e){if(e.key==='Escape'&&menu.hasAttribute('data-open')){var t=trig;close();if(t)t.focus()}});
}

/* ── scroll spy ── */
(function(){
  var links=$$('[data-spy]');if(!links.length||!('IntersectionObserver' in window))return;
  var map={};links.forEach(function(a){var id=(a.getAttribute('href')||'').slice(1);(map[id]=map[id]||[]).push(a)});
  var io=new IntersectionObserver(function(es){es.forEach(function(en){var ls=map[en.target.id]||[];if(en.isIntersecting){links.forEach(function(a){a.removeAttribute('aria-current')});ls.forEach(function(a){a.setAttribute('aria-current','true')})}else ls.forEach(function(a){a.removeAttribute('aria-current')})})},{rootMargin:'-40% 0px -55% 0px'});
  Object.keys(map).forEach(function(id){var s=document.getElementById(id);if(s)io.observe(s)});
})();

/* ── pause decorative loops offscreen ── */
if('IntersectionObserver' in window){
  var po=new IntersectionObserver(function(es){es.forEach(function(en){en.target.classList.toggle('off',!en.isIntersecting)})},{rootMargin:'120px'});
  $$('.morph,.morph2,.marquee .track,[data-loop]').forEach(function(el){po.observe(el)});
}

/* ── FAQ: one open at a time ── */
$$('.faq details').forEach(function(d){d.addEventListener('toggle',function(){if(d.open)$$('.faq details').forEach(function(o){if(o!==d)o.open=false})})});

/* ── gallery ── */
$$('[data-gal]').forEach(function(wrap){
  var tr=$('.gal',wrap),fs=$$('figure',tr),dots=$$('.dots i',wrap),pv=$('[data-prev]',wrap),nx=$('[data-next]',wrap);
  function idx(){var w=fs[0].offsetWidth+20;return Math.max(0,Math.min(fs.length-1,Math.round(tr.scrollLeft/w)))}
  function upd(){var i=idx();dots.forEach(function(d,k){d.classList.toggle('on',k===i)});if(pv)pv.disabled=tr.scrollLeft<4;if(nx)nx.disabled=tr.scrollLeft+tr.clientWidth>=tr.scrollWidth-4}
  tr.addEventListener('scroll',function(){requestAnimationFrame(upd)},{passive:true});
  function go(d){tr.scrollBy({left:d*(fs[0].offsetWidth+20)*(innerWidth>900?2:1),behavior:reduce?'auto':'smooth'})}
  if(pv)pv.addEventListener('click',function(){go(-1)});if(nx)nx.addEventListener('click',function(){go(1)});
  upd();
});

/* ── feature widgets ── */
(function(){
  var wk=$('#week'),wt=$('#wtxt');
  if(wk)$$('button',wk).forEach(function(b){b.addEventListener('click',function(){$$('button',wk).forEach(function(x){x.setAttribute('aria-pressed',x===b)});var off=/^(Сб|Вс)/.test(b.textContent);wt.textContent=b.dataset.d+(off?' — выходной':' — пары загружены');buzz(8)})});
  var hist=$('#hist');
  if(hist){
    var cnt={7:1,8:1,9:1};
    for(var g=1;g<=10;g++){var d=document.createElement('div');d.dataset.g=g;d.setAttribute('role','button');d.tabIndex=0;d.setAttribute('aria-label','Добавить оценку '+g);d.style.setProperty('--c',g===7?'#e8c93a':'#6fd283');d.style.setProperty('--h',100);d.innerHTML='<i></i><span>'+g+'</span>';hist.appendChild(d)}
    var draw=function(){var tot=0,sum=0,mx=1;for(var k in cnt){tot+=cnt[k];sum+=cnt[k]*k;mx=Math.max(mx,cnt[k])}
      $$('div',hist).forEach(function(d){var c=cnt[d.dataset.g]||0;if(c){d.setAttribute('data-on','');d.style.setProperty('--h',Math.max(34,c/mx*100))}else d.removeAttribute('data-on')});
      $('#avg').textContent=tot?(sum/tot).toFixed(2).replace('.',','):'—';
      $('#avgn').textContent=tot?tot+' '+plural(tot,['оценка','оценки','оценок']):'Нет оценок'};
    var add=function(d){var g=d.dataset.g;cnt[g]=((cnt[g]||0)+1)>3?0:(cnt[g]||0)+1;draw();buzz(8)};
    hist.addEventListener('click',function(e){var d=e.target.closest('[data-g]');if(d)add(d)});
    hist.addEventListener('keydown',function(e){if(e.key==='Enter'||e.key===' '){var d=e.target.closest('[data-g]');if(d){e.preventDefault();add(d)}}});
    setTimeout(draw,60);
  }
  var ab=$('#abs'),tt=$('#tot');
  if(ab)ab.addEventListener('click',function(){var on=ab.getAttribute('aria-pressed')!=='true';ab.setAttribute('aria-pressed',on);tt.textContent=on?'2 часа':'0 часов';$('small',ab).textContent=on?'1 пара · 2 часа':'Нажмите, чтобы отметить пропуск';buzz(12)});
})();

/* ── верхняя панель: прогресс прокрутки, скользящий индикатор, раздел (телефон) ── */
(function(){
  var t=$('[data-top]')||$('.topbar');if(!t)return;
  var raf=0;
  function prog(){var h=document.documentElement.scrollHeight-innerHeight;t.style.setProperty('--p',h>0?Math.min(1,Math.max(0,scrollY/h)).toFixed(4):'0');t.toggleAttribute('data-scrolled',scrollY>8)}
  addEventListener('scroll',function(){if(!raf)raf=requestAnimationFrame(function(){raf=0;prog()})},{passive:true});
  addEventListener('resize',prog);prog();
  /* компьютер: «пилюля» следует за курсором и отдыхает на текущем разделе */
  var tabs=$('.tabs',t),ind=tabs&&$('.ind',tabs);
  if(tabs&&ind){
    var links=$$('a',tabs),ready=false;
    function hot(a){
      links.forEach(function(l){l.toggleAttribute('data-hot',l===a)});
      if(!a){ind.removeAttribute('data-on');return}
      ind.style.setProperty('--x',a.offsetLeft+'px');ind.style.setProperty('--w',a.offsetWidth+'px');ind.setAttribute('data-on','');
      if(!ready){ready=true;requestAnimationFrame(function(){requestAnimationFrame(function(){ind.setAttribute('data-ready','')})})}
    }
    function rest(){hot($('a[aria-current]',tabs))}
    links.forEach(function(a){
      a.addEventListener('pointerenter',function(e){if(e.pointerType==='mouse')hot(a)});
      a.addEventListener('focus',function(){hot(a)});
    });
    tabs.addEventListener('pointerleave',rest);tabs.addEventListener('focusout',rest);
    new MutationObserver(function(){if(!tabs.matches(':hover'))rest()}).observe(tabs,{subtree:true,attributes:true,attributeFilter:['aria-current']});
    addEventListener('resize',rest);
    if(document.fonts&&document.fonts.ready)document.fonts.ready.then(rest);
    rest();
  }
  /* телефон: плашка с названием текущего раздела */
  var lab=$('[data-sec]',t),bn=$('.bnav');
  if(lab&&bn){
    var shown='';
    function sec(){
      var a=$('a[aria-current]',bn),h=a&&a.getAttribute('href'),txt=(!a||h==='#top')?'':a.textContent.trim();
      if(txt===shown)return;shown=txt;
      if(!txt){lab.hidden=true;return}
      lab.hidden=false;lab.classList.remove('sw');void lab.offsetWidth;lab.textContent=txt;lab.classList.add('sw');
    }
    new MutationObserver(sec).observe(bn,{subtree:true,attributes:true,attributeFilter:['aria-current']});
    sec();
  }
})();

/* ── hero: three screens, swipe / tap / auto ── */
(function(){
  var st=$('[data-hero]');if(!st)return;
  var phs=$$('.ph',st),tabs=$$('[data-hs]',st.parentNode),N=phs.length,cur=0,timer=null,stopped=false,visible=true,sx=0,sy=0,moved=false,down=false;
  var NAMES=['Расписание','Оценки','Пропуски'];
  function pos(i){var d=(i-cur+N)%N;return d===0?0:d===1?1:-1}
  function render(){
    phs.forEach(function(p,i){var ps=pos(i);p.dataset.pos=ps;p.setAttribute('aria-hidden',ps!==0?'true':'false');if(ps===0){p.removeAttribute('tabindex');p.removeAttribute('role')}else{p.tabIndex=0;p.setAttribute('role','button');p.setAttribute('aria-label','Показать экран: '+NAMES[i])}});
    tabs.forEach(function(t,i){t.setAttribute('aria-pressed',i===cur)});
  }
  function go(i,user){cur=(i%N+N)%N;if(user)halt();render()}
  function halt(){stopped=true;clearInterval(timer)}
  function auto(){if(reduce||stopped)return;timer=setInterval(function(){if(visible&&!document.hidden&&!stopped)go(cur+1)},5200)}
  if(!reduce){st.setAttribute('data-intro','');render();requestAnimationFrame(function(){requestAnimationFrame(function(){st.removeAttribute('data-intro')})})}else render();
  tabs.forEach(function(t,i){t.addEventListener('click',function(){go(i,true)})});
  var pv=$('[data-hprev]',st.parentNode),nx=$('[data-hnext]',st.parentNode);
  if(pv)pv.addEventListener('click',function(){go(cur-1,true)});if(nx)nx.addEventListener('click',function(){go(cur+1,true)});
  st.addEventListener('pointerdown',function(e){if(e.pointerType==='mouse'&&e.button!==0)return;down=true;moved=false;sx=e.clientX;sy=e.clientY});
  st.addEventListener('pointermove',function(e){if(down&&Math.abs(e.clientX-sx)>10)moved=true});
  function up(e){if(!down)return;down=false;var dx=e.clientX-sx,dy=e.clientY-sy;if(Math.abs(dx)>40&&Math.abs(dx)>Math.abs(dy)*1.2){go(cur+(dx<0?1:-1),true);moved=true}}
  st.addEventListener('pointerup',up);st.addEventListener('pointercancel',function(){down=false});
  st.addEventListener('click',function(e){var p=e.target.closest('.ph');if(p&&!moved&&p.dataset.pos!=='0')go(phs.indexOf(p),true);moved=false});
  st.addEventListener('keydown',function(e){var p=e.target.closest('.ph');if(p&&(e.key==='Enter'||e.key===' ')&&p.dataset.pos!=='0'){e.preventDefault();go(phs.indexOf(p),true)}else if(e.key==='ArrowRight'){go(cur+1,true)}else if(e.key==='ArrowLeft'){go(cur-1,true)}});
  st.parentNode.addEventListener('keydown',function(e){if(e.target.closest('[data-hs]')){if(e.key==='ArrowRight')go(cur+1,true);if(e.key==='ArrowLeft')go(cur-1,true)}});
  if('IntersectionObserver' in window)new IntersectionObserver(function(es){visible=es[0].isIntersecting}).observe(st);
  auto();
})();

/* ── «Три вещи»: вкладки + одна карточка (круговое раскрытие, автопоказ, свайп) ── */
(function(){
  var sc=$('[data-showcase]');if(!sc)return;
  var tabs=$$('[role=tab]',sc),panels=$$('.world',sc),stage=$('.sc-stage',sc),N=tabs.length,cur=0,tm=0;
  sc.setAttribute('data-js','');
  panels.forEach(function(p,i){p.setAttribute('data-state',i?'off':'on')});
  function stopAuto(){sc.removeAttribute('data-auto')}
  function origin(k){var t=tabs[k].getBoundingClientRect(),r=stage.getBoundingClientRect();stage.style.setProperty('--ox',(t.left+t.width/2-r.left)+'px');stage.style.setProperty('--oy',(t.bottom-r.top)+'px')}
  function go(k,user){
    k=(k+N)%N;if(k===cur)return;
    panels.forEach(function(p,i){if(i!==cur&&i!==k)p.setAttribute('data-state','off')});
    panels[cur].setAttribute('data-state','prev');
    origin(k);stage.setAttribute('data-anim','');
    panels[k].setAttribute('data-state','on');
    tabs.forEach(function(t,i){t.setAttribute('aria-selected',i===k);t.tabIndex=i===k?0:-1});
    cur=k;clearTimeout(tm);tm=setTimeout(function(){panels.forEach(function(p,i){if(i!==cur)p.setAttribute('data-state','off')})},1100);
    if(user){stopAuto();buzz(8)}
  }
  tabs.forEach(function(t,i){
    t.addEventListener('click',function(){go(i,true)});
    t.addEventListener('keydown',function(e){var d=e.key==='ArrowRight'?1:e.key==='ArrowLeft'?-1:0;if(e.key==='Home')d=-cur;if(e.key==='End')d=N-1-cur;if(!d)return;e.preventDefault();go(cur+d,true);tabs[cur].focus()});
  });
  /* свайп по карточке (вертикальный скролл страницы не мешает) */
  var sx=0,sy=0,tr=false;
  stage.addEventListener('touchstart',function(e){var t=e.touches[0];sx=t.clientX;sy=t.clientY;tr=e.touches.length===1},{passive:true});
  stage.addEventListener('touchend',function(e){if(!tr)return;tr=false;var t=e.changedTouches[0],dx=t.clientX-sx,dy=t.clientY-sy;if(Math.abs(dx)>52&&Math.abs(dx)>Math.abs(dy)*1.4)go(cur+(dx<0?1:-1),true)},{passive:true});
  /* автопоказ: полоска прогресса на активной вкладке; любое действие — выключает */
  if(!reduce){
    sc.setAttribute('data-auto','');sc.setAttribute('data-pause','');
    sc.addEventListener('animationend',function(e){if(e.animationName==='scBar'&&sc.hasAttribute('data-auto'))go(cur+1)});
    sc.addEventListener('pointerdown',stopAuto);sc.addEventListener('keydown',stopAuto);
  }
  if('IntersectionObserver' in window){
    new IntersectionObserver(function(es){var v=es[0].isIntersecting;if(v)sc.setAttribute('data-in','');sc.toggleAttribute('data-pause',!v)},{threshold:.35}).observe(sc);
  }else{sc.setAttribute('data-in','');sc.removeAttribute('data-pause')}
})();

/* ── release: GitHub → latest version, what's new (tables, lists, code), history ── */
(function(){
  var root=$('#rel');if(!root)return;
  var REPO='eugggeneee/journal',API='https://api.github.com/repos/'+REPO+'/releases?per_page=6';
  function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;')}
  function inl(s){
    s=esc(s).replace(/!\[[^\]]*\]\([^)]*\)/g,'');
    s=s.replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+)\)/g,'<a href="$2" target="_blank" rel="noopener">$1</a>');
    s=s.replace(/(^|[\s(>])(https?:\/\/[^\s<)]+)/g,function(m,p,u){var pr=u.match(/github\.com\/[^/]+\/[^/]+\/(?:pull|issues)\/(\d+)/);var t=u.replace(/^https?:\/\/(www\.)?/,'');return p+'<a href="'+u+'" target="_blank" rel="noopener">'+(pr?'#'+pr[1]:(t.length>38?t.slice(0,36)+'…':t))+'</a>'});
    return s.replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>').replace(/`([^`]+)`/g,'<code>$1</code>');
  }
  function cells(l){l=l.trim().replace(/^\|/,'').replace(/\|$/,'');return l.split('|').map(function(c){return c.trim()})}
  var SEP=/^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$/;
  function blocks(md){
    var L=String(md||'').replace(/\r/g,'').replace(/<!--[\s\S]*?-->/g,'').split('\n'),out=[],i=0,cl=null;
    while(i<L.length){
      var l=L[i],t=l.trim(),m;
      if(!t||/^(-{3,}|\*{3,}|_{3,})$/.test(t)){i++;continue}
      if(/^```/.test(t)){var c=[];i++;while(i<L.length&&!/^\s*```/.test(L[i]))c.push(L[i++]);i++;out.push({t:'code',x:c.join('\n')});continue}
      if(t.charAt(0)==='|'&&i+1<L.length&&SEP.test(L[i+1])){var head=cells(t),rows=[];i+=2;while(i<L.length&&L[i].indexOf('|')>-1&&L[i].trim())rows.push(cells(L[i++]));out.push({t:'tbl',head:head,rows:rows});continue}
      if(m=t.match(/^(#{1,6})\s+(.*)$/)){out.push({t:'h',l:m[1].length,x:m[2].replace(/[*_`]/g,'').trim()});i++;continue}
      if(m=t.match(/full changelog\**:?\s*(https?:\/\/\S+)/i)){cl=m[1];i++;continue}
      if(/^([-*+]|\d+\.)\s+/.test(t)){var it=[];while(i<L.length&&(m=L[i].trim().match(/^(?:[-*+]|\d+\.)\s+(.*)$/))){it.push(m[1]);i++}out.push({t:'ul',items:it});continue}
      var p=[];while(i<L.length&&L[i].trim()&&!/^(```|#{1,6}\s|\||([-*+]|\d+\.)\s)/.test(L[i].trim()))p.push(L[i++].trim());
      if(!p.length){i++;continue}out.push({t:'p',x:p.join(' ').replace(/^>\s*/,'')});
    }
    if(cl)out.push({t:'cl',x:cl});return out;
  }
  var KH=[[/нов|feat|добав|added|what|улучш/i,'feat','star'],[/исправ|fix|баг|ошиб/i,'fix','check'],[/скача|download|установ|install/i,'dl','down'],[/провер|подлин|verify|sha|attest/i,'sec','lock']];
  function kh(t){for(var k=0;k<KH.length;k++)if(KH[k][0].test(t))return KH[k];return[0,'other','book']}
  var TYP={feat:'Новое',fix:'Исправлено',perf:'Улучшено'};
  function li(x){
    var t=x,pr=null,m=t.match(/\s+by\s+@([\w-]+)\s+in\s+(https?:\/\/\S*?\/pull\/(\d+))\s*$/);
    if(m){pr={n:m[3],u:m[2]};t=t.slice(0,m.index)}
    var ty=null,c=t.match(/^(feat|fix|perf|refactor|docs|chore|style|build|ci|test|revert|add|update|improve)(\([^)]*\))?!?:\s*(.+)$/i);
    if(c){var k=c[1].toLowerCase();ty=k==='feat'||k==='add'?'feat':k==='fix'?'fix':(k==='perf'||k==='improve'||k==='refactor'||k==='update')?'perf':null;t=c[3]}
    if(/^[а-яё]/.test(t))t=t.charAt(0).toUpperCase()+t.slice(1);
    return '<li>'+(ty?'<em class="ty ty-'+ty+'">'+TYP[ty]+'</em>':'')+'<span class="tx">'+inl(t)+'</span>'+(pr?'<a class="pr" href="'+esc(pr.u)+'" target="_blank" rel="noopener" aria-label="Pull request '+pr.n+'">#'+pr.n+'</a>':'')+'</li>';
  }
  function notesHtml(md,compact){
    var bl=blocks(md),h='',skip=false,det=false,first=true,any=false;
    function endDet(){if(det){h+='</div></details>';det=false}}
    bl.forEach(function(b){
      if(b.t==='h'){
        var isTitle=first&&b.l<=2&&/journal|v?\d+\.\d+/i.test(b.x);first=false;
        if(isTitle)return;
        endDet();var k=kh(b.x);skip=compact&&(k[1]==='dl'||k[1]==='sec');if(skip)return;
        if(/what.?s changed|что изменилось/i.test(b.x)&&b.l<=2)return;
        if(k[1]==='sec'){h+='<details class="rd"><summary><span class="rh k-sec"><svg class="i"><use href="#i-lock"/></svg>'+esc(b.x)+'</span>'+icon('plus')+'</summary><div class="rdb">';det=true;return}
        h+='<h4 class="rh k-'+k[1]+'"><svg class="i"><use href="#i-'+k[2]+'"/></svg>'+esc(b.x)+'</h4>';return;
      }
      first=false;if(skip)return;any=true;
      if(b.t==='p')h+='<p>'+inl(b.x)+'</p>';
      else if(b.t==='ul')h+='<ul class="rl">'+b.items.map(li).join('')+'</ul>';
      else if(b.t==='tbl')h+='<div class="tbl"><table><thead><tr>'+b.head.map(function(c){return '<th>'+inl(c)+'</th>'}).join('')+'</tr></thead><tbody>'+b.rows.map(function(r){return '<tr>'+b.head.map(function(_,j){return '<td data-l="'+esc(b.head[j].replace(/[*`]/g,''))+'">'+inl(r[j]||'')+'</td>'}).join('')+'</tr>'}).join('')+'</tbody></table></div>';
      else if(b.t==='code'){if(!compact)h+='<div class="code"><pre><code>'+esc(b.x)+'</code></pre><button type="button" class="cpy" data-copy aria-label="Скопировать">'+icon('copy')+'</button></div>'}
      else if(b.t==='cl'&&!compact)h+='<p class="cl"><a href="'+esc(b.x)+'" target="_blank" rel="noopener">Все изменения на GitHub →</a></p>';
    });
    endDet();
    return any?h:'<p>Описание релиза не добавлено.</p>';
  }
  var RTF=null,DTF=null;
  try{DTF=new Intl.DateTimeFormat('ru',{day:'numeric',month:'long',year:'numeric'});RTF=new Intl.RelativeTimeFormat('ru',{numeric:'auto'})}catch(e){}
  function dateTxt(iso){var d=new Date(iso);if(isNaN(d))return'';var s=(DTF?DTF.format(d):d.toLocaleDateString()).replace(/\s?г\.$/,'');var days=Math.round((d-Date.now())/864e5),rel='';if(RTF){rel=Math.abs(days)<30?RTF.format(days,'day'):Math.abs(days)<365?RTF.format(Math.round(days/30),'month'):''}return s+(rel?' · '+rel:'')}
  function mb(n){return n>=1048576?(n/1048576).toFixed(1).replace('.',',')+' МБ':Math.max(1,Math.round(n/1024))+' КБ'}
  function ver(r){return r.tag_name||r.name||''}
  function pick(r,re){var a=(r.assets||[]).filter(function(x){return re.test(x.name)});return a[0]||null}
  function render(list){
    list=(list||[]).filter(function(r){return !r.draft});
    if(!list.length){root.dataset.state='empty';return}
    var r=list[0],ipa=pick(r,/\.ipa$/i),apk=pick(r,/\.apk$/i)||pick(r,/\.aab$/i);
    $$('[data-dl="ios"]').forEach(function(a){a.href=ipa?ipa.browser_download_url:r.html_url});
    $$('[data-dl="android"]').forEach(function(a){a.href=apk?apk.browser_download_url:r.html_url});
    $$('[data-ver]').forEach(function(a){a.hidden=false;a.querySelector('b').textContent=ver(r)});
    $('#rel-ver').textContent=ver(r);$('#rel-pre').hidden=!r.prerelease;
    $('#rel-date').textContent=dateTxt(r.published_at||r.created_at);
    var nm=(r.name&&r.name!==r.tag_name)?r.name:'';$('#rel-name').textContent=nm;$('#rel-name').hidden=!nm;
    var as='';
    as+='<a class="store ios" href="'+esc(ipa?ipa.browser_download_url:r.html_url)+'" rel="noopener">'+icon('apple')+'<span><small>'+(ipa?'iPhone · '+mb(ipa.size):'Страница релиза')+'</small><strong>iOS</strong></span></a>';
    as+='<a class="store and" href="'+esc(apk?apk.browser_download_url:r.html_url)+'" rel="noopener">'+icon('android')+'<span><small>'+(apk?'Android · '+mb(apk.size):'Страница релиза')+'</small><strong>Android</strong></span></a>';
    (r.assets||[]).filter(function(x){return x!==ipa&&x!==apk&&!/\.(sha256|txt|json|sigstore|intoto)/i.test(x.name)}).slice(0,3).forEach(function(x){as+='<a class="afile" href="'+esc(x.browser_download_url)+'" rel="noopener">'+icon('down')+'<b>'+esc(x.name)+'</b><span>'+mb(x.size)+'</span></a>'});
    $('#rel-assets').innerHTML=as;$('#rel-gh').href=r.html_url;
    $('#rel-notes').innerHTML=notesHtml(r.body);
    var old=list.slice(1,5),hb=$('#rel-hist');
    if(old.length){hb.hidden=false;$('.faq',hb).innerHTML=old.map(function(x){return '<details><summary><span>'+esc(ver(x))+'<span class="meta">'+esc(dateTxt(x.published_at||x.created_at))+(x.prerelease?' · пре-релиз':'')+'</span></span>'+icon('plus')+'</summary><div class="a">'+notesHtml(x.body,true)+'</div></details>'}).join('');
      $$('.faq details',hb).forEach(function(d){d.addEventListener('toggle',function(){if(d.open)$$('.faq details',hb).forEach(function(o){if(o!==d)o.open=false})})})}
    else hb.hidden=true;
    root.dataset.state='ready';
  }
  function load(){
    root.dataset.state='loading';
    var c=null;try{c=JSON.parse(sessionStorage.getItem('journal-rel2')||'null')}catch(e){}
    if(c&&Date.now()-c.t<6e5){render(c.d);return}
    if(!window.fetch){root.dataset.state='error';return}
    var ctl=window.AbortController?new AbortController():null,to=setTimeout(function(){if(ctl)ctl.abort()},9000);
    fetch(API,{headers:{'Accept':'application/vnd.github+json'},signal:ctl?ctl.signal:undefined}).then(function(r){if(r.status===404)return [];if(!r.ok)throw new Error(r.status);return r.json()}).then(function(d){clearTimeout(to);try{sessionStorage.setItem('journal-rel2',JSON.stringify({t:Date.now(),d:d}))}catch(e){}render(d)}).catch(function(){clearTimeout(to);root.dataset.state='error'});
  }
  $$('[data-rel-retry]').forEach(function(b){b.addEventListener('click',load)});
  document.addEventListener('click',function(e){var b=e.target.closest('[data-copy]');if(!b)return;var t=b.parentNode.querySelector('code').textContent;
    var done=function(){b.dataset.ok='';setTimeout(function(){b.removeAttribute('data-ok')},1600);buzz(10)};
    if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(t).then(done,function(){});else{var ta=document.createElement('textarea');ta.value=t;ta.style.position='fixed';document.body.appendChild(ta);ta.select();try{document.execCommand('copy');done()}catch(x){}ta.remove()}});
  window.__journalRel={render:render};
  load();
})();

/* ── install: Android / iPhone ── */
(function(){
  var w=$('[data-install]');if(!w)return;
  var btns=$$('[data-os]',w),ps=$$('[data-os-panel]',w);
  function set(os){btns.forEach(function(b){b.setAttribute('aria-pressed',b.dataset.os===os)});ps.forEach(function(p){p.hidden=p.dataset.osPanel!==os})}
  btns.forEach(function(b){b.addEventListener('click',function(){set(b.dataset.os);buzz(8)})});
  if(/iPhone|iPad|iPod|Macintosh.*Mobile/i.test(navigator.userAgent||''))set('ios');
})();

/* ── bento: limit ring + undo ── */
(function(){
  var t=$('[data-limit]');
  if(t){
    var n=7,arc=$('#lim-arc',t),num=$('#lim-n',t),txt=$('#lim-txt',t),C=314.16;
    var draw=function(){
      arc.style.strokeDashoffset=C*(1-Math.min(n,10)/10);num.textContent=n;
      t.toggleAttribute('data-over',n>=10);
      txt.textContent=n>=10?'Лимит превышен: '+n+' ч без уважительной причины':n>=7?'Осталось '+(10-n)+' '+plural(10-n,['час','часа','часов'])+' до лимита':'Пока спокойно: счётчик включится с 7 часов';
    };
    t.addEventListener('click',function(e){var b=e.target.closest('[data-lim]');if(!b)return;n=Math.max(0,Math.min(12,n+(+b.dataset.lim)));draw();buzz(n>=10?20:8)});
    setTimeout(draw,60);
  }
  var ul=$('#undo-list'),sn=$('#undo-sn');
  if(ul&&sn){
    var last=null,tm=null;
    ul.addEventListener('click',function(e){var b=e.target.closest('li button');if(!b)return;if(last)last.hidden=true;last=b.parentNode;last.hidden=true;sn.setAttribute('data-open','');buzz(10);clearTimeout(tm);tm=setTimeout(function(){sn.removeAttribute('data-open');last=null},5000)});
    $('button',sn).addEventListener('click',function(){if(last){last.hidden=false;last=null}sn.removeAttribute('data-open');clearTimeout(tm);buzz(8)});
  }
})();

/* ── boot ── */
fillControls(document);
setTheme(S.theme);setHue(S.hue);syncControls();
$$('.switch[data-key]').forEach(function(b){b.setAttribute('aria-checked',!!S[b.dataset.key])});
})();
