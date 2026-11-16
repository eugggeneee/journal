import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import 'settings_home.dart';

/// Кнопка «Настройки» в шапке вкладки: открывает экран настроек поверх вкладок.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Настройки',
        icon: const Icon(Icons.settings_rounded),
        onPressed: () {
          Haptics.selection();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsHomePage()));
        },
      );
}
