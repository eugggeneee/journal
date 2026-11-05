import 'package:material_ui/material_ui.dart';

import '../../../core/haptics.dart';
import '../foundation/ctx.dart';

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

/// Строка в стиле карточек расписания: значок в скруглённом квадрате, заголовок, пояснение и стрелка.
/// Кладётся внутрь [SegmentCard].
class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key, required this.icon, required this.tone, required this.title, this.subtitle, this.trailing, this.showChevron = true});
  final IconData icon;
  final Tone tone;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(46 * 0.34)),
          child: Icon(icon, size: 24, color: tone.fg),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.25)),
              ),
          ]),
        ),
        if (trailing != null) trailing!,
        if (trailing == null && showChevron) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
