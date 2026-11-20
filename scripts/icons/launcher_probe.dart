import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:journal/core/app_icons.dart';
import 'package:journal/main.dart' as journal;

void record(String message) {
  debugPrint(message);
  if (Platform.isIOS) {
    File('${Directory.systemTemp.path}/journal-launcher-probe.txt')
        .writeAsStringSync('$message\n', mode: FileMode.append);
  }
}

/// Точка входа только для проверки установки в симуляторе и эмуляторе.
Future<void> main() async {
  if (Platform.isIOS) {
    final console = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null && message.startsWith('App icon:')) {
        File('${Directory.systemTemp.path}/journal-launcher-probe.txt')
            .writeAsStringSync('$message\n', mode: FileMode.append);
      }
      console(message, wrapWidth: wrapWidth);
    };
  }
  final log = File('${Directory.systemTemp.path}/journal-launcher-probe.txt');
  final previouslyRequested =
      Platform.isIOS && log.existsSync() && log.readAsStringSync().contains('Initial icon: default');
  record('Starting Journal');
  await journal.main();
  await WidgetsBinding.instance.endOfFrame;
  for (var i = 0; i < 90 && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  record('Lifecycle: ${WidgetsBinding.instance.lifecycleState}');
  final previous = await AppIcons.current();
  record('Initial icon: $previous');
  if (previouslyRequested) {
    record(previous == 'teal' ? 'JOURNAL_LAUNCHER_VERIFIED' : 'JOURNAL_LAUNCHER_FAILED current=$previous');
    return;
  }
  if (previous == 'default') {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      final changed = await AppIcons.set('teal');
      record('Requested teal: $changed');
      for (var i = 0; i < 6; i++) {
        if (await AppIcons.current() == 'teal') {
          record('JOURNAL_LAUNCHER_VERIFIED');
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }
  record('JOURNAL_LAUNCHER_FAILED current=${await AppIcons.current()}');
}
