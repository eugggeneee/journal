import 'package:material_ui/material_ui.dart';

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

/// Карточка одной пары в ленте дня: номер, предмет, аудитория и преподаватель, пропуск и пометка.
/// Время пары вынесено на ленту слева, поэтому в самой карточке остаётся только перерыв внутри пары.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.slot,
    required this.date,
    required this.store,
    this.isNow = false,
  });
  final LessonSlot slot;
  final DateTime date;
  final AppStore store;

  /// Пара идёт прямо сейчас.
  final bool isNow;

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
    final mark = store.markFor(date, slot.number);
    final bell = store.bellFor(date, slot.number);
    final base = isNow ? Tone(cs.primary, cs.onPrimary) : Tone(cs.primaryContainer, cs.onPrimaryContainer);
    final tone = absence == null ? base : absenceTone(context, excused: absence.excused);
    final title = slot.subjects.map(store.subjectName).join(' / ');
    final lines = [
      for (final e in slot.entries) [roomText(e.room), e.teacher].where((x) => x.isNotEmpty).join(' · '),
    ].where((x) => x.isNotEmpty).toList();
    // Идущая пара чуть плотнее окрашена, чтобы взгляд находил её сразу.
    final Color? cardColor = absence != null
        ? tone.bg.withValues(alpha: 0.55)
        : (isNow ? cs.primaryContainer.withValues(alpha: 0.5) : null);
    final ring = Color.alphaBlend(cardColor ?? cs.surfaceContainerLow, cs.surfaceContainerLow);

    return SegmentCard(
      index: 0,
      count: 1,
      appear: false,
      color: cardColor,
      onTap: () => showLessonSheet(context, date, slot),
      onLongPress: () => toggleLessonAbsence(context, store, date, slot),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 2, 14),
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
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              if (bell != null && bell.hasBreak)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _InnerBreak(bell: bell, active: isNow && _inBreak(bell)),
                ),
            ]),
          ),
          IconButton(
            tooltip: absence == null ? 'Отметить пропуск' : 'Снять пропуск',
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            icon: AnimatedSwitcher(
              duration: context.motion(Motion.short),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
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
    );
  }
}

/// Перерыв внутри пары: «Обед 12:35–12:40». Во время перерыва подсвечивается.
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
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(bell.lunchInside ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 14, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${word[0].toUpperCase()}${word.substring(1)} ${shortRange(bell.breakStart!, bell.breakEnd!)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.tt.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ]),
    );
  }
}
