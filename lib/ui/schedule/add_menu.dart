import 'package:material_ui/material_ui.dart';

import '../absences/absence_sheet.dart';
import '../grades/grade_sheet.dart';
import '../kit/ctx.dart';
import '../kit/sheet.dart';
import 'marks.dart';

/// Выбор: что добавить на выбранную дату.
Future<void> showAddMenu(BuildContext context, DateTime date) =>
    showAdaptiveSheet<void>(context, (_) => _AddMenu(date: date));

class _AddMenu extends StatelessWidget {
  const _AddMenu({required this.date});
  final DateTime date;

  void _open(BuildContext context, void Function(BuildContext host) action) {
    final host = Navigator.of(context).context;
    Navigator.of(context).pop();
    action(host);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Добавить',
      subtitle: dayCaption(date),
      children: [
        _BigTile(
          icon: Icons.star_rounded,
          bg: gradeTone(context, 9).bg,
          fg: gradeTone(context, 9).fg,
          title: 'Оценка',
          text: 'Записать оценку по предмету',
          onTap: () => _open(context, (h) => showGradeSheet(h, date: date)),
        ),
        const SizedBox(height: 10),
        _BigTile(
          icon: Icons.event_busy_rounded,
          bg: absenceTone(context, excused: false).bg,
          fg: absenceTone(context, excused: false).fg,
          title: 'Пропуск',
          text: 'Выбрать причину и отметить пары',
          onTap: () => _open(context, (h) => showAbsenceSheet(h, date: date)),
        ),
        const SizedBox(height: 10),
        _BigTile(
          icon: Icons.bookmark_rounded,
          bg: markTone(context).bg,
          fg: markTone(context).fg,
          title: 'Пометка',
          text: 'ОКР, зачёт, практика — на день или пару',
          onTap: () => _open(context, (h) => showMarkSheet(h, date)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({required this.icon, required this.bg, required this.fg, required this.title, required this.text, required this.onTap});
  final IconData icon;
  final Color bg;
  final Color fg;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Icon(icon, size: 30, color: fg),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: context.tt.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w800)),
                  Text(text, style: context.tt.bodyMedium?.copyWith(color: fg.withValues(alpha: 0.85))),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ]),
          ),
        ),
      );
}
