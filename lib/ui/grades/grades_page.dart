import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../data/store.dart';
import '../../logic/stats.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/overview.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import '../kit/sheets/select_sheet.dart';
import 'grade_sheet.dart';
import 'subject_page.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});
  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  int _mode = 0; // 0 — предметы, 1 — журнал
  String? _filter; // предмет в журнале
  final FreshTracker _freshGrades = FreshTracker();
  final FreshTracker _freshSubjects = FreshTracker();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final stats = GradeStats.of(store.grades);
    final empty = store.grades.isEmpty;
    _freshGrades.sync(store.grades.map((g) => g.id));
    _freshSubjects.sync(stats.subjects.map((s) => s.subject));

    return LargePage(
      title: 'Оценки',
      subtitle: empty ? 'Успеваемость' : '${gradesText(stats.count)} · ${subjectsText(stats.subjects.length)}',
      slivers: empty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.star_rounded,
                  title: 'Оценок пока нет',
                  message: 'Записывайте оценки с пометками — приложение посчитает средний балл по каждому предмету.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить оценку'),
                    onPressed: () => showGradeSheet(context),
                  ),
                ),
              ),
            ]
          : [
              Inset(children: [
                GradesHero(stats: stats),
                const SizedBox(height: 16),
                ModeSwitch(value: _mode, onChanged: (m) => setState(() => _mode = m)),
              ]),
              FadeInSlivers(
                key: ValueKey('grades-mode-$_mode'),
                slivers: _mode == 0 ? _subjects(context, store, stats) : _journal(context, store, stats),
              ),
            ],
    );
  }

  List<Widget> _subjects(BuildContext context, AppStore store, GradeStats stats) {
    final list = [...stats.subjects]..sort((a, b) => store.subjectName(a.subject).compareTo(store.subjectName(b.subject)));
    return [
      Inset(top: 8, children: [
        SectionHeader('Предметы', trailing: subjectsText(list.length)),
        for (var i = 0; i < list.length; i++)
          Reveal(
            key: ValueKey('sub-${list[i].subject}'),
            animate: _freshSubjects.isFresh(list[i].subject),
            child: _SubjectCard(stat: list[i], index: i, count: list.length, store: store),
          ),
      ]),
    ];
  }

  List<Widget> _journal(BuildContext context, AppStore store, GradeStats stats) {
    final subjects = [...stats.subjects.map((s) => s.subject)]..sort((a, b) => store.subjectName(a).compareTo(store.subjectName(b)));
    final filter = (_filter != null && subjects.contains(_filter)) ? _filter : null;
    final sorted = store.grades.where((g) => filter == null || g.subject == filter).toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final byMonth = <String, List<Grade>>{};
    for (final g in sorted) {
      byMonth.putIfAbsent(monthYear(g.date), () => []).add(g);
    }
    return [
      SliverFilterRow(
        label: filter == null ? 'Все предметы' : store.subjectName(filter),
        active: filter != null,
        onClear: () => setState(() => _filter = null),
        onTap: () => showSelectSheet<String>(
          context,
          title: 'Предмет',
          subtitle: 'Показать оценки только по одному предмету',
          value: filter ?? '',
          options: [
            const MenuOption('', 'Все предметы', icon: Icons.apps_rounded),
            for (final s in subjects) MenuOption(s, store.subjectName(s), icon: Icons.menu_book_outlined),
          ],
          onSelected: (v) => setState(() => _filter = v.isEmpty ? null : v),
        ),
      ),
      for (final e in byMonth.entries)
        Inset(key: ValueKey('month-${e.key}'), children: [
          SectionHeader(e.key, trailing: gradesText(e.value.length), top: 12),
          for (var i = 0; i < e.value.length; i++)
            Reveal(
              key: ValueKey('gr-${e.value[i].id}'),
              animate: _freshGrades.isFresh(e.value[i].id),
              child: GradeTile(grade: e.value[i], store: store, index: i, count: e.value.length),
            ),
        ]),
    ];
  }
}

