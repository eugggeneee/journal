import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/overview.dart';
import '../kit/foundation/ctx.dart';

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

    if (monthLevel == LimitLevel.reached && store.dismissedLevel(monthKeyStr) < LimitLevel.reached.index) {
      items.add(
        _Banner(
          key: ValueKey('m-reached-$monthHours'),
          kind: _BannerKind.reached,
          title: 'Лимит месяца',
          text: monthHours == kMonthLimit
              ? 'Набрано ${hoursText(monthHours)} без уважительной причины за ${_monthName(now)}'
              : 'Набрано ${hoursText(monthHours)} без уважительной причины — лимит $kMonthLimit ч превышен',
          onClose: () => _dismiss(context, store, monthKeyStr, LimitLevel.reached.index),
        ),
      );
    }

    if (semLevel != LimitLevel.ok && !semester.upcoming && store.dismissedLevel(semKeyStr) < semLevel.index) {
      final reached = semLevel == LimitLevel.reached;
      items.add(
        _Banner(
          key: ValueKey('s-${semLevel.name}-$semesterHours'),
          kind: reached ? _BannerKind.reached : _BannerKind.near,
          title: reached ? 'Лимит семестра' : 'Лимит семестра близко',
          text: reached
              ? (semesterHours == kSemesterLimit
                    ? 'Набрано ${hoursText(semesterHours)} без уважительной причины за ${semester.title.toLowerCase()}'
                    : 'Набрано ${hoursText(semesterHours)} без уважительной причины — лимит $kSemesterLimit ч превышен')
              : 'За ${semester.title.toLowerCase()} осталось ${hoursText(kSemesterLimit - semesterHours)} без уважительной причины',
          onClose: () => _dismiss(context, store, semKeyStr, semLevel.index),
        ),
      );
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
    final tone = reached ? absenceTone(context, excused: false) : warnTone(context);
    final accent = reached ? absenceAccent(context, excused: false) : warnAccent(context);
    final bg = tone.bg;
    final fg = tone.fg;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        label: '$title. $text',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.5, end: 1),
                duration: Motion.ms(650),
                curve: Motion.spring,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(
                    reached ? Icons.priority_high_rounded : Icons.hourglass_bottom_rounded,
                    size: 28,
                    color: onColorFor(accent),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.92), height: 1.3)),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Скрыть',
                  icon: Icon(Icons.close_rounded, color: fg),
                  onPressed: onClose,
                )
              else
                const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Два счётчика друг под другом, в том же стиле, что и пары в расписании:
/// пропуски без уважительной причины за месяц и за семестр.
class LimitCounters extends StatelessWidget {
  const LimitCounters({
    super.key,
    required this.monthHours,
    required this.semesterHours,
    required this.semester,
    required this.onSemesterTap,
  });
  final int monthHours;
  final int semesterHours;
  final Semester semester;
  final VoidCallback onSemesterTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final semSubtitle = semester.upcoming ? 'Каникулы · с 1 сентября' : '${semester.title} · ${semester.years}';
    final tone = Tone(context.cs.primaryContainer, context.cs.onPrimaryContainer);
    final month = _LimitGauge(
      title: 'За месяц',
      subtitle: monthYear(now),
      hours: monthHours,
      limit: kMonthLimit,
      warnFrom: kMonthWarnFrom,
    );
    final term = _LimitGauge(
      title: 'За семестр',
      subtitle: semSubtitle,
      hours: semesterHours,
      limit: kSemesterLimit,
      warnFrom: kSemesterWarnFrom,
      onTap: onSemesterTap,
    );
    return HeroCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Запас часов',
            style: context.tt.headlineSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w800),
          ),
          Text('Без уважительной причины', style: context.tt.bodyMedium?.copyWith(color: tone.fg)),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              if (box.maxWidth < MediaQuery.textScalerOf(context).scale(245)) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [month, const SizedBox(height: 4), term],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: month),
                    const SizedBox(width: 4),
                    Expanded(child: term),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LimitGauge extends StatelessWidget {
  const _LimitGauge({
    required this.title,
    required this.subtitle,
    required this.hours,
    required this.limit,
    required this.warnFrom,
    this.onTap,
  });
  final String title, subtitle;
  final int hours, limit, warnFrom;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final level = limitLevel(hours, warnFrom: warnFrom, limit: limit);
    final tone = switch (level) {
      LimitLevel.reached => absenceTone(context, excused: false),
      LimitLevel.near => warnTone(context),
      LimitLevel.ok => Tone(cs.surfaceContainerLow, cs.onSurface),
    };
    final remaining = math.max(0, limit - hours);
    final status = hours > limit
        ? 'Превышено на ${hoursText(hours - limit)}'
        : hours == limit
        ? 'Лимит достигнут'
        : level == LimitLevel.near
        ? 'Близко к лимиту'
        : 'Осталось часов';
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: context.tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w700),
              ),
              if (onTap != null) Icon(Icons.expand_more_rounded, color: tone.fg, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox.square(
            dimension: 72,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: remaining / limit),
              duration: context.motion(Motion.medium),
              curve: Motion.standard,
              builder: (context, progress, child) => CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  color: level == LimitLevel.ok ? cs.primary : tone.fg,
                  track: tone.fg.withValues(alpha: .15),
                  stroke: 6,
                ),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$remaining',
                    style: context.tt.headlineMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            textAlign: TextAlign.center,
            style: context.tt.labelLarge?.copyWith(color: tone.fg),
          ),
          Text(
            '$hours из $limit ч',
            textAlign: TextAlign.center,
            style: context.tt.bodySmall?.copyWith(color: tone.fg),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.tt.labelSmall?.copyWith(color: tone.fg),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: '$title, $subtitle. Осталось ${hoursText(remaining)}, использовано $hours из $limit. $status',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: tone.bg,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(JournalLayout.panelRadius),
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
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
