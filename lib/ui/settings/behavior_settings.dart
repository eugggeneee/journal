part of 'settings_pages.dart';

class BehaviorSettingsPage extends StatelessWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return SettingsScaffold(title: 'Поведение', children: [
      SegmentCard(
        index: 0,
        count: 1,
        onTap: () => store.setHaptics(!s.haptics),
        child: SettingsTile(
          icon: Icons.vibration_rounded,
          title: 'Виброотклик',
          subtitle: 'Лёгкая вибрация при нажатиях и отметках',
          trailing: SettingsSwitch(value: s.haptics, onChanged: store.setHaptics),
        ),
      ),
      const SectionHeader('Анимации'),
      const MotionSelector(),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Text(
          s.motion == 0
              ? 'Все переходы и появления в полную силу.'
              : s.motion == 1
                  ? 'Движение короче и тише, без лишних эффектов.'
                  : 'Всё меняется сразу. Системная настройка «Убрать анимации» тоже учитывается.',
          style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant, height: 1.4),
        ),
      ),
      const SectionHeader('Подсказки'),
      SegmentCard(
        index: 0,
        count: 1,
        onTap: () {
          Haptics.selection();
          showAdaptiveSheet<void>(
            context,
            (_) => const SheetScaffold(title: 'Жесты', subtitle: 'Что делают нажатие, удержание и смахивание', children: [GestureGuide()]),
          );
        },
        child: const SettingsTile(
          icon: Icons.gesture_rounded,
          title: 'Руководство по жестам',
          subtitle: 'Нажатие, удержание, смахивание и свёрнутая карточка',
        ),
      ),
    ]);
  }
}
