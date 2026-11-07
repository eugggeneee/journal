import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/sheet.dart';
import '../settings/bells_sheet.dart';
import '../settings/group_picker.dart';
import 'day_view.dart';

/// Связывает страницу расписания с оболочкой (выбранная дата нужна кнопке «Добавить»).
class ScheduleController extends ChangeNotifier {
  DateTime selected = today();
  void Function(DateTime)? _jump;

  void attach(void Function(DateTime) jump) => _jump = jump;
  void detach() => _jump = null;

  void setSelected(DateTime d) {
    if (sameDay(selected, d)) return;
    selected = d;
    notifyListeners();
  }

  void jumpTo(DateTime d) => _jump?.call(d);
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.controller});
  final ScheduleController controller;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _back = 120;
  static const _fwd = 90;
  static const _total = _back + _fwd + 1;
  static const _chipW = 60.0;

  late DateTime _base = today();
  late PageController _pc = PageController(initialPage: _back);
  final ScrollController _strip = ScrollController();
  late DateTime _selected = _base;

  // Прокрутка вниз прячет месяц и ленту дат (больше места под пары), прокрутка вверх возвращает их.
  late final AnimationController _collapse = AnimationController(vsync: this, duration: Motion.medium);
  late final Animation<double> _size = _collapse.drive(CurveTween(curve: Motion.emphasized)).drive(Tween<double>(begin: 1, end: 0));
  late final Animation<double> _fade =
      _collapse.drive(CurveTween(curve: const Interval(0, 0.6, curve: Curves.easeOut))).drive(Tween<double>(begin: 1, end: 0));
  late final Animation<Offset> _lift =
      _collapse.drive(CurveTween(curve: Motion.emphasized)).drive(Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.35)));
  bool _collapsed = false;
  double _acc = 0;

  void _setCollapsed(bool v) {
    if (_collapsed == v) return;
    _collapsed = v;
    if (context.reduceMotion) {
      _collapse.value = v ? 1 : 0;
    } else {
      _collapse.animateTo(v ? 1 : 0);
    }
  }

  /// Следит за вертикальной прокруткой дня: уходящий вниз список прячет ленту дат, возвращающийся — показывает.
  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final m = n.metrics;
    if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (d == 0 || m.pixels < 0 || m.pixels > m.maxScrollExtent) return false;
      _acc = (d > 0) == (_acc > 0) ? _acc + d : d;
      if (_acc > 14 && m.pixels > 48 && m.maxScrollExtent > 260 && m.maxScrollExtent - m.pixels > 80) {
        _setCollapsed(true);
      } else if (_acc < -10 || m.pixels <= 4) {
        _setCollapsed(false);
      }
    } else if (n is ScrollEndNotification) {
      _acc = 0;
      if (m.pixels <= 4) _setCollapsed(false);
    }
    return false;
  }

  DateTime _dateAt(int i) => addDays(_base, i - _back);
  int _indexOf(DateTime d) => (dayDiff(d, _base) + _back).clamp(0, _total - 1).toInt();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.attach(_jumpTo);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.setSelected(_selected);
      _centerStrip(_back, animate: false);
    });
  }

  @override
  void dispose() {
    widget.controller.detach();
    WidgetsBinding.instance.removeObserver(this);
    _pc.dispose();
    _strip.dispose();
    _collapse.dispose();
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
        _pc = PageController(initialPage: _back);
      });
      widget.controller.setSelected(_selected);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
        _centerStrip(_back, animate: false);
      });
    }
  }

  void _jumpTo(DateTime d) {
    if (!_pc.hasClients) return;
    final idx = _indexOf(d);
    final cur = (_pc.page ?? idx.toDouble()).round();
    if (idx == cur) return;
    if ((idx - cur).abs() > 3 || context.reduceMotion) {
      _pc.jumpToPage(idx);
    } else {
      _pc.animateToPage(idx, duration: Motion.medium, curve: Motion.standard);
    }
  }

  void _centerStrip(int index, {bool animate = true}) {
    if (!_strip.hasClients) return;
    final pos = _strip.position;
    final target = (index * _chipW + _chipW / 2 - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent).toDouble();
    if (animate && !context.reduceMotion) {
      _strip.animateTo(target, duration: const Duration(milliseconds: 280), curve: Motion.standard);
    } else {
      _strip.jumpTo(target);
    }
  }

  Future<void> _pickDate() async {
    final d = await pickDay(context, _selected);
    if (d != null) _jumpTo(dateOnly(d));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final marked = <String>{for (final a in store.absences) ymd(a.date)};
    final noted = <String>{for (final m in store.marks) ymd(m.date)};
    final isToday = sameDay(_selected, today());

    final header = AppBar(
      toolbarHeight: kHeaderHeight,
      titleSpacing: 20,
      title: Swap(
        child: PageTitle(
          relativeDay(_selected),
          key: ValueKey(ymd(_selected)),
          subtitle: '${fullDate(_selected)}${_selected.weekday == DateTime.sunday ? '' : ' · ${weekdayName(_selected)}'}',
        ),
      ),
      actions: [
        // Кнопка «Сегодня» выезжает с пружинкой и плавно раздвигает соседние кнопки.
        AnimatedSize(
          duration: context.motion(Motion.short),
          curve: Motion.standard,
          alignment: Alignment.centerRight,
          child: AnimatedSwitcher(
            duration: context.motion(Motion.short),
            switchInCurve: Motion.spring,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: isToday
                ? const SizedBox.shrink(key: ValueKey('no-today'))
                : IconButton(
                    key: const ValueKey('today'),
                    tooltip: 'Сегодня',
                    icon: const Icon(Icons.today_rounded),
                    onPressed: () => _jumpTo(today()),
                  ),
          ),
        ),
        IconButton(tooltip: 'Выбрать дату', icon: const Icon(Icons.edit_calendar_rounded), onPressed: _pickDate),
        PopupMenuButton<String>(
          tooltip: 'Ещё',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (v) {
            if (v == 'refresh') StoreScope.repoOf(context).prefetch(force: true);
            if (v == 'group') openGroupPicker(context);
            if (v == 'bells') showBellsSheet(context, _selected);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'bells', child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('Звонки на этот день'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Обновить расписание'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'group', child: ListTile(leading: Icon(Icons.groups_rounded), title: Text('Сменить группу'), contentPadding: EdgeInsets.zero)),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );

    final strip = SizedBox(
      height: 92,
      child: ListView.builder(
        controller: _strip,
        scrollDirection: Axis.horizontal,
        itemExtent: _chipW,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: _total,
        itemBuilder: (context, i) {
          final d = _dateAt(i);
          return _DayChip(
            date: d,
            selected: sameDay(d, _selected),
            isToday: sameDay(d, today()),
            marked: marked.contains(ymd(d)),
            noted: noted.contains(ymd(d)),
            onTap: () => _jumpTo(d),
          );
        },
      ),
    );

    final pages = PageView.builder(
      controller: _pc,
      itemCount: _total,
      onPageChanged: (i) {
        Haptics.selection();
        _setCollapsed(false);
        setState(() => _selected = _dateAt(i));
        widget.controller.setSelected(_selected);
        _centerStrip(i);
      },
      itemBuilder: (context, i) {
        final d = _dateAt(i);
        return DayView(key: ValueKey('${ymd(d)}|${store.settings.group}'), date: d, onJump: _jumpTo);
      },
    );

    return ContentFrame(
      child: Column(children: [
        header,
        // Месяц и лента дат плавно сворачиваются при прокрутке дня вниз.
        SizeTransition(
          sizeFactor: _size,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _lift,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Row(children: [
                    Swap(
                      child: Text(
                        monthYear(_selected),
                        key: ValueKey(monthYear(_selected)),
                        style: context.tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    Pill('Группа ${store.settings.group}', tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer), icon: Icons.groups_rounded),
                  ]),
                ),
                strip,
              ]),
            ),
          ),
        ),
        Expanded(child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: pages)),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.selected, required this.isToday, required this.marked, required this.noted, required this.onTap});
  final DateTime date;
  final bool selected;
  final bool isToday;
  final bool marked;
  final bool noted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final sunday = date.weekday == DateTime.sunday;
    final fg = selected ? cs.onPrimary : (isToday ? cs.primary : (sunday ? cs.error.withValues(alpha: 0.8) : cs.onSurface));
    return Semantics(
      button: true,
      selected: selected,
      label: longDate(date),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Haptics.selection();
          onTap();
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 78,
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 26 : 18),
              border: isToday && !selected ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayShort(date),
                  style: context.tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? cs.onPrimary.withValues(alpha: 0.85) : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date.day}',
                  style: context.tt.titleLarge?.copyWith(color: fg, fontWeight: (selected || isToday) ? FontWeight.w800 : FontWeight.w500),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (marked || noted) ? (selected ? cs.onPrimary : (marked ? absenceAccent(context, excused: false) : cs.tertiary)) : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── один день ─────────────────────────
