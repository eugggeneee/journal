import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

/// Расписание дня в виде повестки (как «Расписание» в Google Календаре): слева время начала, конца и
/// длительность, справа цветная карточка пары со всеми подробностями, между парами строки перерывов,
/// обеда и окон. Идущая пара залита цветом и показывает прогресс, идущий перерыв заполняется по мере
/// того, как проходит время, а прошедшие пары приглушены.
class DayAgenda extends StatelessWidget {
  const DayAgenda({super.key, required this.date, required this.slots, required this.store});
  final DateTime date;
  final List<LessonSlot> slots;
  final AppStore store;

  static const double _timeW = 54;

  @override
  Widget build(BuildContext context) {
    final profile = store.bellProfileFor(date);
    final now = DateTime.now();
    final minute = now.hour * 60 + now.minute;
    final diff = dayDiff(date, today());
    final isToday = diff == 0;
    final hasTimes = slots.any((s) => profile[s.number] != null);
    final timeW = hasTimes ? _timeW : 0.0;

    // Ближайшая пара, которая ещё не началась: у неё подпись «Дальше · через …».
    int? nextIndex;
    if (isToday) {
      for (var i = 0; i < slots.length; i++) {
        final b = profile[slots[i].number];
        if (b != null && minute < b.start) {
          nextIndex = i;
          break;
        }
      }
    }

    final rows = <Widget>[];
    var k = 0;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final bell = profile[slot.number];
      final phase = _phase(diff, minute, bell);
      final double fill = switch (phase) {
        _Ph.past => 1,
        _Ph.now => bell == null ? 0 : ((minute - bell.start) / bell.minutes).clamp(0.0, 1.0).toDouble(),
        _Ph.future => 0,
      };

      if (i > 0) {
        final prev = slots[i - 1];
        final label = gapBetween(profile, prev.number, slot.number);
        if (label != null) {
          final a = profile[prev.number];
          final b = bell;
          var gapFill = 0.0;
          var active = false;
          if (diff < 0) {
            gapFill = 1;
          } else if (isToday && a != null && b != null) {
            if (minute >= b.start) {
              gapFill = 1;
            } else if (minute >= a.end) {
              active = true;
              gapFill = ((minute - a.end) / (b.start - a.end)).clamp(0.0, 1.0).toDouble();
            }
          }
          rows.add(Appear(
            index: k++,
            child: Padding(
              padding: EdgeInsets.only(left: timeW, top: 6, bottom: 6),
              child: _BreakRow(
                label: label,
                range: (a != null && b != null) ? shortRange(a.end, b.start) : null,
                lunch: label.startsWith('Обед'),
                window: label.startsWith('Окно'),
                active: active,
                fill: gapFill,
                dim: isToday && gapFill >= 1,
              ),
            ),
          ));
        } else {
          rows.add(const SizedBox(height: 8));
        }
      }

      final lp = phase == _Ph.now
          ? LessonPhase.now
          : (phase == _Ph.past ? LessonPhase.past : (i == nextIndex ? LessonPhase.next : LessonPhase.later));
      final dim = isToday && phase == _Ph.past;
      rows.add(Appear(
        index: k++,
        child: AnimatedOpacity(
          opacity: dim ? 0.62 : 1,
          duration: context.motion(Motion.medium),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (hasTimes)
              SizedBox(
                width: timeW,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, right: 8),
                  child: _TimeColumn(bell: bell, current: phase == _Ph.now),
                ),
              ),
            Expanded(
              child: LessonCard(
                slot: slot,
                date: date,
                store: store,
                phase: lp,
                minutes: bell == null ? null : (phase == _Ph.now ? bell.end - minute : (i == nextIndex ? bell.start - minute : null)),
                progress: fill,
              ),
            ),
          ]),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }

  /// Где пара относительно «сейчас»: прошедшие дни целиком позади, будущие впереди.
  static _Ph _phase(int diff, int minute, BellSlot? bell) {
    if (diff < 0) return _Ph.past;
    if (diff > 0 || bell == null) return _Ph.future;
    if (minute >= bell.end) return _Ph.past;
    if (minute >= bell.start) return _Ph.now;
    return _Ph.future;
  }
}

enum _Ph { past, now, future }

/// Время пары слева: начало крупно, конец и длительность мельче. У идущей пары начало цветное.
class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.bell, required this.current});
  final BellSlot? bell;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final b = bell;
    if (b == null) return const SizedBox.shrink();
    final cs = context.cs;
    const figures = [FontFeature.tabularFigures()];
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topRight,
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(
          fmtMin(b.start),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 16, height: 1.2, fontWeight: FontWeight.w800, fontFeatures: figures, color: current ? cs.primary : cs.onSurface),
        ),
        Text(
          fmtMin(b.end),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, fontFeatures: figures, color: cs.onSurfaceVariant),
        ),
        Text(
          minText(b.minutes),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(fontSize: 11, height: 1.4, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant.withValues(alpha: 0.8)),
        ),
      ]),
    );
  }
}

/// Перерыв, обед или окно между парами: плашка по ширине карточек. Идущий перерыв заполняется слева направо.
class _BreakRow extends StatelessWidget {
  const _BreakRow({required this.label, required this.range, required this.lunch, required this.window, required this.active, required this.fill, required this.dim});
  final String label;
  final String? range;
  final bool lunch;
  final bool window;
  final bool active;
  final double fill;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final accent = lunch ? cs.tertiary : cs.secondary;
    final bg = lunch ? cs.tertiaryContainer : cs.surfaceContainerHigh;
    final fg = lunch ? cs.onTertiaryContainer : cs.onSurfaceVariant;
    final icon = lunch ? Icons.restaurant_rounded : (window ? Icons.hourglass_empty_rounded : Icons.coffee_rounded);
    return AnimatedOpacity(
      opacity: dim ? 0.62 : 1,
      duration: context.motion(Motion.medium),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: bg)),
          if (active)
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: fill),
                duration: context.motion(Motion.long),
                curve: Motion.standard,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v.clamp(0.0, 1.0).toDouble(),
                  child: ColoredBox(color: accent.withValues(alpha: 0.24)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Icon(icon, size: 18, color: active ? accent : fg),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700))),
              if (range != null)
                Text(
                  range!,
                  maxLines: 1,
                  softWrap: false,
                  style: context.tt.labelMedium?.copyWith(color: fg.withValues(alpha: 0.85), fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
