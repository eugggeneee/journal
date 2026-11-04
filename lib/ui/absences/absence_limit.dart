import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/reveal.dart';
import '../kit/widgets.dart';
import '../scope.dart';

/// Предупреждения о лимитах над счётчиками.
///
/// Месяц: с 7 часов без уважительной причины — «лимит близко», с 10 — «лимит достигнут» (его можно скрыть крестиком до конца месяца).
/// Семестр: с 62 часов — «лимит близко», с 72 — «лимит достигнут»; оба скрываются крестиком до следующего уровня.
/// С нового месяца (или семестра) счётчики начинаются заново, скрытые предупреждения возвращаются сами.
class LimitBanners extends StatelessWidget {
  const LimitBanners({super.key, required this.monthHours, required this.semesterHours, required this.semester});
  final int monthHours;
  final int semesterHours;
  final Semester semester;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final monthKeyStr = monthDismissKey(now);
    final semKeyStr = semesterDismissKey(semester);

    final monthLevel = limitLevel(monthHours, warnFrom: kMonthWarnFrom, limit: kMonthLimit);
    final semLevel = limitLevel(semesterHours, warnFrom: kSemesterWarnFrom, limit: kSemesterLimit);

    final items = <Widget>[];

    // Месяц: «близко» без крестика (его нельзя скрыть), «достигнут» — со скрытием.
    if (monthLevel == LimitLevel.near) {
      items.add(_Banner(
        key: ValueKey('m-near-$monthHours'),
        kind: _BannerKind.near,
        title: 'Лимит месяца близко',
        text: 'За ${_monthName(now)} осталось ${hoursText(kMonthLimit - monthHours)} без уважительной причины',
      ));
    } else if (monthLevel == LimitLevel.reached && store.dismissedLevel(monthKeyStr) < LimitLevel.reached.index) {
      items.add(_Banner(
        key: ValueKey('m-reached-$monthHours'),
        kind: _BannerKind.reached,
        title: 'Лимит месяца',
        text: monthHours == kMonthLimit
            ? 'Набрано ${hoursText(monthHours)} без уважительной причины за ${_monthName(now)}'
            : 'Набрано ${hoursText(monthHours)} без уважительной причины — лимит $kMonthLimit ч превышен',
        onClose: () => _dismiss(context, store, monthKeyStr, LimitLevel.reached.index),
      ));
    }

    if (semLevel != LimitLevel.ok && !semester.upcoming && store.dismissedLevel(semKeyStr) < semLevel.index) {
      final reached = semLevel == LimitLevel.reached;
      items.add(_Banner(
        key: ValueKey('s-${semLevel.name}-$semesterHours'),
        kind: reached ? _BannerKind.reached : _BannerKind.near,
        title: reached ? 'Лимит семестра' : 'Лимит семестра близко',
        text: reached
            ? (semesterHours == kSemesterLimit
                ? 'Набрано ${hoursText(semesterHours)} без уважительной причины за ${semester.title.toLowerCase()}'
                : 'Набрано ${hoursText(semesterHours)} без уважительной причины — лимит $kSemesterLimit ч превышен')
            : 'За ${semester.title.toLowerCase()} осталось ${hoursText(kSemesterLimit - semesterHours)} без уважительной причины',
        onClose: () => _dismiss(context, store, semKeyStr, semLevel.index),
      ));
    }

    return Smooth(
      child: items.isEmpty
          ? const SizedBox(key: ValueKey('banners-none'), width: double.infinity)
          : Column(
              key: ValueKey(items.map((e) => e.key.toString()).join('|')),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
    );
  }

  void _dismiss(BuildContext context, AppStore store, String key, int level) {
    final messenger = ScaffoldMessenger.of(context);
    final previous = store.dismissedLevel(key);
    Haptics.selection();
    store.dismissLimit(key, level);
    showUndo(messenger, 'Предупреждение скрыто', () => store.undoDismissLimit(key, previous));
  }

  /// «ноябрь» (в сочетании «за ноябрь» форма не меняется).
  static String _monthName(DateTime d) => monthYear(d).split(' ').first.toLowerCase();
}

