import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../data/models.dart';
import '../../logic/bells.dart';
import '../kit/ctx.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import 'bells_page.dart';

/// Звонки на выбранный день: время каждой пары, перерыв внутри пары, перерывы между парами и обед.
Future<void> showBellsSheet(BuildContext context, DateTime date) =>
    showAdaptiveSheet<void>(context, (_) => _BellsSheet(date: date));

class _BellsSheet extends StatelessWidget {
  const _BellsSheet({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final key = bellKeyFor(date);
    final profile = store.settings.bell(key);
    return SheetScaffold(
      title: 'Звонки',
      subtitle: '${bellTitle(key)} · ${dayCaption(date)}',
      leading: CookieIcon(icon: Icons.notifications_active_rounded, size: 52, bg: cs.secondaryContainer, fg: cs.onSecondaryContainer),
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Настроить звонки'),
          onPressed: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => BellsPage(initialKey: key)));
          },
        ),
      ),
      children: [
        if (profile.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Время пар для этого вида дня ещё не задано. Его можно ввести вручную или заполнить автоматически.',
              textAlign: TextAlign.center,
              style: context.tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
          )
        else
          BellTimeline(profile: profile),
      ],
    );
  }
}

/// Лента звонков: пары и между ними перерывы (обед выделен).
class BellTimeline extends StatelessWidget {
  const BellTimeline({super.key, required this.profile});
  final BellProfile profile;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final nums = profile.slots.keys.toList()..sort();
    final rows = <Widget>[];
    for (final n in nums) {
      final slot = profile.slots[n]!;
      rows.add(Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        NumberBadge('$n', tone: Tone(cs.primaryContainer, cs.onPrimaryContainer), size: 44, round: false),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slotRange(slot), style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            if (slot.hasBreak)
              Row(children: [
                Icon(slot.lunchInside ? Icons.restaurant_rounded : Icons.coffee_rounded, size: 14, color: cs.tertiary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${fmtMin(slot.start)}–${fmtMin(slot.breakStart!)} · ${innerBreakWord(slot)} ${minText(slot.breakMinutes)} · ${fmtMin(slot.breakEnd!)}–${fmtMin(slot.end)}',
                    style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ]),
          ]),
        ),
        Text(halvesText(slot), style: context.tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
      ]));
      final gap = gapLabel(profile, n);
      if (gap != null) {
        final lunch = profile.isLunchAfter(n);
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(58, 8, 0, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Pill(
              gap,
              tone: lunch ? Tone(cs.tertiaryContainer, cs.onTertiaryContainer) : Tone(cs.surfaceContainerHighest, cs.onSurfaceVariant),
              icon: lunch ? Icons.restaurant_rounded : Icons.timer_outlined,
            ),
          ),
        ));
      } else if (n != nums.last) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}
