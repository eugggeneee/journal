import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/bells.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/inputs/pickers.dart';
import '../kit/inputs/settings_tiles.dart';
import '../kit/sheets/select_sheet.dart';
import '../kit/sheets/sheet.dart';

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

/// Звонки: три расписания (будни, суббота, сокращённый день). Сверху готовые расписания колледжа в одно нажатие,
/// ниже короткий список пар: нажали на пару и поправили время в понятной шторке. Всё остальное в «Дополнительно».
class BellsPage extends StatefulWidget {
  const BellsPage({super.key, this.initialKey = kBellWeek});
  final String initialKey;
  @override
  State<BellsPage> createState() => _BellsPageState();
}

class _BellsPageState extends State<BellsPage> {
  late String _key = kBellKeys.contains(widget.initialKey) ? widget.initialKey : kBellWeek;

  static const _icons = {kBellWeek: Icons.work_outline_rounded, kBellSat: Icons.weekend_rounded, kBellShort: Icons.timelapse_rounded};

  BellProfile _profile(AppStore store) => store.settings.bell(_key);

  void _withUndo(AppStore store, String message, BellProfile next) {
    final messenger = ScaffoldMessenger.of(context);
    final key = _key;
    final before = _profile(store);
    Haptics.medium();
    store.setBellProfile(key, next);
    showUndo(messenger, message, () => store.setBellProfile(key, before));
  }

  void _applyPreset(AppStore store, BellPreset preset) {
    if (_profile(store).sameAs(preset.profile)) return;
    _withUndo(store, '${preset.title} применено', preset.profile);
  }

  /// Новая пара: время подставляется через 10 минут после предыдущей, дальше правится в шторке.
  void _addPair(AppStore store) {
    final p = _profile(store);
    var n = 1;
    while (n <= kMaxPairs && p[n] != null) {
      n++;
    }
    if (n > kMaxPairs) return;
    final start = _suggestStart(p, n);
    final end = (start + 90).clamp(start + 1, 24 * 60 - 1).toInt();
    Haptics.selection();
    store.setBellProfile(_key, p.withSlot(n, BellSlot(start: start, end: end)));
    showPairSheet(context, _key, n);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final tt = context.tt;
    final p = _profile(store);
    final problem = p.problem;
    final week = store.settings.bell(kBellWeek);
    final presets = [for (final x in kBellPresets) if (x.key == _key) x];
    final nums = p.slots.keys.toList()..sort();

    final hint = switch (_key) {
      kBellSat => 'Время пар в субботу обычно другое.',
      kBellShort => 'Включается сам в день с пометкой «Сокращённый день».',
      _ => 'Действует с понедельника по пятницу. У вашей группы время может отличаться.',
    };

    final rows = <Widget>[];
    for (var i = 0; i < nums.length; i++) {
      final n = nums[i];
      final slot = p.slots[n]!;
      rows.add(_PairRow(
        key: ValueKey('pair-$_key-$n'),
        n: n,
        slot: slot,
        onTap: () {
          Haptics.selection();
          showPairSheet(context, _key, n);
        },
      ));
      final gap = (i + 1 < nums.length && nums[i + 1] == n + 1) ? gapLabel(p, n) : null;
      rows.add(gap == null
          ? const SizedBox(height: 8)
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Pill(
                  gap,
                  tone: p.isLunchAfter(n) ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.surfaceContainerHighest, cs.onSurfaceVariant),
                  icon: p.isLunchAfter(n) ? Icons.restaurant_rounded : Icons.timer_outlined,
                ),
              ),
            ));
    }

    final extra = <Widget>[
      SettingsTile(
        icon: Icons.auto_fix_high_rounded,
        title: 'Автозаполнение',
        subtitle: 'Пары подряд: начало, длительность, перерыв и обед',
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ),
      SettingsTile(
        icon: Icons.restaurant_rounded,
        title: 'Обед',
        subtitle: p.lunchAfter == 0 ? 'Без обеда между парами' : 'После ${p.lunchAfter} пары',
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ),
      if (_key != kBellWeek && !week.isEmpty)
        SettingsTile(
          icon: Icons.content_copy_rounded,
          title: 'Скопировать из будней',
          subtitle: 'Те же пары и перерывы',
          trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ),
      SettingsTile(
        icon: _key == kBellShort ? Icons.restore_rounded : Icons.delete_sweep_outlined,
        title: _key == kBellShort ? 'Вернуть шаблон колледжа' : 'Очистить всё',
        subtitle: _key == kBellShort ? '6 пар по часу, перерывы по 10 минут' : 'Удалить все пары этого расписания',
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
      ),
    ];
    final extraActions = <VoidCallback>[
      () => showAdaptiveSheet<void>(
            context,
            (ctx) => _AutoFillSheet(
              title: bellTitle(_key),
              onApply: (plan) {
                Navigator.of(ctx).pop();
                _withUndo(store, 'Звонки заполнены', generateBells(plan));
              },
            ),
          ),
      () => showSelectSheet<int>(
            context,
            title: 'Перерыв на обед',
            subtitle: 'Длительность: от конца этой пары до начала следующей',
            value: p.lunchAfter,
            options: [
              const MenuOption(0, 'Без обеда', icon: Icons.block_rounded),
              for (var n = 1; n < kMaxPairs; n++) MenuOption(n, 'После $n пары', icon: Icons.restaurant_rounded),
            ],
            onSelected: (v) => store.setBellProfile(_key, p.withLunch(v)),
          ),
      if (_key != kBellWeek && !week.isEmpty) () => _withUndo(store, 'Скопировано из будней', week),
      () => _withUndo(store, _key == kBellShort ? 'Шаблон колледжа возвращён' : 'Звонки очищены', _key == kBellShort ? kShortDayProfile : const BellProfile()),
    ];

    return Scaffold(
      backgroundColor: cs.surface,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            const SubHeader('Звонки', subtitle: 'Время пар и перерывы'),
            Inset(children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in kBellKeys)
                  ChoiceTag(label: bellTitle(k), icon: _icons[k], selected: _key == k, onTap: () => setState(() => _key = k)),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
                child: Text(hint, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
              ),
              if (presets.isNotEmpty) const SectionHeader('Готовые расписания', top: 20),
              for (var i = 0; i < presets.length; i++)
                SegmentCard(
                  index: i,
                  count: presets.length,
                  onTap: () => _applyPreset(store, presets[i]),
                  child: BadgeRow(
                    icon: Icons.schedule_rounded,
                    tone: hueTone(context, kHueAmber),
                    title: presets[i].title,
                    subtitle: presets[i].subtitle,
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        p.sameAs(presets[i].profile) ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        color: p.sameAs(presets[i].profile) ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                            Expanded(child: Text(problem, style: tt.bodyMedium?.copyWith(color: cs.onErrorContainer))),
                          ]),
                        ),
                      ),
              ),
              SectionHeader('Пары', trailing: nums.isEmpty ? null : pairsText(nums.length)),
              if (nums.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  child: Text('Время пар не задано. Выберите готовое расписание выше или добавьте пары вручную.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant, height: 1.35)),
                ),
              ...rows,
              if (nums.length < kMaxPairs)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить пару'),
                    onPressed: () => _addPair(store),
                  ),
                ),
              const SectionHeader('Дополнительно'),
              for (var i = 0; i < extra.length; i++)
                SegmentCard(index: i, count: extra.length, onTap: extraActions[i], child: extra[i]),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}

