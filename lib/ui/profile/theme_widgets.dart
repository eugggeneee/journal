import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../../core/haptics.dart';
import '../kit/ctx.dart';
import '../kit/feedback.dart';
import '../kit/pickers.dart';
import '../kit/sheet.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import '../theme.dart';

/// Круглый «образец» темы: три основных цвета схемы, как в выборе цветов Android.
class _SchemePainter extends CustomPainter {
  _SchemePainter(this.scheme);
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;
    paint.color = scheme.primary;
    canvas.drawArc(rect, math.pi, math.pi, true, paint); // верхняя половина
    paint.color = scheme.tertiary;
    canvas.drawArc(rect, math.pi / 2, math.pi / 2, true, paint); // нижняя левая четверть
    paint.color = scheme.secondary;
    canvas.drawArc(rect, 0, math.pi / 2, true, paint); // нижняя правая четверть
  }

  @override
  bool shouldRepaint(_SchemePainter old) => !identical(old.scheme, scheme);
}

/// Маленький образец текущей темы (для строки в профиле).
class SchemeDot extends StatelessWidget {
  const SchemeDot({super.key, required this.scheme, this.size = 28});
  final ColorScheme scheme;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: ClipOval(child: CustomPaint(size: Size.square(size), painter: _SchemePainter(scheme))),
      );
}

class _ChoiceItem {
  const _ChoiceItem({required this.label, required this.visual, required this.selected, required this.onTap});
  final String label;
  final Widget visual;
  final bool selected;
  final VoidCallback onTap;
}

/// Сетка вариантов с подписями; выбранный обводится и помечается галочкой.
class _ChoiceGrid extends StatelessWidget {
  const _ChoiceGrid({required this.items, required this.round});
  final List<_ChoiceItem> items;
  final bool round;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 520 ? 6 : 4;
        final w = box.maxWidth / cols;
        return Wrap(
          runSpacing: 6,
          children: [
            for (final it in items) SizedBox(width: w.floorToDouble(), child: _ChoiceTile(item: it, round: round)),
          ],
        );
      });
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.item, required this.round});
  final _ChoiceItem item;
  final bool round;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final sel = item.selected;
    return Semantics(
      button: true,
      selected: sel,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Haptics.selection();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: _size + 10,
              height: _size + 10,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: _size + 10,
                  height: _size + 10,
                  decoration: BoxDecoration(
                    shape: round ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: round ? null : BorderRadius.circular(22),
                    border: Border.all(color: sel ? cs.primary : Colors.transparent, width: 3),
                  ),
                ),
                AnimatedScale(
                  scale: sel ? 0.88 : 1.0,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(width: _size, height: _size, child: item.visual),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AnimatedScale(
                    scale: sel ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surfaceContainerLow, width: 2),
                      ),
                      child: Icon(Icons.check_rounded, size: 14, color: cs.onPrimary),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              child: Text(
                item.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.tt.labelSmall?.copyWith(
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: sel ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Выбор цветовой темы. Тема меняется сразу, а цвета всего интерфейса плавно перетекают.
class ThemeColorGrid extends StatelessWidget {
  const ThemeColorGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final brightness = Theme.of(context).brightness;
    final current = store.settings.themeColor;
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.dynamicAvailable,
      builder: (context, hasDynamic, _) {
        // Без динамических цветов (iPhone, старый Android) «по обоям» совпадает со стандартной темой.
        final effective = (current == AppPalette.auto && !hasDynamic) ? AppPalette.standardId : current;
        final dyn = AppTheme.dynamicFor(brightness);
        return _ChoiceGrid(
          round: true,
          items: [
            if (hasDynamic && dyn != null)
              _ChoiceItem(
                label: 'По обоям',
                visual: SchemeDot(scheme: dyn, size: 56),
                selected: effective == AppPalette.auto,
                onTap: () => store.setThemeColor(AppPalette.auto),
              ),
            for (final c in AppPalette.choices)
              _ChoiceItem(
                label: c.name,
                visual: SchemeDot(scheme: AppPalette.scheme(c, brightness), size: 56),
                selected: effective == c.id,
                onTap: () => store.setThemeColor(c.id),
              ),
          ],
        );
      },
    );
  }
}

/// Строка «Цвет темы»: образец текущей схемы и название. По нажатию открывается шторка с цветами.
class ThemeColorField extends StatelessWidget {
  const ThemeColorField({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.dynamicAvailable,
      builder: (context, hasDynamic, _) => FieldTile(
        label: 'Цвет темы',
        leading: SchemeDot(scheme: Theme.of(context).colorScheme, size: 28),
        valueLabel: AppTheme.nameOf(store.settings.themeColor, hasDynamic: hasDynamic),
        onTap: () => showThemeColorSheet(context),
      ),
    );
  }
}

