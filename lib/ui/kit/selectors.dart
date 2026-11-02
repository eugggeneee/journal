import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../scope.dart';
import 'pickers.dart';
import 'select_sheet.dart';

/// Режим оформления: как в системе / светлая / тёмная (цвета выбираются отдельно).
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
          ButtonSegment(value: 0, icon: Icon(Icons.brightness_auto_rounded), label: Text('Авто')),
          ButtonSegment(value: 1, icon: Icon(Icons.light_mode_rounded), label: Text('Светлая')),
          ButtonSegment(value: 2, icon: Icon(Icons.dark_mode_rounded), label: Text('Тёмная')),
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
    final h = store.settings.absenceHours == 1 ? 1 : 2;
    return SelectField<int>(
      label: 'Часов по умолчанию',
      icon: Icons.timer_outlined,
      value: h,
      valueLabel: h == 1 ? '1 час' : '2 часа (пара)',
      sheetTitle: 'Быстрый пропуск',
      sheetSubtitle: 'Столько часов отмечается по значку пропуска у пары',
      options: const [
        MenuOption(2, '2 часа (пара)', icon: Icons.looks_two_rounded),
        MenuOption(1, '1 час', icon: Icons.looks_one_rounded),
      ],
      onSelected: store.setAbsenceHours,
    );
  }
}
