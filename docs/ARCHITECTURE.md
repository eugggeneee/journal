# Архитектура

Приложение на Flutter, интерфейс на Material 3 (пакет `material_ui`). Состояние в одном `ChangeNotifier`, данные локальные. Платформенные папки `android/` и `ios/` не хранятся: их создаёт `flutter create` (локально и в CI).

Граф зависимостей: [GRAPH.md](GRAPH.md) (генерируется).

## Структура

```
journal/
  .github/
    workflows/          ci.yml, release.yml, setup-signing.yml
    releases/           vX.Y.Z.md: текст релиза стабильной версии
    ISSUE_TEMPLATE/     шаблоны issue
    release-notes.md    шаблон оформления релиза
    dependabot.yml, PULL_REQUEST_TEMPLATE.md
  assets/
    icon/               исходники значка
    icons/              значки по темам (генерируются scripts/icons/make_icons.py)
  docs/
    images/branding/    изображения для README
    ARCHITECTURE.md, COMMITS.md, PRERELEASES.md, RELEASING.md,
    STYLE.md, TESTING.md, VERSIONING.md, GRAPH.md
  lib/
    core/               даты, вибро, палитра тем, смена значка
    data/               models.dart (модели), store.dart (хранилище)
    logic/              чистая логика без Flutter-виджетов
      schedule/         загрузка и разбор расписания с сайта колледжа
    ui/
      app/              оболочка с вкладками, доступ к хранилищу (scope)
      theme/            тема Material 3
      kit/              общие элементы интерфейса
        foundation/     расширения контекста, цвета оценок и статусов
        animation/      единые длительности и кривые, появление элементов
        components/     карточки, итоговые блоки, пустые состояния, уведомления
        inputs/         выбор даты, предмета, оценки, переключатели
        sheets/         нижние шторки и диалоги
      schedule/ grades/ absences/ profile/ settings/ onboarding/   экраны
  scripts/
    icons/              генерация и подключение значков тем
    project/            check.py, graph.py, version.py
    release/            make-keystore.sh
  test/
    data/ logic/ project/ fixtures/
  CHANGELOG.md, CONTRIBUTING.md, AGENTS.md, SECURITY.md, README.md, LICENSE
```

## Слои и правила зависимостей

Направление: `ui` -> `logic` и `data` -> `core`. Папки `data` и `logic` могут импортировать друг друга; `core` не знает об остальных слоях.

| Слой | Может импортировать | Не может |
|---|---|---|
| `core` | только внешние пакеты | `data`, `logic`, `ui` |
| `data` | `core`, `logic` | `ui` |
| `logic` | `core`, `data` | `ui` |
| `ui/kit` | `core`, `data`, `logic`, `ui/app`, `ui/theme` | экраны (`schedule`, `grades`, `absences`, `profile`, `settings`, `onboarding`) |
| экраны | всё, кроме `test` | |
| `lib` | | `test` |

Правила проверяет `scripts/project/graph.py --check` (входит в `check.py` и CI).

## Данные

- Всё хранится локально в `shared_preferences`: данные пользователя (`data_v1`) и кэш расписания (`sched_v1`, не более 400 дней).
- Резервная копия: JSON с полем `app: journal` и версией формата `version` (сейчас 2); импорт принимает только такие копии.
- Лимиты считаются только по часам без уважительной причины: месяц календарный (с 1-го числа счётчик заново); семестр с 1 сентября до кнопки «Завершить 1-й семестр», затем до 1 августа.
- Звонки: два профиля, `week` и `sat`. Внутри пары возможен перерыв (две половины). Обед после пары задаётся номером пары.
- Пометка (`DayMark`): `lesson == 0` на весь день, иначе номер пары; одна на пару в день.
- Пропуск (`Absence`): одна запись на пару в день; повторное добавление заменяет прежнюю.
- Любая операция с оценками и пропусками отменяема: снимок дня (`snapshotDay`, `restoreDay`) или сохранение прежней записи.

## Расписание

`ScheduleService` загружает страницу `https://bseumtc.by/schedule/public/rasp/PODNAM%20ДД_ММ.htm`, `schedule_parser.dart` разбирает кодировку cp1251 и таблицу группы. `ScheduleRepo` кэширует дни и догружает ближайшие при запуске и возвращении в приложение. Единственный сетевой запрос приложения.

## Интерфейс

- Страницы «Оценки» и «Пропуски» построены на одних компонентах `ui/kit/components/overview.dart`: итоговая карточка, переключатель «Предметы / Журнал», фильтр, карточка предмета, строка журнала.
- Анимации берут длительности и кривые из `ui/kit/animation/motion.dart`.
- Цвета оценок, пропусков и лимитов: `ui/kit/foundation/ctx.dart`.

## Платформенная часть

Смена значка: канал `eugggeneee.journal/app_icon`. Нативный код добавляют после `flutter create` скрипты `scripts/icons/setup_android.py` и `scripts/icons/setup_ios.py`; без них приложение работает с обычным значком.
