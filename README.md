<div align="center">

<img src="docs/images/readme/hero.svg" alt="Journal: МГТЭК, Дневник. Расписание, оценки и пропуски в одном месте" width="100%">

<br>

<a href="https://github.com/eugggeneee/journal/releases/latest"><img src="docs/images/readme/btn-android.svg" width="215" alt="Скачать для Android"></a>
&nbsp;
<a href="https://github.com/eugggeneee/journal/releases/latest"><img src="docs/images/readme/btn-iphone.svg" width="215" alt="Скачать для iPhone"></a>

<br><br>

<a href="https://github.com/eugggeneee/journal/releases/latest"><img alt="Релиз" src="https://img.shields.io/github/v/release/eugggeneee/journal?style=flat-square&labelColor=1E1F25&color=BEC3FF"></a>
<a href="https://github.com/eugggeneee/journal/actions/workflows/ci.yml"><img alt="CI" src="https://img.shields.io/github/actions/workflow/status/eugggeneee/journal/ci.yml?branch=main&style=flat-square&labelColor=1E1F25&label=CI"></a>
<a href="LICENSE"><img alt="Лицензия MIT" src="https://img.shields.io/badge/лицензия-MIT-E9B9DA?style=flat-square&labelColor=1E1F25"></a>
<img alt="Material 3" src="https://img.shields.io/badge/Material-3-2F40AE?style=flat-square&labelColor=1E1F25">
<img alt="Android и iOS" src="https://img.shields.io/badge/Android%20%7C%20iOS-Flutter-9EF8A3?style=flat-square&labelColor=1E1F25">

</div>

Дневник студента МГТЭК: расписание группы, оценки и пропуски. Android и iOS. Бесплатно, без рекламы, без аккаунтов, работает офлайн. Лицензия MIT.

> [!NOTE]
> Неофициальное приложение. Расписание берётся с общедоступной страницы сайта колледжа и может отличаться от актуального.

<p align="center">
  <img src="docs/images/readme/screens.png" width="420" alt="Экраны приложения: стартовый экран с тремя главными возможностями и расписание на неделю">
</p>

<p align="center"><img src="docs/images/readme/section-features.svg" width="100%" alt="Возможности"></p>

### Расписание

- Пары группы на любую дату; загруженные дни доступны без интернета.
- Время пар: готовые расписания колледжа или ручной ввод (пары 1-7, суббота отдельно). В карточке пары показаны начало, конец, перерыв внутри пары и обед.
- Пометки ОКР, Зачёт, Практика, Сокращённый день или своя: на пару или на весь день, на любую дату.

### Оценки

- Шкала 1-10, предмет из расписания дня, тип работы и заметка.
- Средний балл, распределение, динамика по предметам.

### Пропуски

- Отметка у пары одним касанием или на весь день; 1 или 2 часа; уважительная причина.
- Лимиты без уважительной причины: 10 часов в месяц и 72 часа в семестр, предупреждения с 7 и 62 часов.

### Прочее

- Отмена любого действия, резервная копия через буфер обмена, виброотклик.
- Светлая и тёмная темы, смена значка приложения под тему на Android и iOS.

<p align="center"><img src="docs/images/readme/section-themes.svg" width="100%" alt="Темы"></p>

<p align="center">
  <img src="docs/images/readme/themes.png" width="100%" alt="20 значков приложения в цветах тем: стандартная, чёрно-белая и основные цвета Material Design">
</p>

Material 3, светлая и тёмная темы, 20 цветовых тем, цвета обоев на Android 12+.

<p align="center"><img src="docs/images/readme/section-install.svg" width="100%" alt="Установка"></p>

