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
import 'grade_sheet.dart';
import 'subject_page.dart';

class GradesPage extends StatefulWidget {
  const GradesPage({super.key});
  @override
  State<GradesPage> createState() => _GradesPageState();
}

class _GradesPageState extends State<GradesPage> {
  int _mode = 0;
  String? _filter; // предмет в журнале

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final stats = GradeStats.of(store.grades);
    final empty = store.grades.isEmpty;

    return LargePage(
      title: 'Оценки',
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
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 0, icon: Icon(Icons.menu_book_rounded), label: Text('Предметы')),
                      ButtonSegment(value: 1, icon: Icon(Icons.history_rounded), label: Text('Журнал')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      Haptics.selection();
                      setState(() => _mode = s.first);
                    },
                  ),
                ),
              ]),
              if (_mode == 0) ..._subjects(context, store, stats) else ..._journal(context, store, stats),
            ],
    );
  }

  List<Widget> _subjects(BuildContext context, AppStore store, GradeStats stats) {
    final list = [...stats.subjects]..sort((a, b) => store.subjectName(a.subject).compareTo(store.subjectName(b.subject)));
    return [
      Inset(top: 8, children: [
        SectionHeader('Предметы', trailing: subjectsText(list.length)),
        for (var i = 0; i < list.length; i++) _SubjectCard(stat: list[i], index: i, count: list.length, store: store),
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
      SliverToBoxAdapter(
        child: SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              ChoiceTag(label: 'Все', selected: filter == null, onTap: () => setState(() => _filter = null)),
              for (final s in subjects) ...[
                const SizedBox(width: 8),
                ChoiceTag(label: store.subjectName(s), selected: filter == s, onTap: () => setState(() => _filter = s)),
              ],
            ],
          ),
        ),
      ),
      for (final e in byMonth.entries)
        Inset(children: [
          SectionHeader(e.key, trailing: gradesText(e.value.length), top: 12),
          for (var i = 0; i < e.value.length; i++) GradeTile(grade: e.value[i], store: store, index: i, count: e.value.length),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Средний балл', style: context.tt.titleSmall?.copyWith(color: tone.fg, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                fmtAvg(avg),
                style: context.tt.displayMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1.05),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(gradesText(stats.count), style: context.tt.titleSmall?.copyWith(color: tone.fg)),
            const SizedBox(height: 2),
            Text(subjectsText(stats.subjects.length), style: context.tt.titleSmall?.copyWith(color: tone.fg)),
          ]),
        ]),
        const SizedBox(height: 22),
        SizedBox(
          height: 84,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 10; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
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
    final cs = context.cs;
    final tone = gradeTone(context, stat.average);
    final impact = stat.lastImpact;
    final last = stat.grades.length > 12 ? stat.grades.sublist(stat.grades.length - 12) : stat.grades;
    return SegmentCard(
      index: index,
      count: count,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SubjectPage(subject: stat.subject))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.subjectName(stat.subject), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${gradesText(stat.count)} · последняя ${stat.last.value}', style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              Spark(grades: last),
            ]),
          ),
          const SizedBox(width: 12),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(18)),
              child: Text(fmtAvg(stat.average), style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800)),
            ),
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
        ]),
      ),
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
              Container(
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
    final cs = context.cs;
    final tone = gradeTone(context, grade.value);
    final sub = [if (showSubject && grade.kind.isNotEmpty) grade.kind, if (grade.note.isNotEmpty) grade.note].join(' · ');
    final title = showSubject ? store.subjectName(grade.subject) : (grade.kind.isEmpty ? 'Без пометки' : grade.kind);
    final subtitle = showSubject ? sub : grade.note;
    return SegmentCard(
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          NumberBadge('${grade.value}', tone: tone, size: 46, round: false),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (subtitle.isNotEmpty)
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(shortDate(grade.date), style: context.tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ]),
      ),
    );
  }
}
