<div align="center">

<img src="docs/logo.png" width="112" alt="Journal">

# Journal

Дневник студента МГТЭК: расписание, оценки, пропуски и задания.<br>
Android и iOS. Без рекламы и аккаунтов, работает офлайн.

[![Релиз](https://img.shields.io/github/v/release/eugggeneee/journal?include_prereleases&style=flat-square&labelColor=1E1F25&color=BEC3FF)](https://github.com/eugggeneee/journal/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/eugggeneee/journal/ci.yml?branch=main&style=flat-square&labelColor=1E1F25&label=CI)](https://github.com/eugggeneee/journal/actions/workflows/ci.yml)
[![Лицензия](https://img.shields.io/badge/лицензия-MIT-E9B9DA?style=flat-square&labelColor=1E1F25)](LICENSE)

</div>

> [!NOTE]
> Неофициальное приложение. Расписание берётся с общедоступной страницы сайта колледжа и может отличаться от актуального.

## Возможности

- **Главная.** Крупный отсчёт до следующего звонка, ход дня с текущим временем, ближайшая пара и быстрые переходы к оценкам, пропускам и заданиям. Блоки можно скрывать и переставлять.
- **Расписание.** Часовая шкала дня с перерывами и текущей парой. На карточке видны предметы подгрупп, кабинеты, преподаватели, пометки, пропуск, задания и сроки. На широком экране доступна сетка недели. Загруженные дни открываются без интернета.
- **Оценки.** Шкала 1-10, предмет, тип работы, заметка. Средний балл и динамика по предметам, цель по предмету и прогноз: сколько нужно получить, чтобы дотянуть.
- **Пропуски.** Отметка у пары или на весь день, уважительная причина, лимиты 10 часов в месяц и 72 часа в семестр с предупреждениями заранее, календарь месяца с тепловой картой.
- **Задания.** Домашнее задание и заметки к парам со сроком, отметка «сделано», напоминание на главной.
- **Оформление.** Material 3, светлая и тёмная темы, 20 цветовых тем со своим значком, цвета обоев на Android 12+, настраиваемые анимации.
- **Данные.** Отмена любого действия, резервная копия в файл .json или через буфер обмена.

## Установка

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

## Конфиденциальность

- Оценки, пропуски и настройки хранятся только на устройстве.
- Единственный сетевой запрос: загрузка расписания с сайта колледжа.
- Нет аккаунтов, рекламы и аналитики.

## Вопросы

<details>
<summary>Нужен ли интернет?</summary>

Только для загрузки расписания. Уже загруженные дни, оценки и пропуски доступны без сети.

</details>

<details>
<summary>Почему расписание может отличаться от актуального?</summary>

Приложение читает общедоступную страницу сайта колледжа и не является официальным. Если колледж изменил расписание после загрузки, данные в приложении устареют.

</details>

<details>
<summary>Почему на iPhone приложение нужно переподписывать?</summary>

Бесплатный Apple ID даёт подпись на 7 дней. AltStore продлевает её автоматически.

</details>

<details>
<summary>Как не потерять данные при смене телефона?</summary>

Перед переездом сделайте резервную копию через буфер обмена: данные хранятся только на устройстве.

</details>

## Разработка

Нужны Flutter 3.47 или новее и Python 3.10 или новее.

```bash
flutter create --platforms=android,ios --org eugggeneee --project-name journal .
flutter pub get
flutter analyze
flutter test
python3 scripts/project/check.py
flutter run
```

Папки `android/` и `ios/` не хранятся в репозитории: их создаёт `flutter create`. Идентификатор приложения: `eugggeneee.journal`. Перед коммитом выполните `python3 scripts/project/check.py`.

| Документ | Содержание |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Порядок работы и проверки перед коммитом |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Структура проекта, слои, данные |
| [docs/STYLE.md](docs/STYLE.md) | Правила кода и интерфейса |
| [docs/COMMITS.md](docs/COMMITS.md) | Формат коммитов |
| [docs/VERSIONING.md](docs/VERSIONING.md) | Нумерация версий |
| [docs/RELEASING.md](docs/RELEASING.md) | Выпуск релиза и ключ подписи |
| [docs/PRERELEASES.md](docs/PRERELEASES.md) | Тестовые версии |
| [docs/TESTING.md](docs/TESTING.md) | Автоматические и ручные проверки |
| [SECURITY.md](SECURITY.md) | Сообщения об уязвимостях |
| [CHANGELOG.md](CHANGELOG.md) | История изменений |

<div align="center"><sub>Лицензия <a href="LICENSE">MIT</a></sub></div>
