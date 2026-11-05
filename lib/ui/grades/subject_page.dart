import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../app/scope.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/overview.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/ctx.dart';
import 'grade_sheet.dart';
import 'grades_page.dart';

/// Оценки по одному предмету: средний балл, динамика и список.
class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key, required this.subject});
  final String subject;

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final FreshTracker _fresh = FreshTracker();

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    final store = StoreScope.of(context);
    final cs = context.cs;
    final grades = store.gradesOf(subject)
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    _fresh.sync(grades.map((g) => g.id));
    final avg = grades.isEmpty ? null : grades.fold<int>(0, (a, g) => a + g.value) / grades.length;
    final tone = gradeTone(context, avg ?? 0);
    final chrono = grades.reversed.toList();
    final minValue = grades.isEmpty ? 0 : grades.map((g) => g.value).reduce((a, b) => a < b ? a : b);
    final maxValue = grades.isEmpty ? 0 : grades.map((g) => g.value).reduce((a, b) => a > b ? a : b);
    String? trend;
    if (grades.length >= 2) {
      final before = chrono.sublist(0, chrono.length - 1);
      final prev = before.fold<int>(0, (a, g) => a + g.value) / before.length;
      final diff = avg! - prev;
      if (diff.abs() >= 0.005) {
        trend = '${diff > 0 ? '+' : '−'}${fmtAvg(diff.abs())} после последней оценки';
      }
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGradeSheet(context, subject: subject),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Оценка'),
      ),
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: Text(store.subjectName(subject))),
            if (grades.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.star_outline_rounded,
                  title: 'Оценок нет',
                  message: 'По этому предмету пока ничего не записано.',
                  action: FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Добавить оценку'),
                    onPressed: () => showGradeSheet(context, subject: subject),
                  ),
                ),
              )
            else
              Inset(children: [
                HeroCard(
                  tone: tone,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    HeroHeader(
                      caption: 'Средний балл',
                      fg: tone.fg,
                      value: AnimatedNumber(
                        value: avg!,
                        format: fmtAvg,
                        style: context.tt.displayMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1.05),
                      ),
                      aside: [gradesText(grades.length), 'от $minValue до $maxValue'],
                    ),
                    if (trend != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(trend, style: context.tt.bodyMedium?.copyWith(color: tone.fg)),
                      ),
                    const SizedBox(height: 16),
                    Spark(grades: chrono.length > 24 ? chrono.sublist(chrono.length - 24) : chrono, height: 44, barWidth: 9),
                  ]),
                ),
                const SectionHeader('Все оценки'),
                for (var i = 0; i < grades.length; i++)
                  Reveal(
                    key: ValueKey('gr-${grades[i].id}'),
                    animate: _fresh.isFresh(grades[i].id),
                    child: GradeTile(grade: grades[i], store: store, index: i, count: grades.length, showSubject: false),
                  ),
              ]),
            const SliverToBoxAdapter(child: SizedBox(height: kFabClearance)),
          ],
        ),
      ),
      backgroundColor: cs.surface,
    );
  }
}
