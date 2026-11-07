import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/settings_tiles.dart';

/// Состояние дня без пар (выходной, нет занятий): что делать дальше и, по желанию, итоги недели.
/// Показывает ближайший учебный день из сохранённых расписаний; нажатие открывает его.
class RestDay extends StatelessWidget {
  const RestDay({
    super.key,
    required this.date,
    required this.store,
    required this.onJump,
    required this.icon,
    required this.title,
    required this.message,
    this.recap = false,
  });
  final DateTime date;
  final AppStore store;
  final ValueChanged<DateTime> onJump;
  final IconData icon;
  final String title;
  final String message;

  /// Показывать итоги прошедшей недели (для воскресенья).
  final bool recap;

  /// Ближайший день после [date] (в пределах недели), у которого сохранены пары.
  DaySchedule? _nextStudyDay() {
    for (var k = 1; k <= 8; k++) {
      final s = store.cachedSchedule(store.settings.group, addDays(date, k));
      if (s != null && s.slots.isNotEmpty) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final next = _nextStudyDay();
    final rows = <_Info>[];

    if (next != null) {
      final profile = store.bellProfileFor(next.date);
      final bells = [for (final s in next.slots) profile[s.number]].whereType<BellSlot>().toList();
      var span = '';
      if (bells.isNotEmpty) {
        final from = bells.map((b) => b.start).reduce((a, b) => a < b ? a : b);
        final to = bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
        span = ' · ${shortRange(from, to)}';
      }
      final target = next.date;
      rows.add(_Info(
        icon: Icons.event_rounded,
        tone: Tone(cs.primaryContainer, cs.onPrimaryContainer),
        title: 'Дальше: ${relativeDay(target)}',
        subtitle: '${shortDate(target)} · ${pairsText(next.slots.length)}$span',
        onTap: () => onJump(target),
      ));
    }

    if (recap) {
      final from = addDays(date, -6);
      var pairs = 0;
      for (var k = 0; k < 7; k++) {
        final s = store.cachedSchedule(store.settings.group, addDays(from, k));
        if (s != null) pairs += s.slots.length;
      }
      var hours = 0;
      for (final a in store.absences) {
        final d = dateOnly(a.date);
        if (!d.isBefore(from) && !d.isAfter(date)) hours += a.hours;
      }
      if (pairs > 0 || hours > 0) {
        rows.add(_Info(
          icon: Icons.insights_rounded,
          tone: hours > 0 ? absenceTone(context, excused: false) : Tone(cs.secondaryContainer, cs.onSecondaryContainer),
          title: 'Итоги недели',
          subtitle: hours > 0 ? '${pairsText(pairs)} · пропущено ${hoursText(hours)}' : '${pairsText(pairs)} · без пропусков',
        ));
      }
    }

    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      action: rows.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var i = 0; i < rows.length; i++)
                SegmentCard(
                  index: i,
                  count: rows.length,
                  onTap: rows[i].onTap,
                  child: BadgeRow(
                    icon: rows[i].icon,
                    tone: rows[i].tone,
                    title: rows[i].title,
                    subtitle: rows[i].subtitle,
                    showChevron: rows[i].onTap != null,
                  ),
                ),
            ]),
    );
  }
}

class _Info {
  const _Info({required this.icon, required this.tone, required this.title, required this.subtitle, this.onTap});
  final IconData icon;
  final Tone tone;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}
