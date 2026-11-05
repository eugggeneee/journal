## Изменение

Что и зачем. Заголовок pull request оформлен по docs/COMMITS.md.

## Проверка

- [ ] `python3 scripts/project/check.py` проходит
- [ ] `docs/GRAPH.md` обновлён (`python3 scripts/project/graph.py`), если менялись `lib/` или `test/`
- [ ] `flutter analyze` без новых замечаний
- [ ] `flutter test` проходит
- [ ] Строка в `CHANGELOG.md` добавлена, если меняется поведение
- [ ] Проверено на устройстве (если менялся интерфейс)
