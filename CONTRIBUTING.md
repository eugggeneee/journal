# Участие в проекте

## Перед началом

1. Прочитать [AGENTS.md](AGENTS.md) и все документы из его таблицы: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/STYLE.md](docs/STYLE.md), [docs/COMMITS.md](docs/COMMITS.md), [docs/VERSIONING.md](docs/VERSIONING.md), [docs/TESTING.md](docs/TESTING.md).
2. Подготовить окружение: команды в [README.md](README.md#разработка).

## Порядок работы

1. Создать ветку от `main`: `feat/короткое-имя`, `fix/короткое-имя`, `docs/короткое-имя`.
2. Внести изменение; логика идёт вместе с тестами ([docs/TESTING.md](docs/TESTING.md)).
3. Если изменение затрагивает то, что показано на сайте, обновить `site/` в том же коммите (`docs/SITE.md`).
4. Добавить строку в `CHANGELOG.md`, раздел `[Не выпущено]`, если меняется поведение для пользователя.
5. Выполнить проверки:
   ```bash
   python3 scripts/project/check.py
   flutter analyze
   flutter test
   ```
6. Закоммитить по [docs/COMMITS.md](docs/COMMITS.md) и открыть pull request.

## Правила

- Один pull request, одна задача.
- Версию вручную меняют только релизным коммитом и пред-релизом ([docs/VERSIONING.md](docs/VERSIONING.md)).
- Формат коммитов и заголовок pull request совпадают: [docs/COMMITS.md](docs/COMMITS.md).
- Нельзя добавлять: эмодзи, секреты, ключи, платформенные папки, сборочные артефакты.
- Уязвимости не обсуждаются в issues: [SECURITY.md](SECURITY.md).

## Выпуск

Только владелец проекта: [docs/RELEASING.md](docs/RELEASING.md), тестовые версии: [docs/PRERELEASES.md](docs/PRERELEASES.md).
