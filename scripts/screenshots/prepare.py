"""Подготовить отдельный checkout стабильного тега к съёмке. Релизные файлы не публикуются из этой копии."""
import shutil
import sys
from pathlib import Path

tool = Path(__file__).resolve().parent
app = Path(sys.argv[1]).resolve()
if app == tool.parents[1] or not (app / 'pubspec.yaml').is_file():
    raise SystemExit('Нужен отдельный checkout приложения')
pubspec = app / 'pubspec.yaml'
text = pubspec.read_text()
pubspec.write_text(text.replace('dev_dependencies:\n', 'dev_dependencies:\n  integration_test:\n    sdk: flutter\n'))
# Только часы интерфейса и календаря. Сетевые таймауты и системные часы не меняются.
for name in ['core/dates.dart', 'ui/home/home_page.dart', 'ui/settings/bells_page.dart',
             'ui/schedule/schedule_page.dart', 'ui/schedule/day_timeline.dart', 'ui/schedule/week_view.dart',
             'ui/absences/absence_limit.dart', 'ui/absences/absence_heatmap.dart', 'ui/absences/absences_page.dart',
             'ui/grades/grades_page.dart', 'ui/settings/settings_home.dart', 'ui/settings/settings_pages.dart']:
    src = app / 'lib' / name
    if src.is_file():
        text = src.read_text(encoding='utf-8')
        src.write_text(text.replace('DateTime.now()', 'DateTime(2026, 11, 18, 11, 10)'), encoding='utf-8')
dest = app / 'integration_test' / 'journal_screens_test.dart'
dest.parent.mkdir(exist_ok=True)
shutil.copyfile(tool / 'scenes.dart.in', dest)
