import 'dart:ui' show FontFeature;

import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/reveal.dart';
import '../kit/select_sheet.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import 'bells_sheet.dart';

/// Выбор времени «чч:мм» (24-часовой формат). Возвращает минуты от полуночи.
Future<int?> pickMinutes(BuildContext context, int initial, {String? help}) async {
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: (initial ~/ 60).clamp(0, 23).toInt(), minute: initial % 60),
    helpText: help,
    cancelText: 'Отмена',
    confirmText: 'Готово',
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child ?? const SizedBox.shrink(),
    ),
  );
  return t == null ? null : t.hour * 60 + t.minute;
}

/// Расписание звонков: время пар с 1-й по 7-ю вручную, отдельно для будней, субботы и сокращённого дня.
/// Внутри каждой пары можно задать перерыв, между парами — обед.
class BellsPage extends StatefulWidget {
  const BellsPage({super.key, this.initialKey = kBellWeek});
  final String initialKey;
  @override
  State<BellsPage> createState() => _BellsPageState();
}

class _BellsPageState extends State<BellsPage> {
  late String _key = kBellKeys.contains(widget.initialKey) ? widget.initialKey : kBellWeek;

  static const _defaultPair = 90;
  static const _defaultBreak = 5;

  BellProfile _profile(AppStore store) => store.settings.bell(_key);

  void _save(AppStore store, BellProfile p) => store.setBellProfile(_key, p);

  void _warn(String text) => showNote(ScaffoldMessenger.of(context), text);

  Future<void> _pickStart(AppStore store, int n) async {
    final p = _profile(store);
    final slot = p[n];
    final m = await pickMinutes(context, slot?.start ?? _suggestStart(p, n), help: '$n пара · начало');
    if (m == null || !mounted) return;
    if (m >= 24 * 60 - 1) return _warn('Слишком поздно для начала пары');
    Haptics.selection();
    if (slot == null) {
      _save(store, p.withSlot(n, BellSlot(start: m, end: (m + _defaultPair).clamp(m + 1, 24 * 60 - 1).toInt())));
      return;
    }
    final end = slot.end > m ? slot.end : (m + slot.minutes).clamp(m + 1, 24 * 60 - 1).toInt();
    var next = BellSlot(start: m, end: end, breakStart: slot.breakStart, breakEnd: slot.breakEnd);
    if (!next.valid) next = next.withoutBreak();
    _save(store, p.withSlot(n, next));
  }

  Future<void> _pickEnd(AppStore store, int n) async {
    final p = _profile(store);
    final slot = p[n];
    final m = await pickMinutes(context, slot?.end ?? (_suggestStart(p, n) + _defaultPair), help: '$n пара · конец');
    if (m == null || !mounted) return;
    Haptics.selection();
    if (slot == null) {
      final start = (m - _defaultPair).clamp(0, m - 1).toInt();
      if (m <= 0) return _warn('Конец пары должен быть позже начала');
      _save(store, p.withSlot(n, BellSlot(start: start, end: m)));
      return;
    }
    if (m <= slot.start) return _warn('Конец пары должен быть позже начала');
    var next = BellSlot(start: slot.start, end: m, breakStart: slot.breakStart, breakEnd: slot.breakEnd);
    if (!next.valid) next = next.withoutBreak();
    _save(store, p.withSlot(n, next));
  }

  /// Подсказка для времени ещё не заданной пары: через 10 минут после предыдущей.
  int _suggestStart(BellProfile p, int n) {
    for (var m = n - 1; m >= 1; m--) {
      final prev = p[m];
      if (prev != null) return (prev.end + 10).clamp(0, 24 * 60 - 1).toInt();
    }
    return 8 * 60 + 30;
  }

  Future<void> _pickBreak(AppStore store, int n, {required bool start}) async {
    final p = _profile(store);
    final slot = p[n];
    if (slot == null || !slot.hasBreak) return;
    final m = await pickMinutes(context, start ? slot.breakStart! : slot.breakEnd!, help: '$n пара · перерыв ${start ? 'с' : 'до'}');
    if (m == null || !mounted) return;
    final next = BellSlot(
      start: slot.start,
      end: slot.end,
      breakStart: start ? m : slot.breakStart,
      breakEnd: start ? slot.breakEnd : m,
    );
    if (!next.valid) return _warn('Перерыв должен быть внутри пары: ${slotRange(slot)}');
    Haptics.selection();
    _save(store, p.withSlot(n, next));
  }

