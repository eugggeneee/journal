import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/overview.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'lesson_card.dart';

/// Карточка «Сейчас» над лентой дня: что идёт, сколько осталось и что будет дальше.
/// Меняет цвет и содержание вместе с фазой дня: пара, перерыв, обед, до начала, после занятий.
class NowCard extends StatelessWidget {
  const NowCard({super.key, required this.clock, required this.slots, required this.profile, required this.store});
  final DayClock clock;
  final List<LessonSlot> slots;
  final BellProfile profile;
  final AppStore store;

  LessonSlot? _slot(int? n) {
    if (n == null) return null;
    for (final s in slots) {
      if (s.number == n) return s;
    }
    return null;
  }

  String _title(LessonSlot s) => s.subjects.map(store.subjectName).join(' / ');

  String _place(LessonSlot s) => [
        for (final e in s.entries) [LessonCard.roomText(e.room), e.teacher].where((x) => x.isNotEmpty).join(' · '),
      ].where((x) => x.isNotEmpty).join(' / ');

  static String _big(int m) => m >= 60 ? '${m ~/ 60} ч ${m % 60}' : '$m';

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final cur = _slot(clock.pair);
    final next = _slot(clock.next);
    final curBell = clock.pair == null ? null : profile[clock.pair!];
    final nextBell = clock.next == null ? null : profile[clock.next!];

    var tone = Tone(cs.primaryContainer, cs.onPrimaryContainer);
    var accent = cs.primary;
    String caption = '';
    String? range;
    String title = '';
    String sub = '';
    String? lead;
    int? left;
    double? progress;

    switch (clock.phase) {
      case DayPhase.none:
        return const SizedBox.shrink();
      case DayPhase.lesson:
        if (cur == null || curBell == null) return const SizedBox.shrink();
        caption = 'Идёт сейчас · ${cur.number} пара';
        range = shortRange(curBell.start, curBell.end);
        title = _title(cur);
        sub = _place(cur);
        lead = 'до конца';
        left = clock.left;
        progress = clock.progress;
      case DayPhase.innerBreak:
        if (cur == null || curBell == null) return const SizedBox.shrink();
        final word = innerBreakWord(curBell);
        tone = curBell.lunchInside ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
        accent = curBell.lunchInside ? cs.tertiary : cs.secondary;
        caption = '${word[0].toUpperCase()}${word.substring(1)} внутри ${cur.number} пары';
        range = shortRange(curBell.breakStart!, curBell.breakEnd!);
        title = _title(cur);
        sub = 'Дальше вторая половина в ${fmtMin(curBell.breakEnd!)}';
        lead = 'до конца';
        left = clock.left;
        progress = clock.progress;
      case DayPhase.gap:
        if (next == null || nextBell == null || curBell == null) return const SizedBox.shrink();
        final lunch = clock.pair != null && profile.isLunchAfter(clock.pair!);
        final window = next.number - (clock.pair ?? next.number) > 1;
        tone = lunch ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.secondaryContainer, cs.onSecondaryContainer);
        accent = lunch ? cs.tertiary : cs.secondary;
        caption = lunch ? 'Обед' : (window ? 'Окно' : 'Перерыв');
        range = shortRange(curBell.end, nextBell.start);
        title = 'Дальше: ${_title(next)}';
        sub = [
          '${next.number} пара в ${fmtMin(nextBell.start)}',
          _place(next),
        ].where((x) => x.isNotEmpty).join(' · ');
        lead = 'через';
        left = clock.left;
        progress = clock.progress;
      case DayPhase.before:
        if (next == null || nextBell == null) return const SizedBox.shrink();
        tone = Tone(cs.secondaryContainer, cs.onSecondaryContainer);
        accent = cs.secondary;
        caption = 'Скоро начало';
        range = fmtMin(nextBell.start);
        title = 'Первая пара: ${_title(next)}';
        sub = [
          '${next.number} пара',
          _place(next),
        ].where((x) => x.isNotEmpty).join(' · ');
        lead = 'через';
        left = clock.left;
      case DayPhase.after:
        tone = Tone(cs.tertiaryContainer, cs.onTertiaryContainer);
        accent = cs.tertiary;
        caption = 'На сегодня всё';
        range = curBell == null ? null : fmtMin(curBell.end);
        title = 'Пары закончились';
        sub = curBell == null ? '' : 'Последняя закончилась в ${fmtMin(curBell.end)}';
    }

    final fg = tone.fg;
    final key = '${clock.phase.name}-${clock.pair}-${clock.next}';
    final content = Column(
      key: ValueKey(key),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700))),
          if (range != null)
            Text(range, style: context.tt.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
        const SizedBox(height: 8),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.headlineSmall?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.15)),
        if (sub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.85))),
          ),
        if (left != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text('$lead ', style: context.tt.titleMedium?.copyWith(color: fg)),
              AnimatedNumber(
                value: left.toDouble(),
                format: (v) => _big(v.round()),
                style: context.tt.displaySmall?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.05),
              ),
              Text(' мин', style: context.tt.titleMedium?.copyWith(color: fg)),
            ]),
          ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: context.motion(Motion.long),
              curve: Motion.standard,
              builder: (context, v, _) => Bar(value: v, color: accent, height: 10, track: fg.withValues(alpha: 0.14)),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HeroCard(tone: tone, child: Smooth(child: content)),
    );
  }
}
