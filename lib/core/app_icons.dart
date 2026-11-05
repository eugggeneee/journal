import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'palette.dart';

/// Смена значка приложения на Android и iPhone.
///
/// Нативная часть (activity-alias на Android, альтернативные значки на iOS) добавляется при сборке
/// скриптами scripts/setup_icons_*.py. Если её нет — методы возвращают null/false, и интерфейс
/// просто сообщает, что смена значка недоступна.
class AppIcons {
  AppIcons._();

  static const MethodChannel _channel = MethodChannel('eugggeneee.journal/app_icon');

  /// Значок есть под каждую тему; id совпадают с id тем.
  static List<String> get ids => [for (final c in AppPalette.choices) c.id];

  static bool get platformOk =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Id значка, который сейчас установлен. null — смена значка недоступна.
  static Future<String?> current() async {
    if (!platformOk) return null;
    try {
      final v = await _channel.invokeMethod<String>('get');
      return (v == null || v.isEmpty) ? 'default' : v;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> set(String id) async {
    if (!platformOk || !ids.contains(id)) return false;
    try {
      return (await _channel.invokeMethod<bool>('set', {'id': id})) ?? false;
    } catch (_) {
      return false;
    }
  }
}
