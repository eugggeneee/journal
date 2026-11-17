import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../absences/absence_actions.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_sheet.dart';
import 'marks.dart';

/// Где пара относительно «сейчас» (имеет смысл для сегодняшнего дня).
enum LessonPhase { past, now, next, later }

/// Карточка одной пары в ленте дня: номер своего цвета у каждого предмета, название целиком, аудитория
/// и преподаватель, пропуск и пометка. Идущая пара показывает, сколько осталось, и полосу прогресса,
/// ближайшая следующая говорит, через сколько начнётся. Время пары вынесено на ленту слева.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.slot,
    required this.date,
    required this.store,
    this.phase = LessonPhase.later,
    this.minutes,
    this.progress = 0,
  });
  final LessonSlot slot;
  final DateTime date;
  final AppStore store;
  final LessonPhase phase;

  /// Для идущей пары: сколько минут осталось; для следующей: через сколько минут начнётся.
  final int? minutes;

  /// Для идущей пары: какая доля уже прошла (0…1).
  final double progress;

  bool get isNow => phase == LessonPhase.now;

  static String roomText(String r) => r.isEmpty ? '' : (RegExp(r'\d').hasMatch(r) ? 'ауд. $r' : r);

  /// Сейчас идёт перерыв внутри пары.
  bool _inBreak(BellSlot bell) {
    if (!bell.hasBreak) return false;
    final now = DateTime.now();
    final m = now.hour * 60 + now.minute;
    return m >= bell.breakStart! && m < bell.breakEnd!;
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final absence = store.absenceFor(date, slot.number);
    final tasks = store.tasksForLesson(date, slot.number);
    final mark = store.markFor(date, slot.number);
    final bell = store.bellFor(date, slot.number);
    final subjectKey = slot.subjects.isEmpty ? '' : slot.subjects.first;
    final base = hueTone(context, subjectHue(subjectKey));
    final tone = absence == null ? base : absenceTone(context, excused: absence.excused);
    final title = slot.subjects.map(store.subjectName).join(' / ');
    // Аудитория и преподаватель со значками: каждая запись — отдельная строка, части переносятся целиком.
    final lines = [
      for (final e in slot.entries)
        <(IconData, String)>[
          if (e.room.isNotEmpty) (Icons.meeting_room_outlined, roomText(e.room)),
          if (e.teacher.isNotEmpty) (Icons.person_outline_rounded, e.teacher),
        ],
    ].where((x) => x.isNotEmpty).toList();
    // Карточка чуть подкрашена цветом предмета и имеет цветную кромку слева. Идущая пара залита цветом темы,
    // чтобы взгляд находил её сразу, пара с пропуском окрашена в цвет пропуска.
    final accent = hueAccent(context, subjectHue(subjectKey));
    final Color cardColor = absence != null
        ? tone.bg.withValues(alpha: 0.55)
        : (isNow ? cs.primaryContainer : Color.alphaBlend(accent.withValues(alpha: 0.09), cs.surfaceContainerLow));
    final edge = absence != null ? absenceAccent(context, excused: absence.excused) : (isNow ? cs.primary : accent);
    final ring = Color.alphaBlend(cardColor, cs.surfaceContainerLow);

    final hasBreak = bell?.hasBreak ?? false;
    return SegmentCard(
      index: 0,
      count: 1,
      appear: false,
      color: cardColor,
      onTap: () => showLessonSheet(context, date, slot),
      onLongPress: () => toggleLessonAbsence(context, store, date, slot),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: edge, width: 5))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(11, 12, 4, hasBreak ? 8 : 12),
          child: Row(children: [
            // Пропуск — плашка с цифрой на верхнем углу номера пары, пометка — на нижнем краю:
            // размер карточки не меняется.
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(clipBehavior: Clip.none, children: [
                NumberBadge('${slot.number}', tone: tone, size: 46, round: false),
                Positioned(
                  top: -7,
                  right: -7,
                  child: PopIn(
                    token: absence == null ? null : '${absence.hours}-${absence.excused}',
                    child: absence == null ? null : AbsenceBadge(hours: absence.hours, excused: absence.excused, ringColor: ring),
                  ),
                ),
                Positioned(
                  bottom: -9,
                  left: -8,
                  right: -8,
                  child: Center(
                    child: PopIn(
                      token: mark?.label,
                      child: mark == null ? null : MarkTag(label: mark.label, ringColor: ring),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2)),
                for (final parts in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 12, runSpacing: 2, children: [
                      for (final p in parts)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(p.$1, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(child: Text(p.$2, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
                        ]),
                    ]),
                  ),
                for (final t in tasks.take(2))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(t.homework ? Icons.menu_book_rounded : Icons.sticky_note_2_rounded, size: 16, color: t.done ? cs.onSurfaceVariant : cs.tertiary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          t.text,
                          style: context.tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: t.done ? cs.onSurfaceVariant : cs.onSurface,
                            decoration: t.done ? TextDecoration.lineThrough : TextDecoration.none,
                          ),
                        ),
                      ),
                    ]),
                  ),
                if (tasks.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ещё ${tasks.length - 2}', style: context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                if (phase == LessonPhase.now || phase == LessonPhase.next) _StatusRow(phase: phase, minutes: minutes, progress: progress),
              ]),
            ),
            IconButton(
              tooltip: absence == null ? 'Отметить пропуск' : 'Снять пропуск',
              constraints: const BoxConstraints.tightFor(width: 40, height: 44),
              padding: EdgeInsets.zero,
              icon: AnimatedSwitcher(
                duration: context.motion(Motion.short),
                switchInCurve: Motion.spring,
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim.clamped, child: child)),
                child: Icon(
                  absence == null ? Icons.event_busy_outlined : Icons.event_available_rounded,
                  key: ValueKey(absence != null),
                ),
              ),
              color: absence == null ? cs.onSurfaceVariant : tone.fg,
              onPressed: () => toggleLessonAbsence(context, store, date, slot),
            ),
          ]),
        ),
        // Перерыв внутри пары занимает всю ширину карточки: время читается целиком.
        if (bell != null && bell.hasBreak)
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 0, 14, 12),
            child: _InnerBreak(bell: bell, active: isNow && _inBreak(bell)),
          ),
        ]),
      ),
    );
  }
}

