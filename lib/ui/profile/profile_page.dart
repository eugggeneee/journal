import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/haptics.dart';
import '../group_picker.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/selectors.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _refreshing = true);
    await StoreScope.repoOf(context).prefetch(force: true, respectSetting: false);
    if (!mounted) return;
    setState(() => _refreshing = false);
    showNote(messenger, 'Расписание обновлено');
  }

  Future<void> _export() async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    Haptics.medium();
    showNote(messenger, 'Копия в буфере обмена — сохраните её в заметках');
  }

  Future<void> _import() async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!mounted) return;
    if (text.trim().isEmpty) {
      await infoDialog(context, 'Буфер обмена пуст', 'Сначала скопируйте текст резервной копии.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Восстановить данные?',
      message: 'Текущие оценки и пропуски будут заменены данными из копии.',
      confirmLabel: 'Восстановить',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final err = store.importJson(text);
    if (err != null) {
      await infoDialog(context, 'Ошибка', err);
    } else {
      showNote(messenger, 'Данные восстановлены');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final store = StoreScope.of(context);
    final s = store.settings;
    final cached = store.schedulesFor(s.group).length;

    return LargePage(
      title: 'Профиль',
      slivers: [
        Inset(children: [
          Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openGroupPicker(context),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CookieIcon(icon: Icons.school_rounded, size: 68, bg: cs.primary, fg: cs.onPrimary),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Группа ${s.group}', style: context.tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('МГТЭК · нажмите, чтобы сменить', style: context.tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.85))),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onPrimaryContainer),
                ]),
              ),
            ),
          ),
          const SectionHeader('Расписание'),
          SegmentCard(
            index: 0,
            count: 1,
            onTap: _refreshing ? null : _refresh,
            child: _RowTile(
              icon: Icons.refresh_rounded,
              title: _refreshing ? 'Обновляю…' : 'Обновить расписание',
              subtitle: 'Сохранено: ${daysText(cached)} на устройстве',
              trailing: _refreshing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
            ),
          ),
          const SectionHeader('Оформление'),
          const SegmentCard(
            index: 0,
            count: 1,
            child: Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 16), child: ThemeSelector()),
          ),
          const SectionHeader('Быстрый пропуск'),
          SegmentCard(
            index: 0,
            count: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Столько часов отмечается, когда вы нажимаете значок пропуска у пары.',
                  style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                const HoursSelector(),
              ]),
            ),
          ),
          const SectionHeader('Поведение'),
          SegmentCard(
            index: 0,
            count: 2,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Icon(Icons.vibration_rounded, color: cs.primary),
              title: const Text('Виброотклик'),
              value: s.haptics,
              onChanged: store.setHaptics,
            ),
          ),
          SegmentCard(
            index: 1,
            count: 2,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              secondary: Icon(Icons.sync_rounded, color: cs.primary),
              title: const Text('Автообновление'),
              subtitle: const Text('Подгружать расписание при запуске'),
              value: s.autoRefresh,
              onChanged: store.setAutoRefresh,
            ),
          ),
          const SectionHeader('Данные'),
          SegmentCard(
            index: 0,
            count: 2,
            onTap: _export,
            child: const _RowTile(icon: Icons.content_copy_rounded, title: 'Сохранить копию', subtitle: 'Оценки и пропуски — в буфер обмена'),
          ),
          SegmentCard(
            index: 1,
            count: 2,
            onTap: _import,
            child: const _RowTile(icon: Icons.restore_rounded, title: 'Восстановить из копии', subtitle: 'Вставить данные из буфера обмена'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
            child: Text(
              'Оценки и пропуски хранятся только на этом устройстве. Расписание берётся с сайта bseumtc.by.',
              style: context.tt.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
        ]),
      ],
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({required this.icon, required this.title, this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: cs.onSecondaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null) Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}
