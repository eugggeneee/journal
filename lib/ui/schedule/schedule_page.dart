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
import '../settings/settings_home.dart';
import 'day_view.dart';
import 'week_view.dart';

/// Связывает страницу расписания с оболочкой (выбранная дата нужна кнопке «Добавить»).
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
  static const _back = 120;
  static const _fwd = 90;
  static const _total = _back + _fwd + 1;
  static const _chipW = 60.0;

  late DateTime _base = today();
  late PageController _pc = PageController(initialPage: _back);
  final ScrollController _strip = ScrollController();
  late DateTime _selected = _base;

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

  /// Неделя включена и экран достаточно широк (от 720 dp), иначе всегда один день.
  bool get _weekMode => mounted && MediaQuery.sizeOf(context).width >= 720 && StoreScope.of(context).settings.weekView;

  void _setWeek(bool v) {
    final store = StoreScope.of(context);
    store.setWeekView(v);
    if (!v) _restoreDayPage();
  }

  /// После возврата к одному дню страница и лента дат снова ставятся на выбранный день.
  void _restoreDayPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final i = _indexOf(_selected);
      if (_pc.hasClients) _pc.jumpToPage(i);
      _centerStrip(i, animate: false);
    });
  }

  void _shiftWeek(int weeks) {
    Haptics.selection();
    setState(() => _selected = addDays(_selected, 7 * weeks));
    widget.controller.setSelected(_selected);
  }

  void _openFromWeek(DateTime d) {
    setState(() => _selected = dateOnly(d));
    widget.controller.setSelected(_selected);
    StoreScope.of(context).setWeekView(false);
    _restoreDayPage();
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

  void _centerStrip(int index, {bool animate = true}) {
    if (!_strip.hasClients) return;
    final pos = _strip.position;
    final target = (index * _chipW + _chipW / 2 - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent).toDouble();
    if (animate && !context.reduceMotion) {
      _strip.animateTo(target, duration: Motion.ms(300), curve: Motion.decelerate);
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
    final marked = <String>{for (final a in store.absences) ymd(a.date)};
    final noted = <String>{for (final m in store.marks) ymd(m.date)};
    final isToday = sameDay(_selected, today());
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final week = wide && store.settings.weekView;
    final monday = addDays(_selected, -(_selected.weekday - 1));

    final header = AppBar(
      toolbarHeight: kHeaderHeight,
      titleSpacing: 20,
      title: Swap(
        child: week
            ? PageTitle('Неделя', key: ValueKey('week-${ymd(monday)}'), subtitle: '${shortDate(monday)} – ${shortDate(addDays(monday, 5))}')
            : PageTitle(
                relativeDay(_selected),
                key: ValueKey(ymd(_selected)),
                // День недели уже в заголовке, если там не «Сегодня», «Завтра» или «Вчера».
                subtitle: dayDiff(_selected, today()).abs() <= 1 ? '${fullDate(_selected)} · ${weekdayName(_selected)}' : fullDate(_selected),
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
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim.clamped, child: child)),
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
            if (v == 'week') _setWeek(!week);
            if (v == 'settings') {
              Haptics.selection();
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsHomePage()));
            }
          },
          itemBuilder: (_) => [
            if (wide)
              PopupMenuItem(
                value: 'week',
                child: ListTile(
                  leading: Icon(week ? Icons.view_day_rounded : Icons.view_week_rounded),
                  title: Text(week ? 'Показать день' : 'Показать неделю'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            const PopupMenuItem(value: 'bells', child: ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('Звонки на этот день'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh_rounded), title: Text('Обновить расписание'), contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'group', child: ListTile(leading: const Icon(Icons.groups_rounded), title: const Text('Сменить группу'), subtitle: Text('Сейчас ${store.settings.group}'), contentPadding: EdgeInsets.zero)),
            const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_rounded), title: Text('Настройки'), contentPadding: EdgeInsets.zero)),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );

    final strip = SizedBox(
      height: 80,
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
        if (week)
          Expanded(child: WeekView(selected: _selected, onShift: _shiftWeek, onOpenDay: _openFromWeek))
        else ...[
          // Лента дат всегда на виду: прокрутка дня её не трогает.
          strip,
          const SizedBox(height: 10),
          Expanded(child: pages),
        ],
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
            duration: Motion.short,
            curve: Motion.standard,
            width: 52,
            height: 70,
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(selected ? 26 : 18),
              border: isToday && !selected ? Border.all(color: cs.primary, width: 1.5) : null,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  duration: Motion.short,
                  curve: Motion.standard,
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
      ),
    );
  }
}

// ───────────────────────── один день ─────────────────────────
