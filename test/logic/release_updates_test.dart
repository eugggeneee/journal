import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal/logic/release_updates.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late int requests;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requests = 0;
  });

  ReleaseUpdates updates(String installed, String tag, {bool pre = false, bool draft = false, int status = 200}) {
    return ReleaseUpdates(prefs, installed: installed, client: MockClient((request) async {
      requests++;
      expect(request.url.toString(), 'https://api.github.com/repos/eugggeneee/journal/releases/latest');
      return http.Response(jsonEncode({'tag_name': tag, 'prerelease': pre, 'draft': draft}), status);
    }));
  }

  test('релиз после беты виден в настройках, сообщение появляется один раз', () async {
    final first = updates('1.0.1-beta.16', 'v1.0.1');
    await Future.wait([first.check(), first.check()]);
    expect(first.available, '1.0.1');
    expect(first.shouldNotify, isTrue);
    await first.markShown(first.available!);
    final reopened = updates('1.0.1-beta.16', 'v1.0.1');
    await reopened.check();
    expect(requests, 1);
    expect(reopened.available, '1.0.1');
    expect(reopened.shouldNotify, isFalse);
    expect(updates('1.0.1', 'v1.0.1').available, isNull);
    expect(updates('1.0.2-beta.1', 'v1.0.1').available, isNull);
  });

  test('сравнение номеров числовое', () async {
    final releases = updates('1.0.9', 'v1.0.10');
    await releases.check();
    expect(releases.available, '1.0.10');
    expect(releases.page(releases.available!).path, '/eugggeneee/journal/releases/tag/v1.0.10');
  });

  test('беты, RC, черновики и ошибки сети не вызывают уведомлений', () async {
    for (final releases in [
      updates('1.0.1', 'v1.0.2-beta.1'),
      updates('1.0.1', 'v1.0.2-rc.1'),
      updates('1.0.1', 'v1.0.2', pre: true),
      updates('1.0.1', 'v1.0.2', draft: true),
      updates('1.0.1', 'v1.0.2', status: 503),
    ]) {
      await releases.check();
      expect(releases.available, isNull);
      expect(releases.shouldNotify, isFalse);
    }
  });
}
