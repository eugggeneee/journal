# Безопасность

## Поддерживаемые версии

Исправления выходят только для последней стабильной версии (см. [Releases](https://github.com/eugggeneee/journal/releases/latest)).

## Сообщение об уязвимости

Не открывайте публичный issue. Используйте раздел Security, Report a vulnerability в репозитории https://github.com/eugggeneee/journal/security/advisories/new. Укажите версию, платформу, шаги воспроизведения и последствия.

## Область

- Данные пользователя хранятся только на устройстве.
- Единственный сетевой запрос: загрузка расписания с `bseumtc.by` по HTTPS.
- Релизные сборки имеют контрольные суммы и подпись-аттестацию GitHub: [docs/RELEASING.md](docs/RELEASING.md).
