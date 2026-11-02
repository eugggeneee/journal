import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/stats.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import 'absence_sheet.dart';

class AbsencesPage extends StatefulWidget {
  const AbsencesPage({super.key});
  @override
  State<AbsencesPage> createState() => _AbsencesPageState();
}

class _AbsencesPageState extends State<AbsencesPage> {
  int _mode = 0;
  int _filter = 0; // 0 все, 1 без уважительной, 2 по уважительной

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final empty = store.absences.isEmpty;
    final stats = AbsenceStats.of(store.absences);

    return LargePage(
      title: 'Пропуски',
      subtitle: empty ? 'Посещаемость' : '${hoursText(stats.totalHours)} пропущено',
      slivers: empty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.event_available_rounded,
                  title: 'Пропусков нет',
                  message: 'Отмечайте пропуски прямо в расписании: нажмите на значок у пары — сразу выберете причину.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить пропуск'),
                    onPressed: () => showAbsenceSheet(context),
                  ),
                ),
              ),
            ]
          : [
              Inset(children: [
                AbsencesHero(stats: stats),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, icon: Icon(Icons.history_rounded), label: Text('Журнал')),
                      ButtonSegment(value: 1, icon: Icon(Icons.menu_book_rounded), label: Text('Предметы')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      Haptics.selection();
                      setState(() => _mode = s.first);
                    },
                  ),
                ),
              ]),
              if (_mode == 0) ..._journal(context, store) else ..._subjects(context, store, stats),
            ],
    );
  }

  List<Widget> _journal(BuildContext context, AppStore store) {
    final sorted = store.absences.where((a) => _filter == 0 || (_filter == 1 ? !a.excused : a.excused)).toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : a.lesson.compareTo(b.lesson);
      });
    final byDay = <String, List<Absence>>{};
    for (final a in sorted) {
      byDay.putIfAbsent(ymd(a.date), () => []).add(a);
    }
    return [
      SliverToBoxAdapter(
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ChoiceTag(label: 'Все', selected: _filter == 0, onTap: () => setState(() => _filter = 0)),
              const SizedBox(width: 8),
              ChoiceTag(label: 'Без уважительной', selected: _filter == 1, onTap: () => setState(() => _filter = 1)),
              const SizedBox(width: 8),
              ChoiceTag(label: 'По уважительной', selected: _filter == 2, onTap: () => setState(() => _filter = 2)),
            ],
          ),
        ),
      ),
      if (byDay.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Нет пропусков с таким фильтром'))),
        ),
      for (final e in byDay.entries)
        Inset(children: [
          SectionHeader(
            longDate(e.value.first.date),
            trailing: hoursText(e.value.fold<int>(0, (s, a) => s + a.hours)),
            top: 12,
          ),
          for (var i = 0; i < e.value.length; i++) _AbsenceTile(absence: e.value[i], store: store, index: i, count: e.value.length),
        ]),
    ];
  }

  List<Widget> _subjects(BuildContext context, AppStore store, AbsenceStats stats) {
    final entries = stats.bySubjectHours.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxV = entries.isEmpty ? 1 : entries.first.value;
    return [
      Inset(top: 8, children: [
        SectionHeader('Часы по предметам', trailing: subjectsText(entries.length)),
        for (var i = 0; i < entries.length; i++)
          SegmentCard(
            index: i,
            count: entries.length,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      entries[i].key.isEmpty ? 'Без предмета' : store.subjectName(entries[i].key),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(hoursText(entries[i].value), style: context.tt.labelLarge?.copyWith(color: context.cs.onSurfaceVariant)),
                ]),
                const SizedBox(height: 12),
                Bar(value: entries[i].value / maxV, color: absenceAccent(context, excused: false)),
              ]),
            ),
          ),
      ]),
    ];
  }
}

/// Итоговая карточка пропусков: всего часов и доля уважительных. Цвета — из палитры Material Design.
class AbsencesHero extends StatelessWidget {
  const AbsencesHero({super.key, required this.stats});
  final AbsenceStats stats;

  @override
  Widget build(BuildContext context) {
    final tone = absenceTone(context, excused: false);
    final fg = tone.fg;
    final unex = stats.unexcusedHours;
    final ex = stats.excusedHours;
    final pairsValue = stats.totalHours / 2;
    final pairs = stats.totalHours.isEven
        ? '≈ ${pairsText(pairsValue.round())}'
        : '≈ ${pairsValue.toStringAsFixed(1).replaceAll('.', ',')} пары';
    final unexColor = absenceAccent(context, excused: false);
    final exColor = absenceAccent(context, excused: true);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Всего пропущено', style: context.tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text('${stats.totalHours}', style: context.tt.displayMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.05)),
          const SizedBox(width: 8),
          Text(plural(stats.totalHours, 'час', 'часа', 'часов'), style: context.tt.titleMedium?.copyWith(color: fg)),
          const Spacer(),
          Text(pairs, style: context.tt.titleSmall?.copyWith(color: fg)),
        ]),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              if (unex > 0) Expanded(flex: unex, child: ColoredBox(color: unexColor)),
              if (unex > 0 && ex > 0) const SizedBox(width: 3),
              if (ex > 0) Expanded(flex: ex, child: ColoredBox(color: exColor)),
              if (unex == 0 && ex == 0) Expanded(child: ColoredBox(color: fg.withValues(alpha: 0.2))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Legend(color: unexColor, label: 'Без уважительной', hours: unex, fg: fg)),
          const SizedBox(width: 12),
          Expanded(child: _Legend(color: exColor, label: 'По уважительной', hours: ex, fg: fg)),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, required this.hours, required this.fg});
  final Color color;
  final String label;
  final int hours;
  final Color fg;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$hours ч', style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
            Text(label, style: context.tt.bodySmall?.copyWith(color: fg.withValues(alpha: 0.85))),
          ]),
        ),
      ]);
}

class _AbsenceTile extends StatelessWidget {
  const _AbsenceTile({required this.absence, required this.store, required this.index, required this.count});
  final Absence absence;
  final AppStore store;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final a = absence;
    final tone = absenceTone(context, excused: a.excused);
    final sub = [
      if (a.lesson > 0) '${a.lesson} пара',
      hoursText(a.hours),
      if (a.excused) 'уважительная',
      if (a.note.isNotEmpty) a.note,
    ].join(' · ');
    return SegmentCard(
      index: index,
      count: count,
      dismissKey: ValueKey('a-${a.id}'),
      swipeRightIcon: a.excused ? Icons.event_busy_rounded : Icons.verified_rounded,
      onSwipeRight: () {
        final m = ScaffoldMessenger.of(context);
        final before = store.snapshotDay(a.date);
        store.saveAbsence(a.copyWith(excused: !a.excused));
        Haptics.selection();
        showUndo(m, a.excused ? 'Отмечено как неуважительная' : 'Отмечено как уважительная', () => store.restoreDay(a.date, before));
      },
      onDelete: () {
        final m = ScaffoldMessenger.of(context);
        final before = store.snapshotDay(a.date);
        store.deleteAbsence(a.id);
        Haptics.medium();
        showUndo(m, 'Пропуск удалён', () => store.restoreDay(a.date, before));
      },
      onTap: () => showAbsenceSheet(context, edit: a),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          NumberBadge(a.lesson > 0 ? '${a.lesson}' : '–', tone: tone, size: 46, round: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                a.subject.isEmpty ? 'Без предмета' : store.subjectName(a.subject),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}
