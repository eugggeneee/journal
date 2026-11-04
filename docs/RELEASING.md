# Сборка и выпуск версий

## Локальная сборка

Папки `android/` и `ios/` в репозитории не хранятся — их создаёт команда `flutter create` (так же делает CI):

```bash
flutter create --platforms=android,ios --org by.mgtek --project-name journal .
flutter pub get
flutter test
flutter run
```

## Как выпустить версию

Релиз полностью автоматический: вы ставите тег — GitHub Actions проверяет код, собирает **Journal** для Android и iPhone,
подписывает сборки и публикует их во вкладке **Releases** вместе с описанием и контрольными суммами.

## 1. Один раз: ключ подписи Android

### Вариант А — автоматически (без терминала)

GitHub не позволяет workflow самому писать секреты встроенным токеном, поэтому нужен временный токен:

1. На github.com: аватар → **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
   - **Repository access:** *Only select repositories* → ваш репозиторий `journal`
   - **Permissions → Repository permissions → Secrets:** *Read and write* (Metadata подставится сам)
   - **Expiration:** 7 дней достаточно → **Generate token** → скопируйте токен.
2. В репозитории: **Settings → Secrets and variables → Actions → New repository secret** → имя `SETUP_PAT`, значение — токен.
3. **Actions → «Создать ключ подписи Android» → Run workflow.** Через минуту в Secrets появятся четыре `ANDROID_KEYSTORE_*`.
4. Удалите секрет `SETUP_PAT` и сам токен в настройках аккаунта — он больше не нужен.

Ключ лежит только в секретах GitHub, достать его оттуда нельзя. Если репозиторий удалят, ключ пропадёт — это обычная цена за удобство.
Повторный запуск workflow без галочки «Перезаписать» ничего не сломает — он остановится.

### Вариант Б — вручную (скрипт)

APK должен быть подписан одним и тем же ключом всегда — иначе Android не даст обновить приложение поверх старого.

```bash
bash scripts/make-keystore.sh --gh
```

Скрипт создаст ключ в `~/journal-signing/` и (с флагом `--gh`, нужен [GitHub CLI](https://cli.github.com)) сам запишет четыре секрета в репозиторий.
Без `gh` он напечатает значения — добавьте их вручную: **Settings → Secrets and variables → Actions → New repository secret**.

| Секрет | Что это |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | файл ключа в base64 (`~/journal-signing/keystore.base64`) |
| `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
| `ANDROID_KEY_ALIAS` | псевдоним ключа (`journal`) |
| `ANDROID_KEY_PASSWORD` | пароль ключа |

> ⚠️ Сохраните `journal-release.jks` и пароль в менеджере паролей и сделайте копию. Потеряете — обновления станут невозможны.
> Файл ключа нельзя коммитить (он уже в `.gitignore`).

Если секреты не заданы, релиз всё равно соберётся, но APK будет подписан **тестовым** ключом — позже его не получится обновить релизным.
Поэтому настройте секреты **до первого тега**.

## 2. Выпуск версии

```bash
git checkout main && git pull
git tag v1.0.0
git push origin v1.0.0
```

Через ~10–15 минут во вкладке **Releases** появится релиз `Journal v1.0.0` с файлами:

- `Journal-v1.0.0-android.apk` — подписан релизным ключом;
- `Journal-v1.0.0-ios.ipa` — без подписи Apple (для AltStore / Sideloadly);
- `SHA256SUMS.txt` — контрольные суммы.

Описание релиза собирается из сообщений коммитов с прошлого тега, шаблон — `.github/release-notes.md`.
Теги вида `v1.1.0-beta.1` публикуются как *pre-release*.

Можно запустить и вручную: **Actions → Release → Run workflow** и указать тег.

## 3. Номера версий

- Имя версии берётся из тега (`v1.2.3` → `1.2.3`).
- Номер сборки (`versionCode`) — номер запуска workflow, он всегда растёт.
- Строку `version:` в `pubspec.yaml` для релиза менять не нужно.

## 4. Проверка скачанного файла

```bash
sha256sum -c SHA256SUMS.txt                                   # контрольные суммы
gh attestation verify Journal-v1.0.0-android.apk --repo <владелец>/<репозиторий>   # подпись GitHub
```

## 5. Про iPhone

Сборка iOS идёт **без подписи Apple** — платный аккаунт разработчика для этого не нужен.
Подпись ставит AltStore / Sideloadly при установке. App Store и TestFlight таким способом недоступны.

## 6. Настройки

- Идентификатор приложения: `APP_ORG` в `.github/workflows/*.yml` (сейчас `by.mgtek` → `by.mgtek.journal`).
  Если меняете после первого релиза, Android воспримет это как другое приложение.
- Название на экране телефона — **Journal** (задаётся в workflow для Android и iOS).
- Иконки: исходник `docs/images/branding/icon.svg`, готовые файлы — `assets/icon/`.

## Описание релиза

Раздел «Что нового» в релизе берётся так:

1. если есть файл `.github/releases/<тег>.md` (например, `.github/releases/v1.3.0.md`) — из него (список строк вида `- что изменилось`);
2. иначе — из заголовков коммитов между прошлым тегом и новым.

Поэтому перед тегом достаточно положить такой файл в репозиторий вместе с коммитом. Название релиза — `Journal <тег>`.
