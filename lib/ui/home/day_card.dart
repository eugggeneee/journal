import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../schedule/lesson_card.dart';
import '../schedule/lesson_sheet.dart';
import '../grades/grade_sheet.dart';
import '../schedule/marks.dart';
import '../settings/bells_page.dart';
import 'day_bar.dart';
import 'hero_surface.dart';

class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.now,
    required this.slots,
    required this.profile,
    required this.store,
    required this.header,
    required this.onOpenDay,
    required this.viewportHeight,
    this.metrics,
  });
  final Widget Function(Tone, bool)? metrics;
  final double viewportHeight;
  final DateTime now;
  final List<LessonSlot> slots;
  final BellProfile profile;
  final AppStore store;
  final VoidCallback onOpenDay;
  final Widget Function(Color fg, bool hasLessonActions) header;

  String _title(LessonSlot slot) => slot.subjects.map(store.subjectName).join(' / ');
  String _place(LessonSlot slot) {
    final rooms = <String, Set<String>>{};
    for (final entry in slot.entries) {
      final teachers = rooms.putIfAbsent(LessonCard.roomText(entry.room), () => <String>{});
      if (entry.teacher.isNotEmpty) teachers.add(entry.teacher);
    }
    return rooms.entries
        .map(
          (entry) =>
              [if (entry.key.isNotEmpty) entry.key, if (entry.value.isNotEmpty) entry.value.join(', ')].join(' · '),
        )
        .where((text) => text.isNotEmpty)
        .join(' / ');
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) => _day(context, box.maxWidth));

  Widget _day(BuildContext context, double width) {
    final cs = context.cs;
    final tt = context.tt;
    final tone = Tone(cs.primaryContainer, cs.onPrimaryContainer);
    final fg = tone.fg;
    final minute = now.hour * 60 + now.minute;
    final numbers = slots.map((s) => s.number).toList();
    final completeTimes = numbers.every((n) => profile[n] != null);
    final clock = dayClock(profile, numbers, minute);
    final current = slots.where((s) => s.number == clock.pair).firstOrNull;
    final following = slots.where((s) => s.number > (clock.pair ?? 0)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final next = clock.next == null ? following.firstOrNull : slots.where((s) => s.number == clock.next).firstOrNull;
    final inLesson = clock.phase == DayPhase.lesson || clock.phase == DayPhase.innerBreak;
    final focus = inLesson ? current : next;
    final bell = current == null ? null : profile[current.number];
    final beforeBreak = clock.phase == DayPhase.lesson && bell != null && bell.hasBreak && minute < bell.breakStart!;
    final left = beforeBreak ? bell.breakStart! - minute : clock.left;
    final reason = switch (clock.phase) {
      DayPhase.lesson when beforeBreak => bell.lunchInside ? 'до обеда' : 'до перерыва',
      DayPhase.lesson when next == null => 'до конца занятий',
      DayPhase.lesson => profile.isLunchAfter(current!.number) ? 'до обеда' : 'до конца пары',
      DayPhase.innerBreak => 'до продолжения',
      DayPhase.gap => 'до пары',
      DayPhase.before => 'до начала',
      _ => '',
    };
    final caption = switch (clock.phase) {
      DayPhase.lesson => 'Идёт сейчас',
      DayPhase.innerBreak => bell!.lunchInside ? 'Обед внутри пары' : 'Перерыв внутри пары',
      DayPhase.gap => gapBetween(profile, current!.number, next!.number) ?? 'Перерыв',
      DayPhase.before => 'Первая пара',
      DayPhase.after => completeTimes ? pairsText(slots.length) : 'Без времени звонков',
      DayPhase.none => 'Сегодня',
    };
    final title = clock.phase == DayPhase.after && completeTimes
        ? 'Пары закончились'
        : focus != null
        ? _title(focus)
        : pairsText(slots.length);
    final bells = numbers.map((n) => profile[n]).whereType<BellSlot>().toList();
    final remaining = bells.where((b) => minute < b.end).length;
    final end = bells.isEmpty ? null : bells.map((b) => b.end).reduce((a, b) => a > b ? a : b);
    final folded = store.settings.dayCardFolded;

    final scale = MediaQuery.textScalerOf(context);
    final availableHeight = viewportHeight - MediaQuery.paddingOf(context).top;
    final sideBySide = width >= 560 && viewportHeight < 500;
    final columnWidth = sideBySide ? (width - 56) / 2 : width - 40;
    final titleStyle = tt.headlineSmall!.copyWith(height: 1.1, fontWeight: FontWeight.w800);
    final place = focus != null ? _place(focus) : '';
    final summaryText = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: '$caption\n', style: tt.labelLarge),
          TextSpan(text: title, style: titleStyle),
          if (!folded && place.isNotEmpty) TextSpan(text: '\n$place', style: tt.bodyMedium),
        ],
      ),
      textDirection: Directionality.of(context),
      textScaler: scale,
    )..layout(maxWidth: (columnWidth - 48 - (focus == null ? 0 : 66)).clamp(1, double.infinity).toDouble());
    final longSummary = summaryText.height > availableHeight * .40;
    summaryText.dispose();
    final compact = folded || availableHeight < scale.scale(560) || longSummary;
    final detailsBelow = !folded && reason.isNotEmpty && (availableHeight < scale.scale(440) || longSummary);
    final summaryFg = detailsBelow ? cs.onSurface : fg;
    final summaryBg = detailsBelow ? cs.surface : tone.bg;
    final summary = Row(
      children: [
        if (focus != null) ...[
          CookieIcon(
            size: 54,
            bg: summaryFg,
            glyph: Text(
              '${focus.number}',
              style: tt.headlineSmall?.copyWith(color: summaryBg, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: InkWell(
            onTap: focus == null ? onOpenDay : () => showLessonSheet(context, now, focus),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, style: tt.labelLarge?.copyWith(color: summaryFg)),
                Text(title, style: titleStyle.copyWith(color: summaryFg)),
                if (!folded && place.isNotEmpty)
                  Text(place, style: tt.bodyMedium?.copyWith(color: summaryFg.withValues(alpha: .85))),
                if (folded && reason.isNotEmpty)
                  Text('$left мин $reason', style: tt.bodyMedium?.copyWith(color: summaryFg)),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: folded ? 'Развернуть карточку' : 'Свернуть карточку',
          color: summaryFg,
          icon: Icon(folded ? Icons.unfold_more_rounded : Icons.unfold_less_rounded),
          onPressed: () {
            Haptics.selection();
            store.setDayCardFolded(!folded);
          },
        ),
      ],
    );
    final endLabel = '$reason\nв ${fmtMin(minute + left)}';
    final endStyle = tt.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600);
    final timer = LayoutBuilder(
      builder: (context, box) {
        final separateLabel = box.maxWidth < MediaQuery.textScalerOf(context).scale(250);
        return Semantics(
          label: '$left мин $reason в ${fmtMin(minute + left)}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    flex: 3,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$left',
                        style: TextStyle(
                          fontSize: 148,
                          height: .93,
                          letterSpacing: -5,
                          fontWeight: FontWeight.w900,
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'мин',
                              style: tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1),
                            ),
                          ),
                          if (!separateLabel) Text(endLabel, style: endStyle),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (separateLabel) Text('$reason в ${fmtMin(minute + left)}', style: endStyle),
            ],
          ),
        );
      },
    );
    Widget heroContent() {
      if (folded || reason.isEmpty) return summary;
      if (detailsBelow) return timer;
      if (sideBySide) {
        return Row(
          children: [
            Expanded(child: summary),
            const SizedBox(width: 16),
            Expanded(child: timer),
          ],
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [summary, timer]);
    }

    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (end != null) ...[
          const SizedBox(height: 8),
          if (!compact)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                children: [
                  Text(
                    'Ход дня',
                    style: tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    remaining > 0
                        ? 'ещё ${pairsText(remaining)} · до ${fmtMin(end)}'
                        : 'Последний звонок в ${fmtMin(end)}',
                    style: tt.labelLarge?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
          DayBar(
            slots: slots,
            profile: profile,
            minute: minute,
            fg: fg,
            bg: tone.bg,
            compact: compact,
            onOpen: (slot) => showLessonSheet(context, now, slot),
          ),
        ],
        if (metrics != null) ...[const SizedBox(height: 8), metrics!(tone, compact)],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroSurface(
          tone: tone,
          header: (fg) => header(fg, inLesson && current != null),
          child: sideBySide && detailsBelow
              ? Row(
                  children: [
                    Expanded(child: timer),
                    const SizedBox(width: 16),
                    Expanded(child: overview),
                  ],
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heroContent(), overview]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (inLesson && current != null) ...[
                const SizedBox(height: 12),
                _LessonActions(date: now, slot: current, store: store, fg: cs.onSurface),
                if (store.markFor(now, current.number) case final mark?)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(alignment: Alignment.centerLeft, child: MarkPill(mark)),
                  ),
              ],
              if (detailsBelow) ...[const SizedBox(height: 12), summary],
              if (!folded) ...[
                if (!completeTimes && slots.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: cs.onSurface),
                      icon: const Icon(Icons.schedule_rounded),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => BellsPage(initialKey: store.bellKeyOn(now)))),
                      label: const Text('Выбрать звонки'),
                    ),
                  ),
                if (inLesson && next != null) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => showLessonSheet(context, now, next),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      'Следующая пара',
                                      if (profile[next.number] case final upcoming?) fmtMin(upcoming.start),
                                    ].join(' · '),
                                    style: tt.labelMedium?.copyWith(color: cs.onSurface),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _title(next),
                                    style: tt.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                                  ),
                                  if (_place(next).isNotEmpty)
                                    Text(_place(next), style: tt.bodySmall?.copyWith(color: cs.onSurface)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right_rounded, color: cs.onSurface),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LessonActions extends StatelessWidget {
  const _LessonActions({required this.date, required this.slot, required this.store, required this.fg});
  final DateTime date;
  final LessonSlot slot;
  final AppStore store;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final absent = store.absenceFor(date, slot.number) != null;
    final mark = store.markFor(date, slot.number);
    final actions = <(IconData, String, VoidCallback)>[
      (
        Icons.star_outline_rounded,
        'Оценка',
        () =>
            showGradeSheet(context, date: date, subject: store.absenceFor(date, slot.number)?.subject ?? slot.subject),
      ),
      (
        absent ? Icons.event_available_rounded : Icons.event_busy_outlined,
        absent ? 'Снять пропуск' : 'Пропуск',
        () => toggleLessonAbsence(context, store, date, slot),
      ),
      (
        Icons.edit_outlined,
        'Пометка',
        () => showMarkSheet(context, date, lesson: slot.number, edit: mark, customEntry: true),
      ),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i != 0) const SizedBox(width: 4),
            Expanded(
              child: GroupTile(
                index: i,
                count: actions.length,
                color: fg.withValues(alpha: .1),
                onTap: actions[i].$3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actions[i].$1, color: fg, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        actions[i].$2,
                        textAlign: TextAlign.center,
                        style: context.tt.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