/// Итоговая карточка: средний балл и распределение оценок.
class GradesHero extends StatelessWidget {
  const GradesHero({super.key, required this.stats});
  final GradeStats stats;

  @override
  Widget build(BuildContext context) {
    final avg = stats.average ?? 0;
    final tone = gradeTone(context, avg);
    final maxC = stats.distribution.reduce((a, b) => a > b ? a : b);
    return HeroCard(
      tone: tone,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HeroHeader(
          caption: 'Средний балл',
          fg: tone.fg,
          value: AnimatedNumber(
            value: avg,
            format: fmtAvg,
            style: context.tt.displayMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1.05),
          ),
          aside: [gradesText(stats.count), subjectsText(stats.subjects.length)],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 84,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 10; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AnimatedContainer(
                      duration: Motion.long,
                      curve: Motion.standard,
                      height: stats.distribution[i] == 0 || maxC == 0 ? 4 : 10 + 46 * stats.distribution[i] / maxC,
                      decoration: BoxDecoration(
                        color: stats.distribution[i] == 0 ? tone.fg.withValues(alpha: 0.2) : gradeAccent(context, i + 1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${i + 1}', style: context.tt.labelSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.stat, required this.index, required this.count, required this.store});
  final SubjectStat stat;
  final int index;
  final int count;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final tone = gradeTone(context, stat.average);
    final impact = stat.lastImpact;
    final last = stat.grades.length > 12 ? stat.grades.sublist(stat.grades.length - 12) : stat.grades;
    return OverviewCard(
      index: index,
      count: count,
      title: store.subjectName(stat.subject),
      subtitle: '${gradesText(stat.count)} · последняя ${stat.last.value}',
      bottom: Spark(grades: last),
      trailing: Column(mainAxisSize: MainAxisSize.min, children: [
        ValuePill(tone: tone, child: AnimatedNumber(value: stat.average, format: fmtAvg)),
        if (impact != null && impact.abs() >= 0.005)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              impact > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              size: 20,
              color: impact > 0 ? gradeAccent(context, 9) : gradeAccent(context, 2),
            ),
          ),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SubjectPage(subject: stat.subject))),
    );
  }
}

/// Мини-график оценок по порядку.
class Spark extends StatelessWidget {
  const Spark({super.key, required this.grades, this.height = 28, this.barWidth = 8});
  final List<Grade> grades;
  final double height;
  final double barWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final g in grades)
              AnimatedContainer(
                duration: Motion.long,
                curve: Motion.standard,
                width: barWidth,
                height: 4 + (height - 4) * g.value / 10,
                margin: const EdgeInsets.only(right: 3),
                decoration: BoxDecoration(color: gradeAccent(context, g.value), borderRadius: BorderRadius.circular(3)),
              ),
          ],
        ),
      );
}

class GradeTile extends StatelessWidget {
  const GradeTile({
    super.key,
    required this.grade,
    required this.store,
    required this.index,
    required this.count,
    this.showSubject = true,
  });
  final Grade grade;
  final AppStore store;
  final int index;
  final int count;
  final bool showSubject;

  @override
  Widget build(BuildContext context) {
    final tone = gradeTone(context, grade.value);
    final sub = [if (showSubject && grade.kind.isNotEmpty) grade.kind, if (grade.note.isNotEmpty) grade.note].join(' · ');
    final title = showSubject ? store.subjectName(grade.subject) : (grade.kind.isEmpty ? 'Без пометки' : grade.kind);
    final subtitle = showSubject ? sub : grade.note;
    return EntryTile(
      index: index,
      count: count,
      dismissKey: ValueKey('g-${grade.id}'),
      onDelete: () {
        final m = ScaffoldMessenger.of(context);
        store.deleteGrade(grade.id);
        Haptics.medium();
        showUndo(m, 'Оценка удалена', () => store.saveGrade(grade));
      },
      onTap: () => showGradeSheet(context, edit: grade),
      badge: NumberBadge('${grade.value}', tone: tone, size: 46, round: false),
      title: title,
      subtitle: subtitle,
      trailing: shortDate(grade.date),
    );
  }
}