  void _toggleBreak(AppStore store, int n) {
    final p = _profile(store);
    final slot = p[n];
    if (slot == null) return;
    Haptics.selection();
    if (slot.hasBreak) {
      _save(store, p.withSlot(n, slot.withoutBreak()));
      return;
    }
    if (slot.minutes < _defaultBreak + 4) return _warn('Пара слишком короткая для перерыва');
    final bs = slot.start + (slot.minutes - _defaultBreak) ~/ 2;
    _save(store, p.withSlot(n, BellSlot(start: slot.start, end: slot.end, breakStart: bs, breakEnd: bs + _defaultBreak)));
  }

  void _clearPair(AppStore store, int n) {
    final p = _profile(store);
    final messenger = ScaffoldMessenger.of(context);
    if (p[n] == null) return;
    final key = _key;
    Haptics.light();
    _save(store, p.withSlot(n, null));
    showUndo(messenger, '$n пара очищена', () => store.setBellProfile(key, p));
  }

  void _withUndo(AppStore store, String message, BellProfile next) {
    final messenger = ScaffoldMessenger.of(context);
    final key = _key;
    final before = _profile(store);
    Haptics.medium();
    store.setBellProfile(key, next);
    showUndo(messenger, message, () => store.setBellProfile(key, before));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final p = _profile(store);
    final problem = p.problem;
    final week = store.settings.bell(kBellWeek);

    final hint = switch (_key) {
      kBellSat => 'В субботу время пар обычно другое — задайте его отдельно.',
      kBellShort => 'Применяется в дни, отмеченные в расписании кнопкой «Сокращённый день».',
      _ => 'Применяется с понедельника по пятницу. У разных групп время может отличаться — введите своё.',
    };

    final nums = [for (var n = 1; n <= kMaxPairs; n++) n];
    final rows = <Widget>[];
    for (final n in nums) {
      rows.add(_PairCard(
        key: ValueKey('pair-$_key-$n'),
        n: n,
        slot: p[n],
        onStart: () => _pickStart(store, n),
        onEnd: () => _pickEnd(store, n),
        onBreakStart: () => _pickBreak(store, n, start: true),
        onBreakEnd: () => _pickBreak(store, n, start: false),
        onToggleBreak: () => _toggleBreak(store, n),
        onClear: () => _clearPair(store, n),
      ));
      final next = p.nextPair(n);
      final gap = (p[n] != null && next == n + 1) ? gapLabel(p, n) : null;
      rows.add(Smooth(
        child: gap == null
            ? SizedBox(key: ValueKey('gap-none-$n'), height: 8, width: double.infinity)
            : Padding(
                key: ValueKey('gap-$n-$gap-${p.isLunchAfter(n)}'),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Center(
                  child: Pill(
                    gap,
                    tone: p.isLunchAfter(n) ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.surfaceContainerHighest, cs.onSurfaceVariant),
                    icon: p.isLunchAfter(n) ? Icons.restaurant_rounded : Icons.timer_outlined,
                  ),
                ),
              ),
      ));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: const Text('Звонки')),
            Inset(children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [for (final k in kBellKeys) ButtonSegment(value: k, label: Text(k == kBellShort ? 'Сокращённый' : bellTitle(k)))],
                  selected: {_key},
                  onSelectionChanged: (s) {
                    Haptics.selection();
                    setState(() => _key = s.first);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                child: Text(hint, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                    label: const Text('Автозаполнение'),
                    onPressed: () => _openAutoFill(store),
                  ),
                ),
                if (_key != kBellWeek && !week.isEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Скопировать из будней',
                    icon: const Icon(Icons.content_copy_rounded),
                    onPressed: () => _withUndo(store, 'Скопировано из будней', week),
                  ),
                ],
                if (!p.isEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Очистить всё',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _withUndo(store, 'Звонки очищены', const BellProfile()),
                  ),
                ],
              ]),
              const SizedBox(height: 16),
              SelectField<int>(
                label: 'Обед',
                icon: Icons.restaurant_rounded,
                value: p.lunchAfter,
                valueLabel: p.lunchAfter == 0 ? 'Без обеда' : 'После ${p.lunchAfter} пары',
                sheetTitle: 'Перерыв на обед',
                sheetSubtitle: 'Длительность — разница между концом этой пары и началом следующей',
                options: [
                  const MenuOption(0, 'Без обеда', icon: Icons.block_rounded),
                  for (var n = 1; n < kMaxPairs; n++) MenuOption(n, 'После $n пары', icon: Icons.restaurant_rounded),
                ],
                onSelected: (v) => _save(store, p.withLunch(v)),
              ),
              Smooth(
                child: problem == null
                    ? const SizedBox(key: ValueKey('problem-none'), width: double.infinity)
                    : Padding(
                        key: ValueKey(problem),
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(20)),
                          child: Row(children: [
                            Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(child: Text(problem, style: context.tt.bodyMedium?.copyWith(color: cs.onErrorContainer))),
                          ]),
                        ),
                      ),
              ),
              const SectionHeader('Пары'),
              ...rows,
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  'Время показывается справа в карточке каждой пары. Значки: ☕ — перерыв внутри пары, 🍴 — после пары обед. '
                  'Перерывы между парами считаются сами — по времени конца и начала.',
                  style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                ),
              ),
              if (!p.isEmpty) ...[
                const SectionHeader('Как это выглядит'),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
                  child: BellTimeline(profile: p),
                ),
              ],
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Future<void> _openAutoFill(AppStore store) => showAdaptiveSheet<void>(
        context,
        (ctx) => _AutoFillSheet(
          title: bellTitle(_key),
          onApply: (plan) {
            Navigator.of(ctx).pop();
            _withUndo(store, 'Звонки заполнены', generateBells(plan));
          },
        ),
      );
}

