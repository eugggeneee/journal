import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:journal/core/app_icons.dart';
import 'package:journal/main.dart' as journal;

void record(String message) {
  debugPrint(message);
  if (Platform.isIOS) {
    File('${Directory.systemTemp.path}/journal-launcher-probe.txt').writeAsStringSync('$message\n', mode: FileMode.append);
  }
}

/// Точка входа только для проверки установки в симуляторе и эмуляторе.
Future<void> main() async {
  record('Starting Journal');
  await journal.main();
  await WidgetsBinding.instance.endOfFrame;
  final previous = await AppIcons.current();
  record('Current icon: $previous');
  if (previous == 'default' && await AppIcons.set('teal') && await AppIcons.current() == 'teal') {
    record('JOURNAL_LAUNCHER_VERIFIED');
  } else {
    record('JOURNAL_LAUNCHER_FAILED ($previous)');
  }
}
