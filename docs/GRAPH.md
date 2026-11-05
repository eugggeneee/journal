# Граф проекта

Файл создаётся скриптом `scripts/project/graph.py`. Вручную не редактируется.
После любого изменения файлов в `lib/` и `test/` (создание, перенос, удаление, смена импортов) выполните:

```bash
python3 scripts/project/graph.py
```

Файлов Dart: 47 в `lib/`, 6 в `test/`.

## Папки

Стрелка A --> B: файлы папки A импортируют файлы папки B. В скобках — число файлов.

```mermaid
flowchart LR
  subgraph g_core["core"]
    lib_core["core (4)"]
  end
  subgraph g_data["data"]
    lib_data["data (2)"]
  end
  subgraph g_logic["logic"]
    lib_logic["logic (4)"]
    lib_logic_schedule["logic/schedule (3)"]
  end
  subgraph g_root["root"]
    lib["lib (1)"]
  end
  subgraph g_ui["ui"]
    lib_ui_absences["ui/absences (4)"]
    lib_ui_app["ui/app (2)"]
    lib_ui_grades["ui/grades (3)"]
    lib_ui_kit_animation["ui/kit/animation (2)"]
    lib_ui_kit_components["ui/kit/components (3)"]
    lib_ui_kit_foundation["ui/kit/foundation (1)"]
    lib_ui_kit_inputs["ui/kit/inputs (3)"]
    lib_ui_kit_sheets["ui/kit/sheets (2)"]
    lib_ui_onboarding["ui/onboarding (1)"]
    lib_ui_profile["ui/profile (3)"]
    lib_ui_schedule["ui/schedule (4)"]
    lib_ui_settings["ui/settings (4)"]
    lib_ui_theme["ui/theme (1)"]
  end
  lib --> lib_core
  lib --> lib_data
  lib --> lib_logic_schedule
  lib --> lib_ui_app
  lib --> lib_ui_onboarding
  lib --> lib_ui_theme
  lib_data --> lib_core
  lib_data --> lib_logic
  lib_logic --> lib_core
  lib_logic --> lib_data
  lib_logic_schedule --> lib_core
  lib_logic_schedule --> lib_data
  lib_ui_absences --> lib_core
  lib_ui_absences --> lib_data
  lib_ui_absences --> lib_logic
  lib_ui_absences --> lib_ui_app
  lib_ui_absences --> lib_ui_kit_animation
  lib_ui_absences --> lib_ui_kit_components
  lib_ui_absences --> lib_ui_kit_foundation
  lib_ui_absences --> lib_ui_kit_inputs
  lib_ui_absences --> lib_ui_kit_sheets
  lib_ui_absences --> lib_ui_settings
  lib_ui_app --> lib_core
  lib_ui_app --> lib_data
  lib_ui_app --> lib_logic_schedule
  lib_ui_app --> lib_ui_absences
  lib_ui_app --> lib_ui_grades
  lib_ui_app --> lib_ui_kit_animation
  lib_ui_app --> lib_ui_profile
  lib_ui_app --> lib_ui_schedule
  lib_ui_grades --> lib_core
  lib_ui_grades --> lib_data
  lib_ui_grades --> lib_logic
  lib_ui_grades --> lib_ui_app
  lib_ui_grades --> lib_ui_kit_animation
  lib_ui_grades --> lib_ui_kit_components
  lib_ui_grades --> lib_ui_kit_foundation
  lib_ui_grades --> lib_ui_kit_inputs
  lib_ui_grades --> lib_ui_kit_sheets
  lib_ui_kit_components --> lib_core
  lib_ui_kit_components --> lib_ui_kit_animation
  lib_ui_kit_components --> lib_ui_kit_foundation
  lib_ui_kit_components --> lib_ui_kit_inputs
  lib_ui_kit_inputs --> lib_core
  lib_ui_kit_inputs --> lib_ui_app
  lib_ui_kit_inputs --> lib_ui_kit_foundation
  lib_ui_kit_inputs --> lib_ui_kit_sheets
  lib_ui_kit_sheets --> lib_core
  lib_ui_kit_sheets --> lib_ui_kit_foundation
  lib_ui_onboarding --> lib_core
  lib_ui_onboarding --> lib_data
  lib_ui_onboarding --> lib_ui_app
  lib_ui_onboarding --> lib_ui_kit_animation
  lib_ui_onboarding --> lib_ui_kit_components
  lib_ui_onboarding --> lib_ui_kit_foundation
  lib_ui_onboarding --> lib_ui_kit_inputs
  lib_ui_onboarding --> lib_ui_profile
  lib_ui_onboarding --> lib_ui_settings
  lib_ui_profile --> lib_core
  lib_ui_profile --> lib_logic
  lib_ui_profile --> lib_ui_app
  lib_ui_profile --> lib_ui_kit_animation
  lib_ui_profile --> lib_ui_kit_components
  lib_ui_profile --> lib_ui_kit_foundation
  lib_ui_profile --> lib_ui_kit_inputs
  lib_ui_profile --> lib_ui_kit_sheets
  lib_ui_profile --> lib_ui_settings
  lib_ui_profile --> lib_ui_theme
  lib_ui_schedule --> lib_core
  lib_ui_schedule --> lib_data
  lib_ui_schedule --> lib_logic
  lib_ui_schedule --> lib_logic_schedule
  lib_ui_schedule --> lib_ui_absences
  lib_ui_schedule --> lib_ui_app
  lib_ui_schedule --> lib_ui_grades
  lib_ui_schedule --> lib_ui_kit_animation
  lib_ui_schedule --> lib_ui_kit_components
  lib_ui_schedule --> lib_ui_kit_foundation
  lib_ui_schedule --> lib_ui_kit_inputs
  lib_ui_schedule --> lib_ui_kit_sheets
  lib_ui_schedule --> lib_ui_settings
  lib_ui_settings --> lib_core
  lib_ui_settings --> lib_data
  lib_ui_settings --> lib_logic
  lib_ui_settings --> lib_ui_app
  lib_ui_settings --> lib_ui_kit_animation
  lib_ui_settings --> lib_ui_kit_components
  lib_ui_settings --> lib_ui_kit_foundation
  lib_ui_settings --> lib_ui_kit_inputs
  lib_ui_settings --> lib_ui_kit_sheets
  lib_ui_theme --> lib_core
```