/// Карточка одной пары: начало и конец, перерыв внутри пары и меню действий.
class _PairCard extends StatelessWidget {
  const _PairCard({
    super.key,
    required this.n,
    required this.slot,
    required this.onStart,
    required this.onEnd,
    required this.onBreakStart,
    required this.onBreakEnd,
    required this.onToggleBreak,
    required this.onClear,
  });
  final int n;
  final BellSlot? slot;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onBreakStart;
  final VoidCallback onBreakEnd;
  final VoidCallback onToggleBreak;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final s = slot;
    final set = s != null;
    return SegmentCard(
      index: 0,
      count: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Column(children: [
          Row(children: [
            NumberBadge('$n', tone: set ? Tone(cs.primaryContainer, cs.onPrimaryContainer) : neutralTone(context), size: 46, round: false),
            const SizedBox(width: 12),
            Expanded(child: _TimeField(label: 'Начало', minutes: s?.start, onTap: onStart)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 18, color: cs.onSurfaceVariant),
            ),
            Expanded(child: _TimeField(label: 'Конец', minutes: s?.end, onTap: onEnd)),
            PopupMenuButton<String>(
              tooltip: 'Действия',
              icon: const Icon(Icons.more_vert_rounded),
              enabled: set,
              onSelected: (v) {
                if (v == 'break') onToggleBreak();
                if (v == 'clear') onClear();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'break',
                  child: ListTile(
                    leading: const Icon(Icons.coffee_rounded),
                    title: Text(s != null && s.hasBreak ? 'Убрать перерыв внутри' : 'Перерыв внутри пары'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Очистить пару'), contentPadding: EdgeInsets.zero),
                ),
              ],
            ),
          ]),
          Smooth(
            child: (s != null && s.hasBreak)
                ? Padding(
                    key: const ValueKey('break'),
                    padding: const EdgeInsets.fromLTRB(0, 10, 10, 2),
                    child: Row(children: [
                      const SizedBox(width: 58),
                      Icon(Icons.coffee_rounded, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: _TimeField(label: 'Перерыв с', minutes: s.breakStart, onTap: onBreakStart, dense: true)),
                      const SizedBox(width: 8),
                      Expanded(child: _TimeField(label: 'до', minutes: s.breakEnd, onTap: onBreakEnd, dense: true)),
                    ]),
                  )
                : const SizedBox.shrink(key: ValueKey('break-none')),
          ),
        ]),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.minutes, required this.onTap, this.dense = false});
  final String label;
  final int? minutes;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final has = minutes != null;
    return Semantics(
      button: true,
      label: '$label: ${has ? fmtMin(minutes!) : 'не задано'}',
      excludeSemantics: true,
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: context.tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              Text(
                has ? fmtMin(minutes!) : '—:—',
                style: (dense ? context.tt.titleSmall : context.tt.titleMedium)?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: has ? cs.onSurface : cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── автозаполнение ─────────────────────────

class _AutoFillSheet extends StatefulWidget {
  const _AutoFillSheet({required this.title, required this.onApply});
  final String title;
  final ValueChanged<BellPlan> onApply;
  @override
  State<_AutoFillSheet> createState() => _AutoFillSheetState();
}

class _AutoFillSheetState extends State<_AutoFillSheet> {
  int first = 8 * 60 + 30;
  int pair = 90;
  int brk = 10;
  int count = kMaxPairs;
  int lunchAfter = 0;
  int lunch = 30;
  int inner = 0;

  BellPlan get plan => BellPlan(
        firstStart: first,
        pairMinutes: pair,
        breakMinutes: brk,
        count: count,
        lunchAfter: lunchAfter >= count ? 0 : lunchAfter,
        lunchMinutes: lunch,
        innerBreak: inner,
      );

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final preview = generateBells(plan);
    final last = preview.slots.isEmpty ? null : preview.slots[(preview.slots.keys.toList()..sort()).last];
    final lunchOptions = [for (var n = 1; n < count; n++) n];
    return SheetScaffold(
      title: 'Автозаполнение',
      subtitle: widget.title,
      leading: CookieIcon(icon: Icons.auto_fix_high_rounded, size: 52, bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.check_rounded, size: 22),
          label: const Text('Заполнить'),
          onPressed: preview.slots.isEmpty ? null : () => widget.onApply(plan),
        ),
      ),
      children: [
        const SizedBox(height: 4),
        FieldTile(
          label: 'Начало 1 пары',
          icon: Icons.wb_twilight_rounded,
          valueLabel: fmtMin(first),
          trailing: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
          onTap: () async {
            final m = await pickMinutes(context, first, help: 'Начало 1 пары');
            if (m != null) setState(() => first = m);
          },
        ),
        const SizedBox(height: 8),
        _Stepper(label: 'Пар в день', value: count, min: 1, max: kMaxPairs, step: 1, suffix: '', onChanged: (v) => setState(() => count = v)),
        _Stepper(label: 'Длительность пары', value: pair, min: 30, max: 180, step: 5, suffix: ' мин', onChanged: (v) => setState(() => pair = v)),
        _Stepper(label: 'Перерыв между парами', value: brk, min: 0, max: 60, step: 5, suffix: ' мин', onChanged: (v) => setState(() => brk = v)),
        _Stepper(label: 'Перерыв внутри пары', value: inner, min: 0, max: 20, step: 5, suffix: ' мин', onChanged: (v) => setState(() => inner = v)),
        const SizedBox(height: 8),
        SelectField<int>(
          label: 'Обед',
          icon: Icons.restaurant_rounded,
          value: lunchAfter >= count ? 0 : lunchAfter,
          valueLabel: (lunchAfter == 0 || lunchAfter >= count) ? 'Без обеда' : 'После $lunchAfter пары',
          sheetTitle: 'Перерыв на обед',
          options: [
            const MenuOption(0, 'Без обеда', icon: Icons.block_rounded),
            for (final n in lunchOptions) MenuOption(n, 'После $n пары', icon: Icons.restaurant_rounded),
          ],
          onSelected: (v) => setState(() => lunchAfter = v),
        ),
        Smooth(
          child: (lunchAfter > 0 && lunchAfter < count)
              ? Padding(
                  key: const ValueKey('lunch'),
                  padding: const EdgeInsets.only(top: 8),
                  child: _Stepper(label: 'Длительность обеда', value: lunch, min: 10, max: 120, step: 5, suffix: ' мин', onChanged: (v) => setState(() => lunch = v)),
                )
              : const SizedBox.shrink(key: ValueKey('lunch-none')),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
          child: Text(
            last == null ? 'Слишком поздно: пары не помещаются в сутки.' : 'Получится: 1 пара в ${fmtMin(preview.slots[1]!.start)}, ${preview.slots.length}-я заканчивается в ${fmtMin(last.end)}.',
            style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Text('Дальше любое время можно поправить вручную.', style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// Строка со значением и кнопками «минус / плюс».
class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.step, required this.suffix, required this.onChanged});
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
          child: Row(children: [
            Expanded(child: Text(label, style: context.tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
            IconButton(
              tooltip: 'Меньше',
              icon: const Icon(Icons.remove_rounded),
              onPressed: value <= min
                  ? null
                  : () {
                      Haptics.selection();
                      onChanged((value - step).clamp(min, max).toInt());
                    },
            ),
            SizedBox(
              width: 64,
              child: Text(
                '$value$suffix',
                textAlign: TextAlign.center,
                style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
            IconButton(
              tooltip: 'Больше',
              icon: const Icon(Icons.add_rounded),
              onPressed: value >= max
                  ? null
                  : () {
                      Haptics.selection();
                      onChanged((value + step).clamp(min, max).toInt());
                    },
            ),
          ]),
        ),
      ),
    );
  }
}