/// Статус пары под названием: «Идёт · ещё 40 мин» с полосой прогресса или «Дальше · через 12 мин».
class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.phase, required this.minutes, required this.progress});
  final LessonPhase phase;
  final int? minutes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final now = phase == LessonPhase.now;
    final m = minutes;
    final text = now
        ? (m == null ? 'Идёт сейчас' : 'Идёт · ещё ${spanText(m)}')
        : (m == null ? 'Дальше' : 'Дальше · через ${spanText(m)}');
    final tone = now ? Tone(cs.primary, cs.onPrimary) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (now)
          Container(
            padding: const EdgeInsets.fromLTRB(6, 3, 12, 3),
            decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PulseDot(color: tone.fg, size: 7),
              const SizedBox(width: 2),
              Flexible(child: Text(text, style: context.tt.labelLarge?.copyWith(color: tone.fg, fontWeight: FontWeight.w700))),
            ]),
          )
        else
          Pill(text, tone: tone, icon: Icons.schedule_rounded),
        if (now)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Bar(value: progress.clamp(0.0, 1.0).toDouble(), color: cs.primary, height: 8, track: cs.primary.withValues(alpha: 0.18)),
          ),
      ]),
    );
  }
}

/// Перерыв внутри пары: «Обед» слева и время справа на всю ширину карточки. Во время перерыва подсвечивается.
class _InnerBreak extends StatelessWidget {
  const _InnerBreak({required this.bell, required this.active});
  final BellSlot bell;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final bg = active ? cs.tertiary : cs.tertiaryContainer.withValues(alpha: 0.7);
    final fg = active ? cs.onTertiary : cs.onTertiaryContainer;
    final word = innerBreakWord(bell);
    return AnimatedContainer(
      duration: context.motion(Motion.medium),
      curve: Motion.standard,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(bell.lunchInside ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 16, color: fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${word[0].toUpperCase()}${word.substring(1)}',
            style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          shortRange(bell.breakStart!, bell.breakEnd!),
          maxLines: 1,
          softWrap: false,
          style: context.tt.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ]),
    );
  }
}
