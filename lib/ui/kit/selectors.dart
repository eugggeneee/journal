import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../scope.dart';

/// Выбор оформления: как в системе / светлая / тёмная.
class ThemeSelector extends StatelessWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 0, label: Text('Системная')),
          ButtonSegment(value: 1, label: Text('Светлая')),
          ButtonSegment(value: 2, label: Text('Тёмная')),
        ],
        selected: {store.settings.themeMode},
        onSelectionChanged: (s) {
          Haptics.selection();
          store.setThemeMode(s.first);
        },
      ),
    );
  }
}

/// Сколько часов отмечается при быстром нажатии «пропустил».
class HoursSelector extends StatelessWidget {
  const HoursSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 2, label: Text('2 часа (пара)')),
          ButtonSegment(value: 1, label: Text('1 час')),
        ],
        selected: {store.settings.absenceHours},
        onSelectionChanged: (s) {
          Haptics.selection();
          store.setAbsenceHours(s.first);
        },
      ),
    );
  }
}
