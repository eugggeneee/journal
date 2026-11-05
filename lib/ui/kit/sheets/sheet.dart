import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../foundation/ctx.dart';

const double _wideBreakpoint = 700;

/// На телефоне — модальная шторка снизу, на планшете и ПК — диалог по центру.
Future<T?> showAdaptiveSheet<T>(BuildContext context, WidgetBuilder builder) {
  final size = MediaQuery.sizeOf(context);
  if (size.width >= _wideBreakpoint) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 560, maxHeight: size.height * 0.9),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: builder,
  );
}

/// Каркас шторки: заголовок, прокручиваемое содержимое и закреплённая нижняя панель.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.trailing,
    this.leading,
    this.footer,
    this.pinned,
    this.fill = false,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final List<Widget> children;
  final Widget? footer;

  /// Закреплённый блок под заголовком (например, строка поиска) — не прокручивается вместе с содержимым.
  final Widget? pinned;

  /// Занять всю доступную высоту (список меняется при поиске, а шторка не должна «прыгать»).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final wide = context.screen.width >= _wideBreakpoint;
    final keyboard = wide ? 0.0 : MediaQuery.viewInsetsOf(context).bottom;
    final safe = wide ? 0.0 : MediaQuery.paddingOf(context).bottom;
    final bottom = keyboard > 0 ? keyboard : safe;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, wide ? 20 : 0, 12, 8),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 14)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          if (pinned != null) Padding(padding: const EdgeInsets.fromLTRB(24, 4, 24, 4), child: pinned),
          Flexible(
            fit: fill ? FlexFit.tight : FlexFit.loose,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
          if (footer != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.cs.outlineVariant.withValues(alpha: 0.5)))),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Задаёт шторке со списком и поиском постоянную высоту: список меняется при вводе,
/// а сама шторка не должна «прыгать». Учитывает клавиатуру.
class SheetHeight extends StatelessWidget {
  const SheetHeight({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= _wideBreakpoint;
    final keyboard = wide ? 0.0 : MediaQuery.viewInsetsOf(context).bottom;
    final base = (size.height * 0.74).clamp(380.0, 680.0).toDouble();
    return SizedBox(height: math.min(base + keyboard, size.height - 80), child: child);
  }
}

/// Подпись над блоком формы.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing, this.top = 20});
  final String text;
  final String? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(text, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            if (trailing != null) Text(trailing!, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
        ),
      );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'ОК',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            backgroundColor: destructive ? ctx.cs.error : null,
            foregroundColor: destructive ? ctx.cs.onError : null,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<void> infoDialog(BuildContext context, String title, String message) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Понятно'))],
      ),
    );

Future<DateTime?> pickDay(BuildContext context, DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );

Future<String?> promptText(BuildContext context, {required String title, String hint = ''}) =>
    showDialog<String>(context: context, builder: (ctx) => _PromptDialog(title: title, hint: hint));

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, required this.hint});
  final String title;
  final String hint;
  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
          controller: _c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: widget.hint),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: _c.text.trim().isEmpty ? null : _submit,
            child: const Text('Добавить'),
          ),
        ],
      );
}

/// Подпись выбранной даты: «Сегодня, 31 октября» / «Среда, 28 октября».
String dayCaption(DateTime d) {
  final r = relativeDay(d);
  return '$r, ${shortDate(d)}';
}