/// Подсказка для времени ещё не заданной пары: через 10 минут после предыдущей.
int _suggestStart(BellProfile p, int n) {
  for (var m = n - 1; m >= 1; m--) {
    final prev = p[m];
    if (prev != null) return (prev.end + 10).clamp(0, 24 * 60 - 1).toInt();
  }
  return 8 * 60 + 30;
}

/// Строка пары в списке: номер, время и коротко о перерыве внутри.
class _PairRow extends StatelessWidget {
  const _PairRow({super.key, required this.n, required this.slot, required this.onTap});
  final int n;
  final BellSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    final detail = slot.hasBreak
        ? '${slot.lunchInside ? 'Обед' : 'Перерыв'} внутри пары: ${shortRange(slot.breakStart!, slot.breakEnd!)}'
        : spanText(slot.minutes);
    return Appear(
      index: n - 1,
      child: SegmentCard(
        index: 0,
        count: 1,
        appear: false,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Row(children: [
            NumberBadge('$n', tone: hueTone(context, kSubjectHues[(n - 1) % kSubjectHues.length]), size: 46, round: false),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(slotRange(slot), style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
                Text(detail, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
            Icon(Icons.edit_outlined, size: 20, color: cs.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── правка одной пары ─────────────────────────

/// Шторка одной пары: начало, конец, перерыв внутри пары. Изменения применяются сразу.
Future<void> showPairSheet(BuildContext context, String key, int n) =>
    showAdaptiveSheet<void>(context, (_) => _PairSheet(bellKey: key, n: n));

class _PairSheet extends StatelessWidget {
  const _PairSheet({required this.bellKey, required this.n});
  final String bellKey;
  final int n;

  static const _defaultBreak = 5;

  void _warn(BuildContext context, String text) => showNote(ScaffoldMessenger.of(context), text);

  Future<void> _pickStart(BuildContext context, AppStore store, BellProfile p, BellSlot slot) async {
    final m = await pickMinutes(context, slot.start, help: '$n пара · начало');
    if (m == null || !context.mounted) return;
    if (m >= 24 * 60 - 1) return _warn(context, 'Слишком поздно для начала пары');
    Haptics.selection();
    final end = slot.end > m ? slot.end : (m + slot.minutes).clamp(m + 1, 24 * 60 - 1).toInt();
    var next = BellSlot(start: m, end: end, breakStart: slot.breakStart, breakEnd: slot.breakEnd);
    if (!next.valid) next = next.withoutBreak();
    store.setBellProfile(bellKey, p.withSlot(n, next));
  }

  Future<void> _pickEnd(BuildContext context, AppStore store, BellProfile p, BellSlot slot) async {
    final m = await pickMinutes(context, slot.end, help: '$n пара · конец');
    if (m == null || !context.mounted) return;
    if (m <= slot.start) return _warn(context, 'Конец пары должен быть позже начала');
    Haptics.selection();
    var next = BellSlot(start: slot.start, end: m, breakStart: slot.breakStart, breakEnd: slot.breakEnd);
    if (!next.valid) next = next.withoutBreak();
    store.setBellProfile(bellKey, p.withSlot(n, next));
  }

  Future<void> _pickBreak(BuildContext context, AppStore store, BellProfile p, BellSlot slot, {required bool start}) async {
    final m = await pickMinutes(context, start ? slot.breakStart! : slot.breakEnd!, help: '$n пара · перерыв ${start ? 'с' : 'до'}');
    if (m == null || !context.mounted) return;
    final next = BellSlot(start: slot.start, end: slot.end, breakStart: start ? m : slot.breakStart, breakEnd: start ? slot.breakEnd : m);
    if (!next.valid) return _warn(context, 'Перерыв должен быть внутри пары: ${slotRange(slot)}');
    Haptics.selection();
    store.setBellProfile(bellKey, p.withSlot(n, next));
  }

  void _toggleBreak(BuildContext context, AppStore store, BellProfile p, BellSlot slot) {
    Haptics.selection();
    if (slot.hasBreak) {
      store.setBellProfile(bellKey, p.withSlot(n, slot.withoutBreak()));
      return;
    }
    if (slot.minutes < _defaultBreak + 4) return _warn(context, 'Пара слишком короткая для перерыва');
    final bs = slot.start + (slot.minutes - _defaultBreak) ~/ 2;
    store.setBellProfile(bellKey, p.withSlot(n, BellSlot(start: slot.start, end: slot.end, breakStart: bs, breakEnd: bs + _defaultBreak)));
  }

  void _delete(BuildContext context, AppStore store, BellProfile p) {
    final messenger = ScaffoldMessenger.of(context);
    final key = bellKey;
    Haptics.light();
    store.setBellProfile(key, p.withSlot(n, null));
    Navigator.of(context).pop();
    showUndo(messenger, '$n пара удалена', () => store.setBellProfile(key, p));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final tt = context.tt;
    final p = store.settings.bell(bellKey);
    final s = p[n];
    if (s == null) {
      return SheetScaffold(
        title: '$n пара',
        subtitle: 'Пара удалена',
        footer: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово'))),
        children: const [SizedBox(height: 8)],
      );
    }
    return SheetScaffold(
      title: '$n пара',
      subtitle: '${bellTitle(bellKey)} · ${spanText(s.minutes)}',
      leading: NumberBadge('$n', tone: hueTone(context, kSubjectHues[(n - 1) % kSubjectHues.length]), size: 52, round: false),
      trailing: IconButton(
        tooltip: 'Удалить пару',
        icon: Icon(Icons.delete_outline_rounded, color: cs.error),
        onPressed: () => _delete(context, store, p),
      ),
      footer: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово'))),
      children: [
        const SizedBox(height: 4),
        FieldTile(
          label: 'Начало',
          icon: Icons.login_rounded,
          valueLabel: fmtMin(s.start),
          trailing: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
          onTap: () => _pickStart(context, store, p, s),
        ),
        const SizedBox(height: 8),
        FieldTile(
          label: 'Конец',
          icon: Icons.logout_rounded,
          valueLabel: fmtMin(s.end),
          trailing: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
          onTap: () => _pickEnd(context, store, p, s),
        ),
        const SizedBox(height: 8),
        Material(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _toggleBreak(context, store, p, s),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(children: [
                Icon(s.lunchInside ? Icons.restaurant_rounded : Icons.coffee_rounded, color: s.hasBreak ? cs.tertiary : cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Перерыв внутри пары', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      s.hasBreak ? (s.lunchInside ? 'Обед внутри пары: ${halvesText(s)}' : 'Две половины: ${halvesText(s)}') : 'Например, две половины по 45 минут',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ]),
                ),
                SettingsSwitch(value: s.hasBreak, onChanged: (_) => _toggleBreak(context, store, p, s)),
              ]),
            ),
          ),
        ),
        if (s.hasBreak) ...[
          const SizedBox(height: 12),
          _HalvesBar(slot: s),
          const SizedBox(height: 12),
          FieldTile(
            label: s.lunchInside ? 'Обед с' : 'Перерыв с',
            icon: Icons.pause_circle_outline_rounded,
            valueLabel: fmtMin(s.breakStart!),
            trailing: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
            onTap: () => _pickBreak(context, store, p, s, start: true),
          ),
          const SizedBox(height: 8),
          FieldTile(
            label: s.lunchInside ? 'Обед до' : 'Перерыв до',
            icon: Icons.play_circle_outline_rounded,
            valueLabel: fmtMin(s.breakEnd!),
            trailing: Icon(Icons.edit_outlined, color: cs.onSurfaceVariant),
            onTap: () => _pickBreak(context, store, p, s, start: false),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// Схема пары: первая половина, перерыв и вторая половина. Длины пропорциональны минутам,
/// но перерыв никогда не уже [_minGap], иначе значок в нём обрезается (перерыв в 5 минут).
class _HalvesBar extends StatelessWidget {
  const _HalvesBar({required this.slot});
  final BellSlot slot;

  static const double _minGap = 40;
  static const double _space = 3;
  static const double _height = 34;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final a = slot.firstHalf < 1 ? 1 : slot.firstHalf;
    final gap = slot.breakMinutes < 1 ? 1 : slot.breakMinutes;
    final b = slot.secondHalf < 1 ? 1 : slot.secondHalf;

    Widget block(double w, Color bg, Widget child) => Container(
          width: w,
          height: _height,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: child,
        );
    Widget half(double w, int minutes) => block(
          w,
          cs.primaryContainer,
          Text('$minutes', maxLines: 1, overflow: TextOverflow.clip, style: context.tt.labelLarge?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
        );

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: LayoutBuilder(builder: (context, box) {
        final free = (box.maxWidth - _space * 2).clamp(0.0, double.infinity).toDouble();
        final gapW = (free * gap / (a + gap + b)).clamp(_minGap, free * 0.5 < _minGap ? _minGap : free * 0.5).toDouble();
        final rest = (free - gapW).clamp(0.0, double.infinity).toDouble();
        final wa = rest * a / (a + b);
        final wb = rest - wa;
        return TweenAnimationBuilder<double>(
          key: ValueKey('${slot.firstHalf}-${slot.breakMinutes}-${slot.secondHalf}'),
          tween: Tween<double>(begin: 0.85, end: 1),
          duration: Motion.ms(380),
          curve: Motion.spring,
          builder: (context, v, child) => Transform.scale(scale: v, child: child),
          child: Row(children: [
            half(wa, slot.firstHalf),
            const SizedBox(width: _space),
            block(gapW, cs.tertiaryContainer, Icon(slot.lunchInside ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 16, color: cs.onTertiaryContainer)),
            const SizedBox(width: _space),
            half(wb, slot.secondHalf),
          ]),
        );
      }),
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
        _Stepper(label: 'Перерыв внутри пары', zeroLabel: 'нет', value: inner, min: 0, max: 20, step: 5, suffix: ' мин', onChanged: (v) => setState(() => inner = v)),
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
            last == null
                ? 'Слишком поздно: пары не помещаются в сутки.'
                : 'Получится: 1 пара в ${fmtMin(preview.slots[1]!.start)}, ${preview.slots.length}-я заканчивается в ${fmtMin(last.end)}.'
                    '${preview.slots[1]!.hasBreak ? ' Пара: ${halvesText(preview.slots[1]!)}.' : ''}',
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
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.step, required this.suffix, required this.onChanged, this.zeroLabel});
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String suffix;
  final ValueChanged<int> onChanged;

  /// Что показывать вместо нуля (например, «нет»).
  final String? zeroLabel;

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
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 64),
              child: Text(
                value == 0 && zeroLabel != null ? zeroLabel! : '$value$suffix',
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
