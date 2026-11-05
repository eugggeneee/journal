# Выпуск релиза

Релиз автоматический: тег запускает `.github/workflows/release.yml`. Workflow проверяет тег и репозиторий, прогоняет анализ и тесты, собирает Android и iOS, подписывает APK, считает контрольные суммы, создаёт аттестацию и публикует релиз.

Тестовые версии: [PRERELEASES.md](PRERELEASES.md). Нумерация: [VERSIONING.md](VERSIONING.md).

## Однократная настройка

### Идентификатор приложения

`eugggeneee.journal`: переменная `APP_ORG: eugggeneee` в `ci.yml` и `release.yml`, имя проекта `journal`. После первого публичного релиза не менять: Android воспримет это как другое приложение.

### Ключ подписи Android

APK всегда подписывается одним ключом, иначе обновление поверх установленной версии невозможно. Настроить ключ нужно до первого тега.

Вариант 1, через GitHub:
1. Создать fine-grained token: доступ только к репозиторию, право Secrets: Read and write, срок 7 дней.
2. Добавить его секретом `SETUP_PAT`.
3. Запустить Actions, «Создать ключ подписи Android», Run workflow. Появятся секреты `ANDROID_KEYSTORE_*`.
4. Удалить секрет `SETUP_PAT` и токен.

Вариант 2, локально:

```bash
bash scripts/release/make-keystore.sh --gh
```

Без флага `--gh` скрипт печатает значения для ручного добавления.

| Секрет | Содержимое |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | файл ключа в base64 |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_ALIAS` | псевдоним (`journal`) |
| `ANDROID_KEY_PASSWORD` | пароль ключа |

Файл ключа и пароль хранить в менеджере паролей с резервной копией. Потеря ключа означает невозможность обновлений. Ключ в репозиторий не коммитится (`.gitignore`).

Без секретов релиз соберётся, но APK получит отладочный ключ и не обновится релизным.

## Порядок выпуска стабильной версии

1. Убедиться, что `main` зелёный: CI проходит.
2. Определить номер по [VERSIONING.md](VERSIONING.md) и поднять версию:
   ```bash
   python3 scripts/project/version.py bump patch    # или minor / major
   ```
3. В `CHANGELOG.md` переименовать раздел `[Не выпущено]` в `[X.Y.Z] - ГГГГ-ММ-ДД` и добавить новый пустой `[Не выпущено]`.
4. Создать `.github/releases/vX.Y.Z.md`: строки вида `- что изменилось`, без заголовков и эмодзи, только факты для пользователя.
5. Выполнить проверки:
   ```bash
   python3 scripts/project/graph.py
   python3 scripts/project/check.py
   flutter analyze
   flutter test
   ```
6. Закоммитить: `chore(release): X.Y.Z`.
7. Поставить тег и отправить:
   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```
8. Дождаться workflow Release (10-15 минут), открыть релиз и проверить файлы: `Journal-vX.Y.Z-android.apk`, `Journal-vX.Y.Z-ios.ipa`, `SHA256SUMS.txt`.
9. Установить APK на устройство и проверить запуск, расписание, добавление оценки и пропуска.

Workflow можно запустить вручную: Actions, Release, Run workflow, указать тег.

## Описание релиза

Берётся по порядку:
1. `.github/releases/<тег>.md`, если файл есть;
2. иначе заголовки коммитов между предыдущим тегом и новым.

Для стабильных версий файл обязателен (проверяется `check.py`). Шаблон оформления: `.github/release-notes.md`.

## Проверка файлов

```bash
sha256sum -c SHA256SUMS.txt
gh attestation verify Journal-vX.Y.Z-android.apk --repo eugggeneee/journal
```

## iOS

Сборка без подписи Apple, платный аккаунт разработчика не нужен. Подпись ставят AltStore или Sideloadly при установке. App Store и TestFlight таким способом недоступны.

## Если релиз содержит ошибку

- Опубликованный тег не удалять и не перемещать.
- Выпустить следующую версию (PATCH, при `X.Y.20` MINOR) с исправлением.
- Ошибочный релиз пометить в GitHub как pre-release или удалить файлы из релиза, оставив тег.

## Название и значки

- Название приложения на устройстве: Journal (задаётся в workflow).
- Исходники значка: `assets/icon/`, готовые значки тем: `assets/icons/` (генерируются `scripts/icons/make_icons.py`).
