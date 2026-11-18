import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/schedule/schedule_service.dart';
import 'package:journal/ui/app/scope.dart';
import 'package:journal/ui/settings/settings_pages.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Share extends SharePlatform {
  ShareParams? params;

  @override
  Future<ShareResult> share(ShareParams params) async {
    this.params = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

void main() {
  testWidgets('экспорт JSON открывает меню с привязкой к строке на планшете', (tester) async {
    final share = _Share();
    final previous = SharePlatform.instance;
    SharePlatform.instance = share;
    addTearDown(() => SharePlatform.instance = previous);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.load();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: StoreScope(store: store, repo: ScheduleRepo(store),
      child: const DataSettingsPage())));
    await tester.pumpAndSettle();
    final row = find.text('Сохранить в файл');
    await tester.tap(row);
    await tester.pumpAndSettle();
    final params = share.params!;
    expect(params.sharePositionOrigin?.contains(tester.getCenter(row)), isTrue);
    expect(jsonDecode(await params.files!.single.readAsString())['app'], 'journal');
  });
}
