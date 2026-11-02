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
import '../theme.dart';
import 'theme_page.dart';
import 'theme_widgets.dart';

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

  void _openTheme() {
    Haptics.selection();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ThemePage()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final store = StoreScope.of(context);
    final s = store.settings;
    final cached = store.schedulesFor(s.group).length;
    const modeNames = ['как в системе', 'светлая', 'тёмная'];

    return LargePage(
      title: 'Профиль',
      subtitle: 'Группа ${s.group} · МГТЭК',
      slivers: [
        Inset(children: [
          Material(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => openGroupPicker(context),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  CookieIcon(icon: Icons.school_rounded, size: 64, bg: cs.primary, fg: cs.onPrimary),
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
          const SectionHeader('Внешний вид'),
          ValueListenableBuilder<bool>(
            valueListenable: AppTheme.dynamicAvailable,
            builder: (context, hasDynamic, _) => SegmentCard(
              index: 0,
              count: 1,
              child: SettingsTile(
                icon: Icons.palette_rounded,
                title: 'Тема и значок',
                subtitle: '${AppTheme.nameOf(s.themeColor, hasDynamic: hasDynamic)} · ${modeNames[s.themeMode]}',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  SchemeDot(scheme: Theme.of(context).colorScheme, size: 26),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ]),
                onTap: _openTheme,
              ),
            ),
          ),
          const SectionHeader('Расписание'),
          SegmentCard(
            index: 0,
            count: 1,
            child: SettingsTile(
              icon: Icons.refresh_rounded,
              title: _refreshing ? 'Обновляю…' : 'Обновить расписание',
              subtitle: 'Сохранено: ${daysText(cached)} на устройстве',
              trailing: _refreshing ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)) : null,
              onTap: _refreshing ? null : _refresh,
            ),
          ),
          const SectionHeader('Быстрый пропуск'),
          const HoursSelector(),
          const SectionHeader('Поведение'),
          SegmentCard(
            index: 0,
            count: 2,
            child: SettingsTile(
              icon: Icons.vibration_rounded,
              title: 'Виброотклик',
              trailing: SettingsSwitch(value: s.haptics, onChanged: store.setHaptics),
              onTap: () => store.setHaptics(!s.haptics),
            ),
          ),
          SegmentCard(
            index: 1,
            count: 2,
            child: SettingsTile(
              icon: Icons.sync_rounded,
              title: 'Автообновление',
              subtitle: 'Подгружать расписание при запуске',
              trailing: SettingsSwitch(value: s.autoRefresh, onChanged: store.setAutoRefresh),
              onTap: () => store.setAutoRefresh(!s.autoRefresh),
            ),
          ),
          const SectionHeader('Данные'),
          SegmentCard(
            index: 0,
            count: 2,
            child: SettingsTile(
              icon: Icons.content_copy_rounded,
              title: 'Сохранить копию',
              subtitle: 'Оценки и пропуски — в буфер обмена',
              onTap: _export,
            ),
          ),
          SegmentCard(
            index: 1,
            count: 2,
            child: SettingsTile(
              icon: Icons.restore_rounded,
              title: 'Восстановить из копии',
              subtitle: 'Вставить данные из буфера обмена',
              onTap: _import,
            ),
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

/// Строка настроек в стиле Material: значок слева, заголовок, пояснение и действие справа.
class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return ListTile(
      onTap: onTap,
      // у карточек-сегментов скругление задаёт сама карточка
      shape: const RoundedRectangleBorder(),
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: cs.primary),
      title: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: context.tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
      trailing: trailing,
    );
  }
}

/// Переключатель Material 3 с галочкой на включённом положении.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: (v) {
          Haptics.selection();
          onChanged(v);
        },
        thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
          (states) => states.contains(WidgetState.selected) ? const Icon(Icons.check_rounded) : null,
        ),
      );
}
