# Journal — лендинг

Статический лендинг для приложения **Journal** (МГТЭК · Дневник). Без сборки и зависимостей — чистый HTML/CSS/JS.

## Структура

```
index.html       — переключатель версий (телефон → mobile/, компьютер → desktop/)
desktop/         — версия для компьютера
mobile/          — версия для телефона
assets/          — мокапы, иконки, og-картинка
404.html, .nojekyll, robots.txt
```

Принудительно открыть нужную версию: `?view=desktop` или `?view=mobile`
(выбор запоминается; ссылки «Версия для…» есть в подвалах обеих страниц).

## Публикация на GitHub Pages

**Вариант 1 — папка `docs/` (проще всего)**
1. Скопируйте всё содержимое архива в папку `docs/` репозитория `eugggeneee/journal`.
2. Settings → Pages → Source: *Deploy from a branch* → Branch: `main`, папка `/docs` → Save.
3. Через минуту сайт откроется на `https://eugggeneee.github.io/journal/`.

**Вариант 2 — отдельная ветка `gh-pages`**
1. Создайте ветку `gh-pages` и положите содержимое архива в её корень.
2. Settings → Pages → Branch: `gh-pages`, папка `/ (root)`.

## Что поправить под себя

- Кнопки «Скачать для iOS / Android» ведут на `https://github.com/eugggeneee/journal/releases/latest`.
  Если появятся прямые ссылки (TestFlight, APK) — замените `href` у `.store` в `desktop/index.html` и `mobile/index.html`.
- Адрес в `og:image` и `canonical` рассчитан на `https://eugggeneee.github.io/journal/`.
  Если домен другой — замените в трёх `index.html`.
- Шрифты Unbounded и Onest подгружаются с Google Fonts; без сети используются системные.
