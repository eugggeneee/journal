import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/main.dart' as journal;
import 'package:shared_preferences/shared_preferences.dart';

/// Использует контейнер установленного приложения только на симуляторе CI.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const stage = String.fromEnvironment('JOURNAL_UPGRADE_STAGE');
  final marker = File('${Directory.systemTemp.path}/journal-upgrade-$stage.txt');
  try {
    if (stage == 'previous') {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString('data_v1', jsonEncode({
        'version': 3,
        'settings': {'group': '0000', 'onb': true, 'tc': 'teal', 'theme': 2, 'auto': false},
        'grades': [Grade(id: 'upgrade-grade', date: DateTime(2026, 11, 18), subject: 'Математика', value: 9).toJson()],
        'tasks': [], 'marks': [], 'absences': [],
      }));
      if (!saved) throw StateError('SharedPreferences');
    }
    final store = await AppStore.load();
    if (store.settings.group != '0000' || store.settings.themeColor != 'teal' ||
        store.grades.single.id != 'upgrade-grade' || store.grades.single.value != 9) {
      throw StateError('Группа, оформление или отметка после запуска отличаются');
    }
    await journal.main();
    await WidgetsBinding.instance.endOfFrame;
    await marker.writeAsString('ok', flush: true);
  } catch (error, stack) {
    await marker.writeAsString('$error\n$stack', flush: true);
    rethrow;
  }
}
