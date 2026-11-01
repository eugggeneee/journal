## Journal {{TAG}} · МГТЭК — Дневник

Приложение для Android и iOS: расписание, оценки и пропуски в одном месте. Некоммерческий проект.

### Скачать

| Платформа | Файл | Как установить |
|---|---|---|
| 🤖 **Android** | `Journal-{{TAG}}-android.apk` | Скачайте файл → откройте → разрешите установку из этого источника |
| 🍎 **iPhone / iPad** | `Journal-{{TAG}}-ios.ipa` | Установите через [AltStore](https://altstore.io) или [Sideloadly](https://sideloadly.io) |

- Android-сборка {{ANDROID_SIGNING}}.
- iOS-сборка **без подписи Apple** — её подписывает AltStore/Sideloadly своим сертификатом при установке.

### Что нового

{{CHANGES}}

### Проверка подлинности

Сборки собраны автоматически на GitHub Actions и снабжены подписью-аттестацией GitHub (provenance).
Проверить скачанный файл:

```
gh attestation verify Journal-{{TAG}}-android.apk --repo {{REPO}}
```

Контрольные суммы SHA-256 (файл `SHA256SUMS.txt`):

```
{{SUMS}}
```
