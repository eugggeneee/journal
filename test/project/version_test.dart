import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Схема версий из docs/VERSIONING.md: MAJOR.MINOR.PATCH, PATCH от 0 до 20,
/// пред-релизы -beta.N и -rc.N, номер сборки после «+».
void main() {
  final text = File('pubspec.yaml').readAsStringSync();
  final raw = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(text)!.group(1)!;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:-(?:beta|rc)\.(\d+))?(?:\+(\d+))?$').firstMatch(raw);

  test('версия в pubspec.yaml соответствует схеме', () {
    expect(match, isNotNull, reason: raw);
  });

  test('первая цифра не меньше 1, последняя не больше 20', () {
    expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(1));
    expect(int.parse(match.group(3)!), lessThanOrEqualTo(20));
  });

  test('стабильная версия описана в CHANGELOG.md', () {
    final base = raw.split('+').first;
    if (base.contains('-')) return;
    final log = File('CHANGELOG.md').readAsStringSync();
    expect(log.contains('## [$base]'), isTrue, reason: 'нет раздела [$base]');
    expect(File('.github/releases/v$base.md').existsSync(), isTrue);
  });
}