Файлы лежат в [Releases](https://github.com/eugggeneee/journal/releases/latest).

| Платформа | Файл | Как установить |
|---|---|---|
| Android | `Journal-vX.Y.Z-android.apk` | Открыть файл, разрешить установку из этого источника |
| iPhone, iPad | `Journal-vX.Y.Z-ios.ipa` | Установить через [AltStore](https://altstore.io) или [Sideloadly](https://sideloadly.io) |

> [!IMPORTANT]
> Сборка для iOS не подписана Apple. С бесплатным Apple ID её нужно переподписывать раз в 7 дней; AltStore делает это автоматически.

<details>
<summary>Проверка файла</summary>

```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify Journal-vX.Y.Z-android.apk --repo eugggeneee/journal
```

</details>

<p align="center"><img src="docs/images/readme/section-privacy.svg" width="100%" alt="Конфиденциальность"></p>

<p align="center">
  <img src="docs/images/readme/privacy.svg" width="100%" alt="Единственный сетевой запрос: загрузка расписания с сайта колледжа. Оценки, пропуски и настройки хранятся только на устройстве. Нет аккаунтов, рекламы и аналитики.">
</p>

- Оценки, пропуски и настройки хранятся только на устройстве.
- Единственный сетевой запрос: загрузка расписания с сайта колледжа.
- Нет аккаунтов, рекламы и аналитики.

<p align="center"><img src="docs/images/readme/section-faq.svg" width="100%" alt="Вопросы и ответы"></p>

<details>
<summary>Нужен ли интернет?</summary>

Только для загрузки расписания. Уже загруженные дни, оценки и пропуски доступны без сети.

</details>

<details>
<summary>Почему расписание может отличаться от актуального?</summary>

Приложение читает общедоступную страницу сайта колледжа и не является официальным. Если колледж изменил страницу или расписание после загрузки, данные в приложении устареют.

</details>

<details>
<summary>Почему на iPhone приложение нужно переподписывать?</summary>

Сборка для iOS не подписана Apple, а бесплатный Apple ID даёт подпись на 7 дней. AltStore продлевает её автоматически.

</details>

<details>
<summary>Как не потерять данные при смене телефона?</summary>

Данные хранятся только на устройстве, поэтому перед переездом сделайте резервную копию через буфер обмена.

</details>

<p align="center"><img src="docs/images/readme/section-dev.svg" width="100%" alt="Разработка"></p>

Требования: Flutter 3.47 или новее, Python 3.10 или новее (скрипты проекта).

```bash
flutter create --platforms=android,ios --org eugggeneee --project-name journal .
flutter pub get
flutter analyze
flutter test
python3 scripts/project/check.py
flutter run
```

Папки `android/` и `ios/` не хранятся в репозитории: их создаёт `flutter create`. Идентификатор приложения: `eugggeneee.journal`.

Перед коммитом выполните `python3 scripts/project/check.py` и, если менялись файлы в `lib/` или `test/`, `python3 scripts/project/graph.py`.

Графика README собирается скриптом `python3 scripts/readme/make_assets.py` (флаг `--raster` добавляет `themes.png` и `social-preview.png`).

<p align="center"><img src="docs/images/readme/section-docs.svg" width="100%" alt="Документация"></p>

| Документ | Содержание |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Порядок работы и проверки перед коммитом |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Структура проекта, слои, данные |
| [docs/GRAPH.md](docs/GRAPH.md) | Граф зависимостей (генерируется) |
| [docs/STYLE.md](docs/STYLE.md) | Правила кода и интерфейса |
| [docs/COMMITS.md](docs/COMMITS.md) | Формат коммитов |
| [docs/VERSIONING.md](docs/VERSIONING.md) | Нумерация версий |
| [docs/RELEASING.md](docs/RELEASING.md) | Выпуск релиза и ключ подписи |
| [docs/PRERELEASES.md](docs/PRERELEASES.md) | Тестовые версии |
| [docs/TESTING.md](docs/TESTING.md) | Автоматические и ручные проверки |
| [SECURITY.md](SECURITY.md) | Сообщения об уязвимостях |
| [CHANGELOG.md](CHANGELOG.md) | История изменений |

<p align="center"><sub>Лицензия <a href="LICENSE">MIT</a></sub></p>