/// Шторка выбора цвета: тема применяется сразу, шторка остаётся открытой, чтобы видеть результат.
Future<void> showThemeColorSheet(BuildContext context) => showAdaptiveSheet<void>(
      context,
      (ctx) => SheetScaffold(
        title: 'Цвет темы',
        subtitle: 'Применяется сразу ко всему приложению',
        footer: SizedBox(
          width: double.infinity,
          child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Готово')),
        ),
        children: const [Padding(padding: EdgeInsets.only(top: 4), child: ThemeColorGrid())],
      ),
    );

/// Живой макет приложения: рисуется цветами текущей темы, поэтому на глазах перекрашивается при выборе.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final tt = context.tt;
    Widget navIcon(IconData icon, {bool selected = false}) => AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 44,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? cs.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: selected ? cs.onSecondaryContainer : cs.onSurfaceVariant),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Расписание', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Pill('Группа 6312', tone: Tone(cs.secondaryContainer, cs.onSecondaryContainer), icon: Icons.groups_rounded),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(24)),
          child: Row(children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(clipBehavior: Clip.none, children: [
                NumberBadge('2', tone: Tone(cs.primaryContainer, cs.onPrimaryContainer), size: 46, round: false),
                Positioned(
                  top: -7,
                  right: -7,
                  child: AbsenceBadge(hours: 2, excused: false, ringColor: cs.surfaceContainer),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Математика', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('ауд. 214 · Иванова И. И.', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(100)),
            child: Text('Добавить', style: tt.labelLarge?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(100)),
            child: Text('Весь день', style: tt.labelLarge?.copyWith(color: cs.onSecondaryContainer, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.add_rounded, color: cs.onPrimaryContainer),
          ),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            navIcon(Icons.calendar_month_rounded, selected: true),
            navIcon(Icons.star_outline_rounded),
            navIcon(Icons.event_busy_outlined),
            navIcon(Icons.person_outline_rounded),
          ]),
        ),
      ]),
    );
  }
}

/// Выбор значка приложения: у каждой темы свой значок. Строка открывает шторку со значками.
class AppIconSection extends StatefulWidget {
  const AppIconSection({super.key});
  @override
  State<AppIconSection> createState() => _AppIconSectionState();
}

class _AppIconSectionState extends State<AppIconSection> {
  final ValueNotifier<String?> _current = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _busy = ValueNotifier<bool>(false);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _current.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final v = await AppIcons.current();
    if (!mounted) return;
    _current.value = v;
    setState(() => _loaded = true);
  }

  Future<void> _pick(String id) async {
    if (_busy.value || id == _current.value) return;
    final messenger = ScaffoldMessenger.of(context);
    final android = Theme.of(context).platform == TargetPlatform.android;
    final prev = _current.value;
    _current.value = id;
    _busy.value = true;
    final ok = await AppIcons.set(id);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) _current.value = prev;
    if (!ok) {
      showNote(messenger, 'Не удалось сменить значок');
    } else if (android) {
      showNote(messenger, 'Значок обновится через пару секунд');
    }
  }

  void _open() {
    showAdaptiveSheet<void>(
      context,
      (ctx) => _AppIconSheet(current: _current, busy: _busy, onPick: _pick),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppIcons.platformOk) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: _current,
      builder: (context, current, _) {
        final known = current != null && AppPalette.has(current);
        final String value;
        if (!_loaded) {
          value = '';
        } else if (current == null) {
          value = 'Недоступно в этой сборке';
        } else {
          value = known ? AppPalette.byId(current).name : 'Стандартный';
        }
        return FieldTile(
          label: 'Значок приложения',
          valueLabel: value,
          placeholder: 'Загрузка…',
          leading: known
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/icons/preview/$current.png', width: 28, height: 28, fit: BoxFit.cover),
                )
              : Icon(Icons.apps_rounded, color: context.cs.onSurfaceVariant),
          onTap: _loaded && current != null ? _open : null,
        );
      },
    );
  }
}

class _AppIconSheet extends StatelessWidget {
  const _AppIconSheet({required this.current, required this.busy, required this.onPick});
  final ValueNotifier<String?> current;
  final ValueNotifier<bool> busy;
  final Future<void> Function(String id) onPick;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final themeId = AppPalette.has(store.settings.themeColor) ? store.settings.themeColor : AppPalette.standardId;
    return ValueListenableBuilder<String?>(
      valueListenable: current,
      builder: (context, cur, _) => ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (context, isBusy, _) => SheetScaffold(
          title: 'Значок приложения',
          subtitle: 'У каждой темы свой значок',
          footer: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                label: const Text('Под тему'),
                onPressed: isBusy ? null : () => onPick(themeId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово'))),
          ]),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _ChoiceGrid(
                round: false,
                items: [
                  for (final c in AppPalette.choices)
                    _ChoiceItem(
                      label: c.name,
                      selected: cur == c.id,
                      onTap: () => onPick(c.id),
                      visual: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset('assets/icons/preview/${c.id}.png', fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
