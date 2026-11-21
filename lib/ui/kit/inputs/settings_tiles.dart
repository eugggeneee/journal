import 'package:material_ui/material_ui.dart';

import '../../../core/haptics.dart';
import '../foundation/journal_theme.dart';
import '../components/widgets.dart';

/// Строка настроек в стиле Material: значок слева, заголовок, пояснение и действие справа.
class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = BadgeRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      showChevron: false,
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Переключатель Material 3 с галочкой на включённом положении.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: (v) {
          Haptics.selection();
          onChanged(v);
        },
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
          (states) => states.contains(WidgetState.selected) ? const Icon(Icons.check_rounded) : null,
        ),
      );
}

/// Строка в стиле карточек расписания: значок в скруглённом квадрате, заголовок, пояснение и стрелка.
/// Кладётся внутрь [SegmentCard].
class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.showChevron = true});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => JournalRow(
    leading: IconBox(icon: icon), title: title, subtitle: subtitle,
    trailing: trailing ?? (showChevron ? Icon(Icons.chevron_right_rounded, color: context.cs.onSurfaceVariant) : null),
  );
}
