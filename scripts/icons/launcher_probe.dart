import 'package:flutter/widgets.dart';
import 'package:journal/core/app_icons.dart';
import 'package:journal/main.dart' as journal;

/// Точка входа только для проверки установки в симуляторе и эмуляторе.
Future<void> main() async {
  await journal.main();
  await WidgetsBinding.instance.endOfFrame;
  final previous = await AppIcons.current();
  if (previous == 'default' && await AppIcons.set('teal') && await AppIcons.current() == 'teal') {
    debugPrint('JOURNAL_LAUNCHER_VERIFIED');
  } else {
    debugPrint('JOURNAL_LAUNCHER_FAILED ($previous)');
  }
}
