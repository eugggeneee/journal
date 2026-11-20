import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_icons.dart';
import '../kit/components/feedback.dart';

/// Синхронизация работает и вне экрана оформления, в том числе после восстановления настроек.
class IconSync extends StatefulWidget {
  const IconSync({super.key, required this.desired, required this.child});
  final String? desired;
  final Widget child;

  @override
  State<IconSync> createState() => _IconSyncState();
}

class _IconSyncState extends State<IconSync> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(IconSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.desired != widget.desired) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    AppIcons.cancelQueued();
    final id = widget.desired;
    if (id == null || !AppIcons.platformOk) return;
    _timer = Timer(const Duration(milliseconds: 350), () async {
      final ok = await AppIcons.select(id);
      if (mounted && widget.desired == id && !ok && AppIcons.actual.value != null) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger != null) showNote(messenger, 'Значок не изменился. Выключите и снова включите «Значок в цвет темы».');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
