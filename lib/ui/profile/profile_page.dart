import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../../logic/limits.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/settings_tiles.dart';
import '../settings/bells_page.dart';
import '../settings/group_picker.dart';
import '../settings/settings_pages.dart';
import '../theme/app_theme.dart';
import 'theme_page.dart';

/// Профиль: сверху группа, ниже — настройки по разделам в том же стиле, что и пары в расписании.
/// Шесть разделов помещаются на экран без прокрутки.
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

    final rows = <_Section>[
      _Section(
        icon: Icons.palette_rounded,
        title: 'Оформление',
        subtitle: '${AppTheme.nameOf(s.themeColor, hasDynamic: AppTheme.dynamicAvailable.value)} · ${modeNames[s.themeMode]}',
        tone: Tone(cs.primaryContainer, cs.onPrimaryContainer),
        page: const ThemePage(),
      ),
      _Section(
        icon: Icons.calendar_month_rounded,
        title: 'Расписание',
        subtitle: s.autoRefresh ? 'Группа и автообновление' : 'Автообновление выключено',
        tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
        page: const ScheduleSettingsPage(),
      ),
      _Section(
        icon: Icons.notifications_active_rounded,
        title: 'Звонки',
        subtitle: bellsSummary(s),
        tone: Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
        page: const BellsPage(),
      ),
      _Section(
        icon: Icons.event_busy_rounded,
        title: 'Пропуски',
        subtitle: sem.upcoming ? 'Каникулы · лимит $kMonthLimit ч в месяц' : '${sem.title} · лимиты $kMonthLimit ч и $kSemesterLimit ч',
        tone: Tone(cs.errorContainer, cs.onErrorContainer),
        page: const AbsenceSettingsPage(),
      ),
      _Section(
        icon: Icons.tune_rounded,
        title: 'Поведение',
        subtitle: s.haptics ? 'Виброотклик включён' : 'Виброотклик выключен',
        tone: Tone(cs.primaryContainer, cs.onPrimaryContainer),
        page: const BehaviorSettingsPage(),
      ),
      _Section(
        icon: Icons.cloud_sync_rounded,
        title: 'Данные',
        subtitle: 'Копия и восстановление',
        tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer),
        page: const DataSettingsPage(),
      ),
    ];

    return LargePage(
      title: 'Профиль',
      subtitle: 'Группа ${s.group} · МГТЭК',
      bottomGap: 24,
      slivers: [
        Inset(children: [
          Appear(
            child: PressScale(
              scale: 0.99,
              child: Material(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: ArtCircles(
                  color: cs.primary,
                  child: InkWell(
                    onTap: () {
                      Haptics.selection();
                      openGroupPicker(context);
                    },
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
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++)
            SegmentCard(
              index: i,
              count: rows.length,
              onTap: () => _open(context, rows[i].page),
              child: BadgeRow(icon: rows[i].icon, tone: rows[i].tone, title: rows[i].title, subtitle: rows[i].subtitle),
            ),
        ]),
      ],
    );
  }
}

class _Section {
  const _Section({required this.icon, required this.title, required this.subtitle, required this.tone, required this.page});
  final IconData icon;
  final String title;
  final String subtitle;
  final Tone tone;
  final Widget page;
}
