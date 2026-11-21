part of 'settings_pages.dart';

class AbsenceSettingsPage extends StatelessWidget {
  const AbsenceSettingsPage({super.key});

  Future<void> _end(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final t = today();
    final sem = store.semesterOn(t);
    final ok = await confirmDialog(
      context,
      title: 'Завершить 1-й семестр?',
      message: 'С ${fullDate(t)} начнётся 2-й семестр: счётчик в $kSemesterLimit часов начнётся заново и закончится '
          '1 августа ${sem.year + 1}. Пропуски 1-го семестра останутся в журнале.',
      confirmLabel: 'Завершить',
    );
    if (!ok || !context.mounted) return;
    if (!store.endFirstSemester(t)) return;
    Haptics.medium();
    showUndo(messenger, 'Начался 2-й семестр', () => store.reopenFirstSemester(sem.year));
  }

  Future<void> _reopen(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final sem = store.semesterOn();
    final split = semesterSplit(sem.year, store.settings.semesterSplits);
    final ok = await confirmDialog(
      context,
      title: 'Вернуть 1-й семестр?',
      message: 'Завершение 1-го семестра отменится, а пропуски 2-го семестра снова будут считаться в 1-м.',
      confirmLabel: 'Вернуть',
      destructive: true,
    );
    if (!ok || !context.mounted || split == null) return;
    store.reopenFirstSemester(sem.year);
    Haptics.medium();
    showUndo(messenger, '1-й семестр возвращён', () => store.endFirstSemester(split));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = context.cs;
    final now = journalNow();
    final sem = store.semesterOn(now);
    final hours = semesterUnexcusedHours(store.absences, sem);
    final month = monthUnexcusedHours(store.absences, now);
    final canEnd = canEndSemester(now, store.settings.semesterSplits);
    final second = sem.number == 2;
    final tone = Tone(cs.secondaryContainer, cs.onSecondaryContainer);

    final String period;
    if (sem.upcoming) {
      period = 'Каникулы. ${sem.title} начнётся ${fullDate(sem.start)}.';
    } else if (second) {
      period = 'Идёт с ${fullDate(sem.start)} и закончится ${fullDate(sem.end)}.';
    } else {
      period = 'Идёт с ${fullDate(sem.start)}. Закончится, когда вы нажмёте кнопку ниже.';
    }

    return SettingsScaffold(title: 'Пропуски', children: [
      const SectionHeader('Быстрый пропуск', top: 0),
      const HoursSelector(),
      const SectionHeader('Семестр'),
      Appear(
        index: 1,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sem.title, style: context.tt.titleLarge?.copyWith(color: tone.fg, fontWeight: JournalType.heading)),
                  Text('Учебный год ${sem.years}', style: context.tt.bodyMedium?.copyWith(color: tone.fg.withValues(alpha: 0.85))),
                ]),
              ),
              Text('$hours / $kSemesterLimit ч', style: context.tt.titleMedium?.copyWith(color: tone.fg, fontWeight: JournalType.heading)),
            ]),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(end: hours / kSemesterLimit),
              duration: Motion.ms(500),
              curve: Motion.standard,
              builder: (context, v, _) => Bar(
                value: v,
                color: hours >= kSemesterLimit ? absenceAccent(context, excused: false) : cs.primary,
                track: tone.fg.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(height: 12),
            Text(period, style: context.tt.bodyMedium?.copyWith(color: tone.fg, height: 1.35)),
            Smooth(
              child: canEnd
                  ? Padding(
                      key: const ValueKey('end'),
                      padding: const EdgeInsets.only(top: 16),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.flag_rounded),
                        label: const Text('Завершить 1-й семестр'),
                        onPressed: () => _end(context),
                      ),
                    )
                  : second
                      ? Padding(
                          key: const ValueKey('reopen'),
                          padding: const EdgeInsets.only(top: 16),
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Вернуть 1-й семестр'),
                            onPressed: () => _reopen(context),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
            ),
          ]),
        ),
      ),
      const SectionHeader('Лимиты'),
      SegmentCard(
        index: 0,
        count: 2,
        child: SettingsTile(
          icon: Icons.calendar_month_rounded,
          title: 'В месяц: $kMonthLimit ч',
          subtitle: 'Сейчас $month ч без уважительной. Счётчик обнуляется с 1-го числа каждого месяца',
        ),
      ),
      SegmentCard(
        index: 1,
        count: 2,
        child: SettingsTile(
          icon: Icons.school_rounded,
          title: 'В семестр: $kSemesterLimit ч',
          subtitle: 'Предупреждение с $kSemesterWarnFrom ч без уважительной причины',
        ),
      ),
    ]);
  }
}
