import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/limits.dart';
import '../../logic/stats.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/reveal.dart';
import '../kit/select_sheet.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import '../settings/settings_pages.dart';
import 'absence_limit.dart';
import 'absence_sheet.dart';

class AbsencesPage extends StatefulWidget {
  const AbsencesPage({super.key});
  @override
  State<AbsencesPage> createState() => _AbsencesPageState();
}

class _AbsencesPageState extends State<AbsencesPage> with WidgetsBindingObserver {
  int _mode = 0;
  int _filter = 0; // 0 все, 1 без уважительной, 2 по уважительной
  final FreshTracker _fresh = FreshTracker();
  final FreshTracker _freshSubjects = FreshTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Приложение могло пролежать в фоне до нового месяца — счётчики пересчитываются при возвращении.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _openSemester(BuildContext context, Semester sem, int hours) {
    showAdaptiveSheet<void>(context, (ctx) => _SemesterSheet(semester: sem, hours: hours));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final empty = store.absences.isEmpty;
    final stats = AbsenceStats.of(store.absences);
    final now = DateTime.now();
    final semester = store.semesterOn(now);
    final monthHours = monthUnexcusedHours(store.absences, now);
    final semesterHours = semesterUnexcusedHours(store.absences, semester);
    _fresh.sync(store.absences.map((a) => a.id));
    _freshSubjects.sync(stats.bySubjectHours.keys);

    return LargePage(
      title: 'Пропуски',
      subtitle: empty ? 'Посещаемость' : '${hoursText(stats.totalHours)} пропущено',
      slivers: empty
          ? [
              Inset(children: [
                LimitCounters(
                  monthHours: monthHours,
                  semesterHours: semesterHours,
                  semester: semester,
                  onSemesterTap: () => _openSemester(context, semester, semesterHours),
                ),
              ]),
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
                LimitBanners(monthHours: monthHours, semesterHours: semesterHours, semester: semester),
                LimitCounters(
                  monthHours: monthHours,
                  semesterHours: semesterHours,
                  semester: semester,
                  onSemesterTap: () => _openSemester(context, semester, semesterHours),
                ),
                const SizedBox(height: 12),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterButton(
              icon: Icons.filter_list_rounded,
              label: const ['Все пропуски', 'Без уважительной', 'По уважительной'][_filter],
              active: _filter != 0,
              onClear: () => setState(() => _filter = 0),
              onTap: () => showSelectSheet<int>(
                context,
                title: 'Показать пропуски',
                value: _filter,
                options: const [
                  MenuOption(0, 'Все пропуски', icon: Icons.apps_rounded),
                  MenuOption(1, 'Без уважительной', icon: Icons.event_busy_rounded),
                  MenuOption(2, 'По уважительной', icon: Icons.verified_rounded),
                ],
                onSelected: (v) => setState(() => _filter = v),
              ),
            ),
          ),
        ),
      ),
      if (byDay.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Нет пропусков с таким фильтром'))),
        ),
      for (final e in byDay.entries)
        Inset(key: ValueKey('day-${e.key}'), children: [
          SectionHeader(
            longDate(e.value.first.date),
            trailing: hoursText(e.value.fold<int>(0, (s, a) => s + a.hours)),
            top: 12,
          ),
          for (var i = 0; i < e.value.length; i++)
            Reveal(
              key: ValueKey('ab-${e.value[i].id}'),
              animate: _fresh.isFresh(e.value[i].id),
              child: _AbsenceTile(absence: e.value[i], store: store, index: i, count: e.value.length),
            ),
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
          Reveal(
            key: ValueKey('subj-${entries[i].key}'),
            animate: _freshSubjects.isFresh(entries[i].key),
            child: SegmentCard(
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
                _AnimatedBar(value: entries[i].value / maxV, color: absenceAccent(context, excused: false)),
              ]),
            ),
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
    return Appear(
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(32)),
      child: ArtCircles(
      color: fg,
      radius: 32,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Всего за всё время', style: context.tt.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          AnimatedNumber(value: stats.totalHours.toDouble(), format: (v) => '${v.round()}', style: context.tt.displayMedium?.copyWith(color: fg, fontWeight: FontWeight.w800, height: 1.05)),
          const SizedBox(width: 8),
          Text(plural(stats.totalHours, 'час', 'часа', 'часов'), style: context.tt.titleMedium?.copyWith(color: fg)),
          const Spacer(),
          Text(pairs, style: context.tt.titleSmall?.copyWith(color: fg)),
        ]),
        const SizedBox(height: 18),
        _SplitBar(unexcused: unex, excused: ex, unexColor: unexColor, exColor: exColor, gapColor: tone.bg, emptyColor: fg.withValues(alpha: 0.2)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Legend(color: unexColor, label: 'Без уважительной', hours: unex, fg: fg)),
          const SizedBox(width: 12),
          Expanded(child: _Legend(color: exColor, label: 'По уважительной', hours: ex, fg: fg)),
        ]),
      ]),
      ),
      ),
      ),
    );
  }
}

