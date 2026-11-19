import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/foundation/lesson_colors.dart';
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
    this.metrics,
  });
  final DateTime now;
  final List<LessonSlot> slots;
  final BellProfile profile;
  final AppStore store;
  final VoidCallback onOpenDay;
  final Widget Function(Color fg, bool hasLessonActions) header;
  final Widget? metrics;

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
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final tone = Tone(cs.primary, cs.onPrimary);
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
    final nextColors = next == null ? null : LessonColors.of(context, store, next);
    final focusColors = focus == null ? null : LessonColors.of(context, store, focus);

    return HeroSurface(
      tone: tone,
      header: (fg) => header(fg, inLesson && current != null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (focus != null) ...[
                CookieIcon(
                  size: 54,
                  bg: focusColors!.fill,
                  glyph: Text(
                    '${focus.number}',
                    style: tt.headlineSmall?.copyWith(color: focusColors.ink, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: InkWell(
                  onTap: onOpenDay,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(caption, style: tt.labelLarge?.copyWith(color: fg)),
                      Text(
                        title,
                        style: tt.headlineSmall?.copyWith(color: fg, height: 1.1, fontWeight: FontWeight.w800),
                      ),
                      if (!folded && focus != null && _place(focus).isNotEmpty)
                        Text(_place(focus), style: tt.bodyMedium?.copyWith(color: fg.withValues(alpha: .85))),
                      if (folded && reason.isNotEmpty)
                        Text('$left мин $reason', style: tt.bodyMedium?.copyWith(color: fg)),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: folded ? 'Развернуть карточку' : 'Свернуть карточку',
                color: fg,
                icon: Icon(folded ? Icons.unfold_more_rounded : Icons.unfold_less_rounded),
                onPressed: () {
                  Haptics.selection();
                  store.setDayCardFolded(!folded);
                },
              ),
            ],
          ),
          if (!folded && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Semantics(
                label: '$left мин $reason в ${fmtMin(minute + left)}',
                excludeSemantics: true,
                child: Row(
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
                            Text(
                              'мин',
                              style: tt.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1),
                            ),
                            Text(
                              '$reason\nв ${fmtMin(minute + left)}',
                              style: tt.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (inLesson && current != null) ...[
            const SizedBox(height: 12),
            _LessonActions(date: now, slot: current, store: store, fg: fg),
          ],
          if (end != null) ...[
            const SizedBox(height: 12),
            if (!folded)
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
              store: store,
              slots: slots,
              profile: profile,
              minute: minute,
              fg: fg,
              bg: tone.bg,
              compact: folded,
              onOpen: (slot) => showLessonSheet(context, now, slot),
            ),
          ],
          if (!folded) ...[
            if (!completeTimes && slots.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: fg),
                  icon: const Icon(Icons.schedule_rounded),
                  onPressed: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => BellsPage(initialKey: store.bellKeyOn(now)))),
                  label: const Text('Выбрать звонки'),
                ),
              ),
            if (inLesson && next != null) ...[
              const SizedBox(height: 16),
              Material(
                color: nextColors!.fill,
                borderRadius: BorderRadius.circular(16),
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
                                style: tt.labelMedium?.copyWith(color: nextColors.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _title(next),
                                style: tt.titleMedium?.copyWith(color: nextColors.ink, fontWeight: FontWeight.w700),
                              ),
                              if (_place(next).isNotEmpty)
                                Text(_place(next), style: tt.bodySmall?.copyWith(color: nextColors.ink)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: nextColors.ink),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (metrics != null) ...[const SizedBox(height: 16), metrics!],
        ],
      ),
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
              child: Material(
                color: fg.withValues(alpha: .10),
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(i == 0 ? 20 : 6),
                  right: Radius.circular(i == 2 ? 20 : 6),
                ),
                child: InkWell(
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
            ),
          ],
        ],
      ),
    );
  }
}
