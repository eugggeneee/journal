## Journal {{TAG}}

МГТЭК · Дневник: расписание, отметки и пропуски. Android и iOS.

### Скачать

| Платформа | Файл | Установка |
|---|---|---|
| Android | `Journal-{{TAG}}-android.apk` | Открыть файл и разрешить установку из этого источника |
| iPhone, iPad | [Скачать IPA](https://github.com/{{REPO}}/releases/download/{{TAG}}/Journal-{{TAG}}-ios.ipa) | В AltStore Classic или SideStore открыть **My Apps → +** и выбрать файл. На компьютере можно использовать [Sideloadly](https://sideloadly.io) |

Для установки стабильной версии и дальнейших обновлений [добавьте источник Journal в AltStore Classic или SideStore](https://eugggeneee.github.io/journal/ios/).

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
