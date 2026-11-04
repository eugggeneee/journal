import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../logic/limits.dart';
import '../group_picker.dart';
import '../kit/ctx.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import '../settings/bells_page.dart';
import '../settings/settings_pages.dart';
import '../theme.dart';
import 'theme_page.dart';

/// Профиль: сверху группа, ниже — настройки, разбитые на разделы. Все разделы помещаются на экран без прокрутки.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _open(BuildContext context, Widget page) {
    Haptics.selection();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final store = StoreScope.of(context);
    final s = store.settings;
    const modeNames = ['как в системе', 'светлая', 'тёмная'];
    final sem = store.semesterOn();

    final tiles = <_Section>[
      _Section(
        icon: Icons.palette_rounded,
        title: 'Оформление',
        subtitle: '${AppTheme.nameOf(s.themeColor, hasDynamic: AppTheme.dynamicAvailable.value)} · ${modeNames[s.themeMode]}',
        tone: Tone(cs.primaryContainer, cs.onPrimaryContainer),
        onTap: () => _open(context, const ThemePage()),
      ),
      _Section(
        icon: Icons.calendar_month_rounded,
        title: 'Расписание',
        subtitle: s.autoRefresh ? 'Автообновление включено' : 'Автообновление выключено',
        tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
        onTap: () => _open(context, const ScheduleSettingsPage()),
      ),
      _Section(
        icon: Icons.notifications_active_rounded,
        title: 'Звонки',
        subtitle: bellsSummary(s),
        tone: Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
        onTap: () => _open(context, const BellsPage()),
      ),
      _Section(
        icon: Icons.event_busy_rounded,
        title: 'Пропуски',
        subtitle: sem.upcoming ? 'Каникулы' : '${sem.title} · лимит $kSemesterLimit ч',
        tone: Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
        onTap: () => _open(context, const AbsenceSettingsPage()),
      ),
      _Section(
        icon: Icons.tune_rounded,
        title: 'Поведение',
        subtitle: s.haptics ? 'Виброотклик включён' : 'Виброотклик выключен',
        tone: Tone(cs.primaryContainer, cs.onPrimaryContainer),
        onTap: () => _open(context, const BehaviorSettingsPage()),
      ),
      _Section(
        icon: Icons.cloud_sync_rounded,
        title: 'Данные',
        subtitle: 'Копия и восстановление',
        tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
        onTap: () => _open(context, const DataSettingsPage()),
      ),
    ];

    return LargePage(
      title: 'Профиль',
      subtitle: 'Группа ${s.group} · МГТЭК',
      bottomGap: 24,
      slivers: [
        Inset(children: [
          Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openGroupPicker(context),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CookieIcon(icon: Icons.school_rounded, size: 64, bg: cs.primary, fg: cs.onPrimary),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Группа ${s.group}', style: context.tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('МГТЭК · нажмите, чтобы сменить', style: context.tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onPrimaryContainer),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < tiles.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _SectionTile(section: tiles[i])),
              const SizedBox(width: 12),
              Expanded(child: _SectionTile(section: tiles[i + 1])),
            ]),
          ],
        ]),
      ],
    );
  }
}

class _Section {
  const _Section({required this.icon, required this.title, required this.subtitle, required this.tone, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Tone tone;
  final VoidCallback onTap;
}

/// Плитка раздела настроек: фиксированной высоты, чтобы все шесть разделов стояли ровной сеткой.
class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.section});
  final _Section section;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final t = section.tone;
    return Semantics(
      button: true,
      label: '${section.title}. ${section.subtitle}',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: section.onTap,
          child: SizedBox(
            height: 132,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(16)),
                  child: Icon(section.icon, size: 24, color: t.fg),
                ),
                const Spacer(),
                Text(section.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  section.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.25),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
