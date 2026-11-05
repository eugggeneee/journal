# Участие в проекте

## Перед началом

1. Прочитать [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) и [docs/STYLE.md](docs/STYLE.md).
2. Подготовить окружение: команды в [README.md](README.md#разработка).

## Порядок работы

1. Создать ветку от `main`: `feat/короткое-имя`, `fix/короткое-имя`, `docs/короткое-имя`.
2. Внести изменение; логика идёт вместе с тестами ([docs/TESTING.md](docs/TESTING.md)).
3. Обновить граф проекта, если менялись файлы в `lib/`, `test/` или импорты:
   ```bash
   python3 scripts/project/graph.py
   ```
4. Добавить строку в `CHANGELOG.md`, раздел `[Не выпущено]`, если меняется поведение для пользователя.
5. Выполнить проверки:
   ```bash
   python3 scripts/project/check.py
   flutter analyze
   flutter test
   ```
6. Закоммитить по [docs/COMMITS.md](docs/COMMITS.md) и открыть pull request.

## Граф проекта

`docs/GRAPH.md` описывает файлы и зависимости проекта и всегда должен соответствовать коду. Он обновляется после любого действия, которое меняет состав или связи файлов Dart: создание, удаление, перенос, переименование, добавление или удаление импортов, добавление тестов. Это делается командой `python3 scripts/project/graph.py`, а файл коммитится вместе с изменением. CI отклоняет изменения с устаревшим графом.

## Правила

- Один pull request, одна задача.
- Версию вручную меняют только релизным коммитом и пред-релизом ([docs/VERSIONING.md](docs/VERSIONING.md)).
- Формат коммитов и заголовок pull request совпадают: [docs/COMMITS.md](docs/COMMITS.md).
- Нельзя добавлять: эмодзи, секреты, ключи, платформенные папки, сборочные артефакты.
- Уязвимости не обсуждаются в issues: [SECURITY.md](SECURITY.md).

## Выпуск

Только владелец проекта: [docs/RELEASING.md](docs/RELEASING.md), тестовые версии: [docs/PRERELEASES.md](docs/PRERELEASES.md).
