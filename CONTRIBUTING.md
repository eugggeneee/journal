# Участие в проекте

## Перед началом

1. Прочитать документы: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/STYLE.md](docs/STYLE.md), [docs/COMMITS.md](docs/COMMITS.md), [docs/VERSIONING.md](docs/VERSIONING.md), [docs/TESTING.md](docs/TESTING.md).
2. Подготовить окружение: команды в [README.md](README.md#разработка).

## Порядок работы

1. Создать ветку от `main`: `feat/короткое-имя`, `fix/короткое-имя`, `docs/короткое-имя`.
2. Внести изменение; логику в `lib/logic` и `lib/data` менять вместе с тестами, исправление ошибки начинать с теста ([docs/TESTING.md](docs/TESTING.md)).
3. Добавить строку в `CHANGELOG.md`, раздел `[Не выпущено]`, если меняется поведение для пользователя.
4. Общие элементы интерфейса добавлять в `lib/ui/kit`; длительности и кривые брать из `Motion`, цвета из темы.
5. Изменилась структура папок, правила или команды: обновить `docs/ARCHITECTURE.md` и связанные документы в том же коммите.
6. Убрать лишнее: неиспользуемые файлы, закомментированный код, TODO, `__pycache__`, `.idea`, `.dart_tool`, `build`, `pubspec.lock`, `.metadata`, `*.iml`.
7. Выполнить проверки после каждого изменения:
   ```bash
   python3 scripts/project/check.py
   flutter analyze
   flutter test
   ```
8. Закоммитить по [docs/COMMITS.md](docs/COMMITS.md) и открыть pull request.

## Правила

- Один pull request, одна задача; один коммит, одно логическое изменение.
- Версию вручную меняют только релизным коммитом и пред-релизом ([docs/VERSIONING.md](docs/VERSIONING.md)).
- Формат коммитов и заголовок pull request совпадают: [docs/COMMITS.md](docs/COMMITS.md).
- Нельзя добавлять: эмодзи, секреты, ключи, платформенные папки (`android/`, `ios/`), сборочные артефакты.
- Нельзя обходить проверки и правила слоёв, переписывать опубликованную историю `main` и перемещать теги.
- Уязвимости не обсуждаются в issues: [SECURITY.md](SECURITY.md).

## Выпуск

Только владелец проекта: [docs/RELEASING.md](docs/RELEASING.md), тестовые версии: [docs/PRERELEASES.md](docs/PRERELEASES.md).
