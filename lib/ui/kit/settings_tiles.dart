import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import 'ctx.dart';

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
    final cs = context.cs;
    return ListTile(
      onTap: onTap,
      // у карточек-сегментов скругление задаёт сама карточка
      shape: const RoundedRectangleBorder(),
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      trailing: trailing,
    );
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
