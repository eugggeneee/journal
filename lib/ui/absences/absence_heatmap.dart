import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/store.dart';
import '../../logic/heatmap.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';

/// Календарь пропусков: месяц сеткой, чем больше часов за день, тем насыщеннее клетка. Нажатие на клетку
/// показывает, по каким предметам набрались часы. Стрелки листают месяцы.
class AbsenceHeatmap extends StatefulWidget {
  const AbsenceHeatmap({super.key, required this.store});
  final AppStore store;

  @override
  State<AbsenceHeatmap> createState() => _AbsenceHeatmapState();
}

class _AbsenceHeatmapState extends State<AbsenceHeatmap> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  bool get _isCurrent {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int delta) {
    Haptics.selection();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _openDay(BuildContext context, MonthAbsences data, int day) {
    final subjects = data.bySubjectByDay[day];
    if (subjects == null || subjects.isEmpty) return;
    Haptics.selection();
    final date = DateTime(data.year, data.month, day);
    final hours = data.hoursByDay[day] ?? 0;
    showAdaptiveSheet<void>(
      context,
      (ctx) => SheetScaffold(
        title: longDate(date),
        subtitle: '${hoursText(hours)} пропущено',
        children: [
          for (final e in subjects.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(color: ctx.cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Expanded(child: Text(widget.store.subjectName(e.key), style: ctx.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                  const SizedBox(width: 12),
                  Text(hoursText(e.value), style: ctx.tt.labelLarge?.copyWith(color: ctx.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final data = MonthAbsences.of(widget.store.absences, _month.year, _month.month);
    final accent = absenceAccent(context, excused: false);
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = data.daysInMonth;
    final rowCount = ((leading + days) / 7).ceil();
    final now = DateTime.now();

    Widget cell(int index) {
      final day = index - leading + 1;
      if (day < 1 || day > days) return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
      final k = data.intensity(day);
      final isToday = _isCurrent && day == now.day;
      final bg = k > 0 ? Color.alphaBlend(accent.withValues(alpha: 0.2 + 0.7 * k), cs.surfaceContainerHigh) : cs.surfaceContainerHigh.withValues(alpha: 0.6);
      final fg = k > 0.65 ? cs.onPrimary : cs.onSurface;
      return AspectRatio(
        aspectRatio: 1,
        child: Semantics(
          button: k > 0,
          label: k > 0 ? '$day число, ${hoursText(data.hoursByDay[day]!)} пропущено' : '$day число, пропусков нет',
          excludeSemantics: true,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: k > 0 ? () => _openDay(context, data, day) : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: isToday ? Border.all(color: cs.primary, width: 2) : null,
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('$day', style: tt.labelLarge?.copyWith(color: fg, fontWeight: k > 0 ? FontWeight.w800 : FontWeight.w500)),
                      if (k > 0) Text('${data.hoursByDay[day]} ч', style: TextStyle(fontSize: 10, height: 1.1, color: fg.withValues(alpha: 0.9), fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final grid = Column(
      key: ValueKey('${_month.year}-${_month.month}'),
      children: [
        for (var r = 0; r < rowCount; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              for (var c = 0; c < 7; c++) ...[
                if (c > 0) const SizedBox(width: 6),
                Expanded(child: cell(r * 7 + c)),
              ],
            ]),
          ),
      ],
    );

    return SegmentCard(
      index: 0,
      count: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconButton(tooltip: 'Предыдущий месяц', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(monthYear(_month), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  data.totalHours == 0 ? 'Пропусков нет' : '${hoursText(data.totalHours)} пропущено',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            IconButton(tooltip: 'Следующий месяц', icon: const Icon(Icons.chevron_right_rounded), onPressed: _isCurrent ? null : () => _shift(1)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            for (var c = 0; c < 7; c++) ...[
              if (c > 0) const SizedBox(width: 6),
              Expanded(
                child: Center(
                  child: Text(_weekdays[c], style: tt.labelSmall?.copyWith(color: c == 6 ? cs.error.withValues(alpha: 0.8) : cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Swap(child: grid),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('меньше', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            for (final k in const [0.0, 0.3, 0.6, 1.0])
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: k == 0 ? cs.surfaceContainerHigh : Color.alphaBlend(accent.withValues(alpha: 0.2 + 0.7 * k), cs.surfaceContainerHigh),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            const SizedBox(width: 4),
            Text('больше', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}