/// Двухцветная шкала «без уважительной / по уважительной»: границы плавно сдвигаются при изменении данных.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.unexcused,
    required this.excused,
    required this.unexColor,
    required this.exColor,
    required this.gapColor,
    required this.emptyColor,
  });
  final int unexcused;
  final int excused;
  final Color unexColor;
  final Color exColor;
  final Color gapColor;
  final Color emptyColor;

  @override
  Widget build(BuildContext context) {
    final total = unexcused + excused;
    final share = total == 0 ? 0.0 : unexcused / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 12,
        child: LayoutBuilder(builder: (context, box) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(end: share),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) {
              final inner = v > 0.001 && v < 0.999;
              return Stack(children: [
                Positioned.fill(child: ColoredBox(color: total == 0 ? emptyColor : exColor)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: box.maxWidth * v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: unexColor,
                      border: Border(right: BorderSide(color: gapColor, width: inner ? 3 : 0)),
                    ),
                  ),
                ),
              ]);
            },
          );
        }),
      ),
    );
  }
}

/// Полоса прогресса, которая плавно подрастает или сокращается.
class _AnimatedBar extends StatelessWidget {
  const _AnimatedBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Bar(value: v, color: color),
      );
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


/// Подробности семестра: период, часы и переход к настройкам (там же кнопка «Завершить 1-й семестр»).
class _SemesterSheet extends StatelessWidget {
  const _SemesterSheet({required this.semester, required this.hours});
  final Semester semester;
  final int hours;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final left = kSemesterLimit - hours;
    final period = semester.upcoming
        ? 'Начнётся ${fullDate(semester.start)}'
        : '${fullDate(semester.start)} — ${semester.number == 1 && !StoreScope.of(context).settings.semesterSplits.containsKey('${semester.year}') ? 'до конца 1-го семестра' : fullDate(semester.end)}';
    return SheetScaffold(
      title: semester.title,
      subtitle: 'Учебный год ${semester.years}',
      leading: CookieIcon(icon: Icons.school_rounded, size: 52, bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Настройки семестра'),
          onPressed: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => const AbsenceSettingsPage()));
          },
        ),
      ),
      children: [
        _row(context, Icons.event_rounded, 'Период', period),
        _row(context, Icons.event_busy_rounded, 'Без уважительной причины', '${hoursText(hours)} из $kSemesterLimit'),
        _row(
          context,
          Icons.hourglass_bottom_rounded,
          'Осталось до лимита',
          left > 0 ? hoursText(left) : 'лимит ${left == 0 ? 'достигнут' : 'превышен'}',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Считаются только пропуски без уважительной причины. Первый семестр идёт с 1 сентября, пока вы не завершите его '
            'в настройках; сразу после этого начинается второй — до 1 августа.',
            style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String value) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, size: 22, color: cs.onSecondaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            Text(value, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
