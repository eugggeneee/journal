import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../kit/ctx.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import 'grade_sheet.dart';
import 'grades_page.dart';

/// Оценки по одному предмету: средний балл, динамика и список.
class SubjectPage extends StatelessWidget {
  const SubjectPage({super.key, required this.subject});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final grades = store.gradesOf(subject)
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });
    final avg = grades.isEmpty ? null : grades.fold<int>(0, (a, g) => a + g.value) / grades.length;
    final tone = gradeTone(context, avg ?? 0);
    final chrono = grades.reversed.toList();
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
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(32)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(fmtAvg(avg!), style: context.tt.displayMedium?.copyWith(color: tone.fg, fontWeight: FontWeight.w800, height: 1)),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text('средний балл', style: context.tt.titleSmall?.copyWith(color: tone.fg)),
                      ),
                    ]),
                    if (trend != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(trend, style: context.tt.bodyMedium?.copyWith(color: tone.fg)),
                      ),
                    const SizedBox(height: 16),
                    Spark(grades: chrono.length > 24 ? chrono.sublist(chrono.length - 24) : chrono, height: 44, barWidth: 9),
                    const SizedBox(height: 8),
                    Text('${gradesText(grades.length)} · от ${grades.reduce((a, b) => a.value < b.value ? a : b).value} до ${grades.reduce((a, b) => a.value > b.value ? a : b).value}',
                        style: context.tt.bodySmall?.copyWith(color: tone.fg.withValues(alpha: 0.9))),
                  ]),
                ),
                const SectionHeader('Все оценки'),
                for (var i = 0; i < grades.length; i++)
                  GradeTile(grade: grades[i], store: store, index: i, count: grades.length, showSubject: false),
              ]),
            const SliverToBoxAdapter(child: SizedBox(height: kFabClearance)),
          ],
        ),
      ),
      backgroundColor: cs.surface,
    );
  }
}