## Правила слоёв

- core не зависит от data, logic и ui
- data не зависит от ui
- logic не зависит от ui
- ui/kit не зависит от экранов
- lib не зависит от test

## Файлы

| Файл | Строк | Импортирует | Используют |
|---|---:|---:|---:|
| `core/app_icons.dart` | 41 | 1 | 1 |
| `core/dates.dart` | 97 | 0 | 21 |
| `core/haptics.dart` | 18 | 0 | 23 |
| `core/palette.dart` | 68 | 0 | 5 |
| `data/models.dart` | 501 | 1 | 21 |
| `data/store.dart` | 399 | 5 | 15 |
| `logic/bells.dart` | 141 | 2 | 6 |
| `logic/limits.dart` | 105 | 2 | 6 |
| `logic/schedule/cp1251.dart` | 52 | 0 | 2 |
| `logic/schedule/schedule_parser.dart` | 124 | 1 | 2 |
| `logic/schedule/schedule_service.dart` | 185 | 5 | 4 |
| `logic/stats.dart` | 77 | 1 | 3 |
| `logic/subject_names.dart` | 26 | 0 | 1 |
| `main.dart` | 67 | 7 | 0 |
| `ui/absences/absence_actions.dart` | 37 | 5 | 1 |
| `ui/absences/absence_limit.dart` | 322 | 9 | 1 |
| `ui/absences/absence_sheet.dart` | 499 | 12 | 5 |
| `ui/absences/absences_page.dart` | 478 | 18 | 1 |
| `ui/app/scope.dart` | 23 | 2 | 21 |
| `ui/app/shell.dart` | 152 | 10 | 1 |
| `ui/grades/grade_sheet.dart` | 223 | 10 | 5 |
| `ui/grades/grades_page.dart` | 283 | 15 | 2 |
| `ui/grades/subject_page.dart` | 113 | 8 | 1 |
| `ui/kit/animation/motion.dart` | 25 | 0 | 6 |
| `ui/kit/animation/reveal.dart` | 244 | 0 | 14 |
| `ui/kit/components/feedback.dart` | 25 | 1 | 12 |
| `ui/kit/components/overview.dart` | 309 | 6 | 3 |
| `ui/kit/components/widgets.dart` | 427 | 4 | 17 |
| `ui/kit/foundation/ctx.dart` | 98 | 0 | 23 |
| `ui/kit/inputs/pickers.dart` | 507 | 6 | 8 |
| `ui/kit/inputs/selectors.dart` | 56 | 4 | 3 |
| `ui/kit/inputs/settings_tiles.dart` | 91 | 2 | 4 |
| `ui/kit/sheets/select_sheet.dart` | 249 | 3 | 7 |
| `ui/kit/sheets/sheet.dart` | 251 | 2 | 14 |
| `ui/onboarding/onboarding.dart` | 447 | 12 | 1 |
| `ui/profile/profile_page.dart` | 140 | 12 | 1 |
| `ui/profile/theme_page.dart` | 52 | 6 | 1 |
| `ui/profile/theme_widgets.dart` | 468 | 10 | 2 |
| `ui/schedule/add_menu.dart` | 93 | 5 | 1 |
| `ui/schedule/lesson_sheet.dart` | 246 | 15 | 1 |
| `ui/schedule/marks.dart` | 304 | 11 | 3 |
| `ui/schedule/schedule_page.dart` | 728 | 18 | 1 |
| `ui/settings/bells_page.dart` | 704 | 15 | 4 |
| `ui/settings/bells_sheet.dart` | 112 | 8 | 2 |
| `ui/settings/group_picker.dart` | 251 | 4 | 4 |
| `ui/settings/settings_pages.dart` | 360 | 14 | 3 |
| `ui/theme/app_theme.dart` | 173 | 1 | 4 |

