import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appBuildName;
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReleaseUpdates extends ChangeNotifier {
  ReleaseUpdates(this._prefs, {this.installed = buildVersion, http.Client? client})
      : _get = client?.get ?? http.get;

  // iOS хранит в Info.plist только числовую часть. CI передаёт полный тег отдельно.
  static const buildVersion = String.fromEnvironment('JOURNAL_VERSION', defaultValue: appBuildName ?? '');
  static final _endpoint = Uri.https('api.github.com', '/repos/eugggeneee/journal/releases/latest');
  static final _stable = RegExp(r'^v(\d+\.\d+\.\d+)$');
  static const _latest = 'release.latest';
  static const _checked = 'release.checked';
  static const _shown = 'release.shown';
  final SharedPreferences _prefs;
  final Future<http.Response> Function(Uri, {Map<String, String>? headers}) _get;
  final String installed;
  Future<void>? _checking;
  DateTime? _attempt;

  String? get available {
    final latest = _prefs.getString(_latest);
    if (latest == null || installed.isEmpty) return null;
    return Version.parse(latest) > Version.parse(installed) ? latest : null;
  }

  Uri page(String version) => Uri.https('github.com', '/eugggeneee/journal/releases/tag/v$version');

  bool get shouldNotify => available != null && _prefs.getString(_shown) != available;
  Future<bool> markShown(String version) => _prefs.setString(_shown, version);

  Future<void> check() => _checking ??= _refresh().whenComplete(() { _checking = null; });

  Future<void> _refresh() async {
    final now = DateTime.now();
    final checked = DateTime.fromMillisecondsSinceEpoch(_prefs.getInt(_checked) ?? 0);
    bool recent(DateTime then, Duration interval) => !then.isAfter(now) && now.difference(then) < interval;
    if (recent(checked, const Duration(hours: 12)) ||
        (_attempt != null && recent(_attempt!, const Duration(minutes: 5)))) return;
    _attempt = now;
    try {
      final response = await _get(_endpoint, headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 8));
      if (response.statusCode == 404) {
        await _prefs.remove(_latest);
      } else {
        if (response.statusCode != 200) return;
        final data = jsonDecode(response.body);
        if (data is! Map || data['draft'] != false || data['prerelease'] != false) return;
        final match = _stable.firstMatch(data['tag_name']?.toString() ?? '');
        if (match == null) return;
        await _prefs.setString(_latest, Version.parse(match[1]!).toString());
      }
      await _prefs.setInt(_checked, now.millisecondsSinceEpoch);
      notifyListeners();
    } on Exception {
      // Офлайн и при ограничении API сохраняем результат последней успешной проверки.
    }
  }
}
