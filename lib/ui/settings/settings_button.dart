import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import 'settings_home.dart';

/// Кнопка «Настройки» в шапке вкладки: открывает экран настроек поверх вкладок.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.color});

  /// Цвет значка, если кнопка стоит на цветной поверхности (шапка главной).
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Настройки',
        color: color,
        icon: const Icon(Icons.settings_rounded),
        onPressed: () {
          Haptics.selection();
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsHomePage()));
        },
      );
}
