import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';

void main() {
  test('старые данные с группой считаются пройденным приветствием', () {
    final s = Settings.fromJson({'group': '6312', 'extra': <String>[]});
    expect(s.onboarded, isTrue);
    expect(s.absenceHours, 2);
    expect(s.themeMode, 0);
  });

  test('новая установка без группы показывает приветствие', () {
    expect(Settings.fromJson(null).onboarded, isFalse);
  });

  test('некорректные значения заменяются безопасными', () {
    final s = Settings.fromJson({'group': 'x', 'theme': 9, 'ah': 7});
    expect(s.themeMode, 0);
    expect(s.absenceHours, 2);
  });
}
