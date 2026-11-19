import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';
import '../settings/bells_sheet.dart';
import '../settings/group_picker.dart';
import '../../data/models.dart';
import '../absences/absence_actions.dart';
import '../grades/grade_sheet.dart';
import '../kit/sheets/select_sheet.dart';
import 'calendar_grid.dart';
import 'day_actions.dart';
import 'marks.dart';
import 'day_view.dart';
import 'week_view.dart';

/// Открывает выбранную дату из других вкладок.
class ScheduleController extends ChangeNotifier {
  DateTime selected = today();
  void Function(DateTime)? _jump;

  /// День, который попросили открыть до того, как страница расписания построилась.
  DateTime? _pending;

  void attach(void Function(DateTime) jump) {
    _jump = jump;
    final p = _pending;
    _pending = null;
    if (p != null) WidgetsBinding.instance.addPostFrameCallback((_) => jump(p));
  }

  void detach() => _jump = null;

  void setSelected(DateTime d) {
    if (sameDay(selected, d)) return;
    selected = d;
    notifyListeners();
  }

  void jumpTo(DateTime d) {
    final j = _jump;
    if (j == null) {
      _pending = d;
    } else {
      j(d);
    }
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.controller});
  final ScheduleController controller;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with WidgetsBindingObserver {
  static final _first = DateTime(2020);
  static final _last = DateTime(2100);
  int get _back => dayDiff(_base, _first);
  int get _total => dayDiff(_last, _first) + 1;
  int _refresh = 0;
  bool _wasWeek = false;
  int _weekIndex(int dayIndex) => (dayIndex + _first.weekday - 1) ~/ 7;

  late DateTime _base = today();
  late PageController _pc = PageController(keepPage: false, initialPage: _back);
  late final _strip = PageController(keepPage: false, initialPage: _weekIndex(_back));
  late DateTime _selected = _base;

  DateTime _dateAt(int i) => addDays(_first, i);
  int _indexOf(DateTime d) => dayDiff(d, _first).clamp(0, _total - 1).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.attach(_jumpTo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.setSelected(_selected);
      _centerStrip(_indexOf(_selected));
    });
  }

  @override
  void dispose() {
    widget.controller.detach();
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    _strip.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    StoreScope.repoOf(context).prefetch();
    if (!sameDay(_base, today())) {
      final old = _pc;
      setState(() {
        _base = today();
        _selected = _base;
        _pc = PageController(keepPage: false, initialPage: _back);
      });
      widget.controller.setSelected(_selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        _centerStrip(_indexOf(_selected));
      });
    }
  }

  /// Неделя включена и экран достаточно широк (от 720 dp), иначе всегда один день.
  bool get _weekMode => mounted && MediaQuery.sizeOf(context).width >= 720 && StoreScope.of(context).settings.weekView;

  /// После возврата к одному дню страница и лента дат снова ставятся на выбранный день.
  void _restoreDayPage() {
    final i = _indexOf(_selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pc.hasClients) _pc.jumpToPage(i);
      _centerStrip(i);
    });
  }

  void _shiftWeek(int weeks) {
    Haptics.selection();
    setState(() => _selected = _dateAt(_indexOf(addDays(_selected, 7 * weeks))));
    widget.controller.setSelected(_selected);
  }

  void _openFromWeek(DateTime d) {
    setState(() => _selected = dateOnly(d));
    widget.controller.setSelected(_selected);
    StoreScope.of(context).setWeekView(false);
  }

  void _jumpTo(DateTime d) {
    if (_weekMode) {
      setState(() => _selected = dateOnly(d));
      widget.controller.setSelected(_selected);
      return;
    }
    if (!_pc.hasClients) return;
    final idx = _indexOf(d);
    final cur = (_pc.page ?? idx.toDouble()).round();
    if (idx == cur) return;
    if ((idx - cur).abs() > 3 || context.reduceMotion) {
      _pc.jumpToPage(idx);
    } else {
      _pc.animateToPage(idx, duration: Motion.page, curve: Motion.emphasized);
    }
  }

  void _centerStrip(int index) {
    final week = _weekIndex(index);
    if (_strip.hasClients && _strip.page?.round() != week) _strip.jumpToPage(week);
  }

  void _menu(bool week) {
    final store = StoreScope.of(context);
    final date = _selected;
    final slots = store.cachedSchedule(store.settings.group, date)?.slots ?? const <LessonSlot>[];
    final mark = store.markFor(date, 0);
    final allAbsent = slots.isNotEmpty && slots.every((s) => store.absenceFor(date, s.number) != null);
    final options = <(String, IconData, String, VoidCallback)>[
      if (!week) ...[
        ('Добавить оценку', Icons.star_outline_rounded, 'На выбранную дату', () => showGradeSheet(context, date: date)),
        (
          'Пометка на день',
          Icons.bookmark_add_outlined,
          'На выбранную дату',
          () => showMarkSheet(context, date, edit: mark),
        ),
        if (slots.isNotEmpty)
          (
            allAbsent ? 'Снять пропуски за день' : 'Отметить пропуск всего дня',
            Icons.event_busy_outlined,
            'На выбранную дату',
            () => toggleWholeDay(context, store, date, slots),
          ),
        (
          mark?.label == kShortDayMark ? 'Вернуть обычные звонки' : 'Сокращённый день',
          Icons.timelapse_rounded,
          'На выбранную дату',
          () => toggleShortDay(context, store, date),
        ),
        (
          'Звонки на этот день',
          Icons.notifications_none_rounded,
          'На выбранную дату',
          () => showBellsSheet(context, date),
        ),
      ],
      ('Обновить расписание', Icons.refresh_rounded, 'Расписание', () => setState(() => _refresh++)),
      ('Сменить группу', Icons.groups_outlined, 'Расписание', () => openGroupPicker(context)),
    ];
    showSelectSheet<int>(
      context,
      title: week ? 'Неделя' : longDate(date),
      subtitle: 'Группа ${store.settings.group}',
      options: [
        for (var i = 0; i < options.length; i++)
          MenuOption(i, options[i].$1, icon: options[i].$2, section: options[i].$3),
      ],
      onSelected: (i) => options[i].$4(),
    );
  }

  Future<void> _pickDate() async {
    final d = await pickDay(context, _selected);
    if (mounted && d != null) _jumpTo(dateOnly(d));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final marked = <String>{for (final a in store.absences) ymd(a.date)};
    final noted = <String>{for (final m in store.marks) ymd(m.date)};
    final isToday = sameDay(_selected, today());
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final week = wide && store.settings.weekView;
    if (_wasWeek && !week) _restoreDayPage();
    _wasWeek = week;
    final cs = context.cs;
    final header = SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: 'Выбрать дату',
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Расписание · ${store.settings.group}',
                          style: context.tt.labelLarge?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  monthYear(_selected),
                                  style: context.tt.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isToday)
              IconButton(tooltip: 'Сегодня', icon: const Icon(Icons.today_rounded), onPressed: () => _jumpTo(today())),
            if (wide)
              IconButton(
                tooltip: week ? 'Показать день' : 'Показать неделю',
                icon: Icon(week ? Icons.view_day_outlined : Icons.view_week_outlined),
                onPressed: () => store.setWeekView(!week),
              ),
            IconButton(tooltip: 'Ещё', icon: const Icon(Icons.more_horiz_rounded), onPressed: () => _menu(week)),
          ],
        ),
      ),
    );

    final strip = SizedBox(
      height: 64,
      child: PageView.builder(
        controller: _strip,
        itemCount: _weekIndex(_total - 1) + 1,
        onPageChanged: (w) {
          if (w == _weekIndex(_indexOf(_selected))) return;
          final index = w * 7 - (_first.weekday - 1) + _selected.weekday - 1;
          _jumpTo(_dateAt(index.clamp(0, _total - 1)));
        },
        itemBuilder: (context, w) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final index = w * 7 + i - (_first.weekday - 1);
                      if (index < 0 || index >= _total) return const SizedBox.shrink();
                      final d = _dateAt(index);
                      return CalendarDate(
                        date: d,
                        selected: sameDay(d, _selected),
                        marked: marked.contains(ymd(d)) || noted.contains(ymd(d)),
                        onTap: () => _jumpTo(d),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final pages = PageView.builder(
      controller: _pc,
      itemCount: _total,
      onPageChanged: (i) {
        Haptics.selection();
        setState(() => _selected = _dateAt(i));
        widget.controller.setSelected(_selected);
        _centerStrip(i);
      },
      itemBuilder: (context, i) {
        final d = _dateAt(i);
        return DayView(key: ValueKey('${ymd(d)}|${store.settings.group}'), date: d, refresh: _refresh, onJump: _jumpTo);
      },
    );

    return ContentFrame(
      maxWidth: week ? 1440 : 840,
      child: Column(
        children: [
          header,
          if (week)
            Expanded(
              child: WeekView(refresh: _refresh, selected: _selected, onShift: _shiftWeek, onOpenDay: _openFromWeek),
            )
          else ...[
            // Лента дат всегда на виду: прокрутка дня её не трогает.
            strip,
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: .6)),
            Expanded(child: pages),
          ],
        ],
      ),
    );
  }
}