enum _BannerKind { near, reached }

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.kind, required this.title, required this.text, this.onClose});
  final _BannerKind kind;
  final String title;
  final String text;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final reached = kind == _BannerKind.reached;
    final accent = absenceAccent(context, excused: false);
    final tone = warnTone(context);
    final bg = reached ? accent : tone.bg;
    final fg = reached ? onColorFor(accent) : tone.fg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: '$title. $text',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
          child: Row(children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: reached ? fg : warnAccent(context), shape: BoxShape.circle),
                child: Icon(
                  reached ? Icons.priority_high_rounded : Icons.hourglass_bottom_rounded,
                  size: 28,
                  color: reached ? accent : onColorFor(warnAccent(context)),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(text, style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.92), height: 1.3)),
              ]),
            ),
            if (onClose != null)
              IconButton(
                tooltip: 'Скрыть',
                icon: Icon(Icons.close_rounded, color: fg),
                onPressed: onClose,
              )
            else
              const SizedBox(width: 10),
          ]),
        ),
      ),
    );
  }
}

/// Два счётчика друг под другом, в том же стиле, что и пары в расписании:
/// пропуски без уважительной причины за месяц и за семестр.
class LimitCounters extends StatelessWidget {
  const LimitCounters({super.key, required this.monthHours, required this.semesterHours, required this.semester, required this.onSemesterTap});
  final int monthHours;
  final int semesterHours;
  final Semester semester;
  final VoidCallback onSemesterTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final semSubtitle = semester.upcoming ? 'Каникулы · с 1 сентября' : '${semester.title} · ${semester.years}';
    return Column(children: [
      LimitCard(
        index: 0,
        count: 2,
        icon: Icons.calendar_month_rounded,
        title: 'За месяц',
        subtitle: monthYear(now),
        hours: monthHours,
        limit: kMonthLimit,
        warnFrom: kMonthWarnFrom,
      ),
      LimitCard(
        index: 1,
        count: 2,
        icon: Icons.school_rounded,
        title: 'За семестр',
        subtitle: semSubtitle,
        hours: semesterHours,
        limit: kSemesterLimit,
        warnFrom: kSemesterWarnFrom,
        onTap: onSemesterTap,
      ),
    ]);
  }
}

/// Карточка-счётчик: кольцо с числом часов, период, сколько осталось до лимита и полоса прогресса.
class LimitCard extends StatelessWidget {
  const LimitCard({
    super.key,
    required this.index,
    required this.count,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.hours,
    required this.limit,
    required this.warnFrom,
    this.onTap,
  });
  final int index;
  final int count;
  final IconData icon;
  final String title;
  final String subtitle;
  final int hours;
  final int limit;
  final int warnFrom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final level = limitLevel(hours, warnFrom: warnFrom, limit: limit);
    final Tone tone;
    final Color accent;
    switch (level) {
      case LimitLevel.reached:
        tone = absenceTone(context, excused: false);
        accent = absenceAccent(context, excused: false);
      case LimitLevel.near:
        tone = warnTone(context);
        accent = warnAccent(context);
      case LimitLevel.ok:
        tone = Tone(cs.surfaceContainerLow, cs.onSurface);
        accent = cs.primary;
    }
    final left = limit - hours;
    final status = level == LimitLevel.reached
        ? (hours == limit ? 'Лимит достигнут' : 'Превышено на ${hoursText(hours - limit)}')
        : 'Осталось ${hoursText(left)}';
    final muted = tone.fg.withValues(alpha: 0.78);
    return Semantics(
      container: true,
      label: '$title, $subtitle: $hours из $limit часов без уважительной причины. $status',
      child: SegmentCard(
        index: index,
        count: count,
        color: tone.bg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(children: [
            SizedBox(
              width: 62,
              height: 62,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: limit == 0 ? 0 : hours / limit),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CustomPaint(
                  painter: _RingPainter(progress: v, color: accent, track: tone.fg.withValues(alpha: 0.14), stroke: 7),
                  child: Center(
                    child: AnimatedNumber(
                      value: hours.toDouble(),
                      format: (x) => '${x.round()}',
                      style: context.tt.titleLarge?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(icon, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 1),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall?.copyWith(color: muted)),
                const SizedBox(height: 6),
                Text('$status · из $limit ч', style: context.tt.bodyMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (onTap != null) Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    paint.color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    paint.color = color;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track || old.stroke != stroke;
}
