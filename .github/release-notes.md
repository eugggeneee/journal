## Journal {{TAG}}

МГТЭК · Дневник: расписание, оценки и пропуски. Android и iOS.

### Скачать

| Платформа | Файл | Установка |
|---|---|---|
| Android | `Journal-{{TAG}}-android.apk` | Открыть файл и разрешить установку из этого источника |
| iPhone, iPad | `Journal-{{TAG}}-ios.ipa` | Установить через [AltStore](https://altstore.io) или [Sideloadly](https://sideloadly.io) |

- Android-сборка {{ANDROID_SIGNING}}.
- iOS-сборка не подписана Apple: подпись ставит AltStore или Sideloadly при установке.

### Что нового

{{CHANGES}}

### Проверка подлинности

Сборки создаются на GitHub Actions и имеют подпись-аттестацию GitHub.

```
gh attestation verify Journal-{{TAG}}-android.apk --repo {{REPO}}
```

Контрольные суммы SHA-256 (`SHA256SUMS.txt`):

```
{{SUMS}}
```
