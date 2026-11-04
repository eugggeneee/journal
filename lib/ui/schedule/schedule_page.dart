import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../../logic/schedule_service.dart';
import '../absences/absence_actions.dart';
import '../group_picker.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/reveal.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import '../settings/bells_page.dart';
import '../settings/bells_sheet.dart';
import 'lesson_sheet.dart';
import 'marks.dart';

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

  void _jumpTo(DateTime d) {
    if (!_pc.hasClients) return;
    final idx = _indexOf(d);
    final cur = (_pc.page ?? idx.toDouble()).round();
    if (idx == cur) return;
    if ((idx - cur).abs() > 3) {
      _pc.jumpToPage(idx);
    } else {
      _pc.animateToPage(idx, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  void _centerStrip(int index, {bool animate = true}) {
    if (!_strip.hasClients) return;
    final pos = _strip.position;
    final target = (index * _chipW + _chipW / 2 - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent).toDouble();
    if (animate) {
      _strip.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
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
      title: PageTitle(
        relativeDay(_selected),
        subtitle: '${fullDate(_selected)}${_selected.weekday == DateTime.sunday ? '' : ' · ${weekdayName(_selected)}'}',
      ),
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isToday
              ? const SizedBox.shrink(key: ValueKey('no-today'))
              : IconButton(
                  key: const ValueKey('today'),
                  tooltip: 'Сегодня',
                  icon: const Icon(Icons.today_rounded),
                  onPressed: () => _jumpTo(today()),
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
            if (v == 'short') toggleShortDay(context, StoreScope.of(context), _selected);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'short',
              child: ListTile(
                leading: Icon(store.isShortDay(_selected) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded),
                title: const Text('Сокращённый день'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
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
        setState(() => _selected = _dateAt(i));
        widget.controller.setSelected(_selected);
        _centerStrip(i);
      },
      itemBuilder: (context, i) {
        final d = _dateAt(i);
        return DayView(key: ValueKey('${ymd(d)}|${store.settings.group}'), date: d);
      },
    );

    return ContentFrame(
      child: Column(children: [
        header,
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Row(children: [
            Text(monthYear(_selected), style: context.tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
            const Spacer(),
            Pill('Группа ${store.settings.group}', tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer), icon: Icons.groups_rounded),
          ]),
        ),
        strip,
        Expanded(child: pages),
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
                    color: (marked || noted) ? (selected ? cs.onPrimary : (marked ? cs.error : cs.tertiary)) : Colors.transparent,
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

/// Сокращённый день: переключатель с отменой. Если время звонков для него не задано — предлагает настроить.
void toggleShortDay(BuildContext context, AppStore store, DateTime date) {
  final m = ScaffoldMessenger.of(context);
  final was = store.isShortDay(date);
  store.setShortDay(date, !was);
  Haptics.selection();
  m.hideCurrentSnackBar();
  if (!was && store.settings.bell(kBellShort).isEmpty) {
    final nav = Navigator.of(context);
    m.showSnackBar(SnackBar(
      content: const Text('Сокращённый день отмечен. Задайте для него время пар'),
      persist: false,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Настроить',
        onPressed: () => nav.push(MaterialPageRoute<void>(builder: (_) => const BellsPage(initialKey: kBellShort))),
      ),
    ));
    return;
  }
  showUndo(m, was ? 'Обычный день' : 'Сокращённый день отмечен', () => store.setShortDay(date, was));
}

class DayView extends StatefulWidget {
  const DayView({super.key, required this.date});
  final DateTime date;
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
    // Сегодня: раз в полминуты обновляем подсветку идущей пары.
    if (sameDay(widget.date, today())) {
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
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
        ? const Padding(padding: EdgeInsets.only(top: 120), child: Center(child: CircularProgressIndicator()))
        : _content(context, store, st);
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, kFabClearance),
        children: [
          if (st != null && st.status != DayStatus.ok) ..._plainChips(context, store),
          MarksSection(date: widget.date, store: store, slots: slots),
          content,
        ],
      ),
    );
  }

  /// Кнопки дня: сокращённый день и пометка.
  Widget _chips(BuildContext context, AppStore store, {required bool showShort}) {
    final short = store.isShortDay(widget.date);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (showShort)
          FilterChip(
            avatar: Icon(short ? Icons.timelapse_rounded : Icons.schedule_rounded, size: 18),
            label: const Text('Сокращённый день'),
            selected: short,
            showCheckmark: false,
            onSelected: (_) => toggleShortDay(context, store, widget.date),
          ),
        ActionChip(
          avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('Пометка'),
          onPressed: () {
            Haptics.selection();
            showMarkSheet(context, widget.date);
          },
        ),
      ]),
    );
  }

  List<Widget> _plainChips(BuildContext context, AppStore store) => [_chips(context, store, showShort: false)];

  Widget _content(BuildContext context, AppStore store, DayState st) {
    final cs = context.cs;
    switch (st.status) {
      case DayStatus.ok:
        final s = st.schedule!;
        final sub = st.note ?? (st.fromCache ? 'Сохранено на устройстве' : 'Обновлено в ${hhmm(s.fetchedAt)}');
        final marked = [for (final slot in s.slots) if (store.absenceFor(widget.date, slot.number) != null) slot];
        final allMarked = marked.length == s.slots.length && s.slots.isNotEmpty;
        final hours = marked.fold<int>(0, (a, slot) => a + (store.absenceFor(widget.date, slot.number)?.hours ?? 0));
        final nowPair = sameDay(widget.date, today()) ? _currentPair(store) : null;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        pairsText(s.slots.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    // Плашка с часами появляется рядом с заголовком и не меняет высоту шапки.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: PopIn(
                        token: hours,
                        child: hours > 0
                            ? Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Pill(
                                  hoursText(hours),
                                  tone: absenceTone(context, excused: false),
                                  icon: Icons.event_busy_rounded,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ]),
                  Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ]),
              ),
              // Ширина кнопки не зависит от подписи — «Весь день» и «Снять день» не сдвигают шапку.
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(152, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                  child: Icon(
                    allMarked ? Icons.event_available_rounded : Icons.event_busy_rounded,
                    key: ValueKey(allMarked),
                    size: 20,
                  ),
                ),
                label: Text(allMarked ? 'Снять день' : 'Весь день'),
                onPressed: () => toggleWholeDay(context, store, widget.date, s.slots),
              ),
            ]),
          ),
          _chips(context, store, showShort: true),
          for (var i = 0; i < s.slots.length; i++)
            LessonCard(
              index: i,
              count: s.slots.length,
              slot: s.slots[i],
              date: widget.date,
              store: store,
              isNow: nowPair == s.slots[i].number,
            ),
        ]);
      case DayStatus.sunday:
        return const EmptyState(icon: Icons.wb_sunny_rounded, title: 'Выходной', message: 'В этот день пар нет.');
      case DayStatus.noGroup:
        return EmptyState(
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

  /// Номер пары, которая идёт прямо сейчас (если задано время звонков).
  int? _currentPair(AppStore store) {
    final now = DateTime.now();
    return store.bellProfileFor(widget.date).pairAt(now.hour * 60 + now.minute);
  }
}

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.index,
    required this.count,
    required this.slot,
    required this.date,
    required this.store,
    this.isNow = false,
  });
  final int index;
  final int count;
  final LessonSlot slot;
  final DateTime date;
  final AppStore store;

  /// Пара идёт прямо сейчас.
  final bool isNow;

  static String roomText(String r) => r.isEmpty ? '' : (RegExp(r'\d').hasMatch(r) ? 'ауд. $r' : r);

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final absence = store.absenceFor(date, slot.number);
    final mark = store.markFor(date, slot.number);
    final bell = store.bellFor(date, slot.number);
    final profile = store.bellProfileFor(date);
    final base = isNow ? Tone(cs.primary, cs.onPrimary) : Tone(cs.primaryContainer, cs.onPrimaryContainer);
    final tone = absence == null ? base : absenceTone(context, excused: absence.excused);
    final title = slot.subjects.map(store.subjectName).join(' / ');
    final lines = [
      for (final e in slot.entries) [roomText(e.room), e.teacher].where((x) => x.isNotEmpty).join(' · '),
    ].where((x) => x.isNotEmpty).toList();
    final cardColor = absence == null ? cs.surfaceContainerLow : Color.alphaBlend(tone.bg.withValues(alpha: 0.55), cs.surfaceContainerLow);

    return SegmentCard(
      index: index,
      count: count,
      color: absence == null ? null : tone.bg.withValues(alpha: 0.55),
      onTap: () => showLessonSheet(context, date, slot),
      onLongPress: () => toggleLessonAbsence(context, store, date, slot),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
                  child: absence == null ? null : AbsenceBadge(hours: absence.hours, excused: absence.excused, ringColor: cardColor),
                ),
              ),
              Positioned(
                bottom: -9,
                left: -8,
                right: -8,
                child: Center(
                  child: PopIn(
                    token: mark?.label,
                    child: mark == null ? null : MarkTag(label: mark.label, ringColor: cardColor),
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
                  child: Text(l, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
            ]),
          ),
          if (bell != null) _TimeColumn(slot: bell, lunch: profile.isLunchAfter(slot.number), highlight: isNow),
          IconButton(
            tooltip: absence == null ? 'Отметить пропуск' : 'Снять пропуск',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
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

/// Время пары справа в карточке: начало и конец в две строки. Высота — две строки текста,
/// меньше номера пары, поэтому размер карточки не меняется. Значки: ☕ — перерыв внутри пары, 🍴 — после пары обед.
class _TimeColumn extends StatelessWidget {
  const _TimeColumn({required this.slot, required this.lunch, required this.highlight});
  final BellSlot slot;
  final bool lunch;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    const figures = [FontFeature.tabularFigures()];
    Widget line(String text, TextStyle? style, IconData? icon) => Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3)],
          Text(text, style: style),
        ]);
    return Semantics(
      label: 'Время пары: ${slotRange(slot)}${slot.hasBreak ? ', внутри перерыв' : ''}${lunch ? ', после пары обед' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, right: 2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          line(
            fmtMin(slot.start),
            context.tt.labelLarge?.copyWith(fontWeight: FontWeight.w800, color: highlight ? cs.primary : cs.onSurface, fontFeatures: figures),
            slot.hasBreak ? Icons.coffee_rounded : null,
          ),
          const SizedBox(height: 2),
          line(
            fmtMin(slot.end),
            context.tt.labelMedium?.copyWith(color: cs.onSurfaceVariant, fontFeatures: figures),
            lunch ? Icons.restaurant_rounded : null,
          ),
        ]),
      ),
    );
  }
}