## Зависимости папок

- `lib` -> `core`, `data`, `logic/schedule`, `ui/app`, `ui/onboarding`, `ui/theme`
- `core` -> нет
- `data` -> `core`, `logic`
- `logic` -> `core`, `data`
- `logic/schedule` -> `core`, `data`
- `ui/absences` -> `core`, `data`, `logic`, `ui/app`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/kit/sheets`, `ui/settings`
- `ui/app` -> `core`, `data`, `logic/schedule`, `ui/absences`, `ui/grades`, `ui/kit/animation`, `ui/profile`, `ui/schedule`
- `ui/grades` -> `core`, `data`, `logic`, `ui/app`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/kit/sheets`
- `ui/kit/animation` -> нет
- `ui/kit/components` -> `core`, `ui/kit/animation`, `ui/kit/foundation`, `ui/kit/inputs`
- `ui/kit/foundation` -> нет
- `ui/kit/inputs` -> `core`, `ui/app`, `ui/kit/foundation`, `ui/kit/sheets`
- `ui/kit/sheets` -> `core`, `ui/kit/foundation`
- `ui/onboarding` -> `core`, `data`, `ui/app`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/profile`, `ui/settings`
- `ui/profile` -> `core`, `logic`, `ui/app`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/kit/sheets`, `ui/settings`, `ui/theme`
- `ui/schedule` -> `core`, `data`, `logic`, `logic/schedule`, `ui/absences`, `ui/app`, `ui/grades`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/kit/sheets`, `ui/settings`
- `ui/settings` -> `core`, `data`, `logic`, `ui/app`, `ui/kit/animation`, `ui/kit/components`, `ui/kit/foundation`, `ui/kit/inputs`, `ui/kit/sheets`
- `ui/theme` -> `core`

## Тесты

| Тест | Проверяет |
|---|---|
| `data/settings_test.dart` | `core/palette.dart`, `data/models.dart` |
| `data/store_test.dart` | `data/models.dart`, `data/store.dart`, `logic/stats.dart` |
| `logic/bells_test.dart` | `data/models.dart`, `data/store.dart`, `logic/bells.dart` |
| `logic/limits_test.dart` | `data/models.dart`, `logic/limits.dart` |
| `logic/parser_test.dart` | `core/dates.dart`, `logic/schedule/cp1251.dart`, `logic/schedule/schedule_parser.dart`, `logic/schedule/schedule_service.dart` |
| `project/version_test.dart` | файлы проекта |
