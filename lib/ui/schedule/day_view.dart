import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/schedule/schedule_service.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'day_actions.dart';
import 'day_timeline.dart';
import 'marks.dart';
import 'rest_day.dart';

/// Один день расписания: панель дня, лента пар и состояния без пар.
class DayView extends StatefulWidget {
  const DayView({super.key, required this.date, this.refresh = 0, required this.onJump});
  final DateTime date;
  final int refresh;

  /// Открыть другой день (например, ближайший учебный из карточки выходного).
  final ValueChanged<DateTime> onJump;

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  DayState? _st;
  bool _started = false;
  int _gen = 0;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Сегодня: раз в полминуты обновляем карточку «Сейчас» и шкалу дня.
    if (sameDay(widget.date, today())) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(DayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refresh != oldWidget.refresh) _load(force: true);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load({bool force = false}) async {
    final store = StoreScope.of(context);
    final repo = StoreScope.repoOf(context);
    final gen = ++_gen;
    final cached = store.cachedSchedule(store.settings.group, widget.date);
    if (cached != null && _st == null) _st = DayState(DayStatus.ok, schedule: cached, fromCache: true);
    final st = await repo.load(widget.date, force: force);
    if (!mounted || gen != _gen) return;
    setState(() => _st = st);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final st = _st;
    final slots = st?.schedule?.slots ?? const <LessonSlot>[];
    final Widget content = st == null
        ? const Padding(key: ValueKey('day-loading'), padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
        : KeyedSubtree(key: ValueKey('day-${st.status.name}'), child: _content(context, store, st));
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, kFabClearance),
        children: [
          if (st != null && st.status != DayStatus.ok) _chips(context),
          MarksSection(date: widget.date, store: store, slots: slots),
          Smooth(child: content),
        ],
      ),
    );
  }

  /// Кнопки дня без пар: пометка (ОКР, зачёт, практика, сокращённый день или своя).
  Widget _chips(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(
            avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Пометка'),
            onPressed: () {
              Haptics.selection();
              showMarkSheet(context, widget.date);
            },
          ),
          ActionChip(
            avatar: const Icon(Icons.timelapse_rounded, size: 18),
            label: const Text('Сокращённый день'),
            onPressed: () => toggleShortDay(context, StoreScope.of(context), widget.date),
          ),
        ]),
      );

  Widget _content(BuildContext context, AppStore store, DayState st) {
    switch (st.status) {
      case DayStatus.ok:
        final s = st.schedule!;
        final date = widget.date;
        final status = st.note ?? (st.fromCache ? 'Сохранено на устройстве' : 'Обновлено в ${hhmm(s.fetchedAt)}');
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DayToolbar(date: date, slots: s.slots, store: store),
          DayTimeline(date: date, slots: s.slots, store: store, now: DateTime.now()),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(status, textAlign: TextAlign.center, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
            ),
          ),
        ]);
      case DayStatus.sunday:
        return RestDay(
          date: widget.date,
          store: store,
          onJump: widget.onJump,
          icon: Icons.wb_sunny_rounded,
          title: 'Выходной',
          message: 'В этот день пар нет, можно отдохнуть.',
          recap: true,
        );
      case DayStatus.noGroup:
        return RestDay(
          date: widget.date,
          store: store,
          onJump: widget.onJump,
          icon: Icons.search_off_rounded,
          title: 'Расписание не найдено',
          message: 'Для группы ${store.settings.group} на эту дату занятий нет.',
        );
      case DayStatus.notPublished:
        final future = !widget.date.isBefore(today());
        return EmptyState(
          icon: Icons.hourglass_empty_rounded,
          title: 'Расписание пока отсутствует',
          message: future
              ? 'Колледж публикует расписание только на ближайшие дни. Потяните вниз, чтобы проверить ещё раз.'
              : 'Этот день не был сохранён на устройстве, а на сайте старые расписания не хранятся.',
        );
      case DayStatus.offline:
      case DayStatus.error:
        return EmptyState(
          icon: st.status == DayStatus.offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
          title: 'Не удалось загрузить',
          message: st.note ?? 'Проверьте подключение и попробуйте ещё раз.',
          action: FilledButton.tonal(onPressed: () => _load(force: true), child: const Text('Повторить')),
        );
    }
  }
}
