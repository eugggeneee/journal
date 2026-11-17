import 'package:flutter_test/flutter_test.dart';
import 'package:journal/ui/kit/foundation/ctx.dart';

void main() {
  test('у предмета постоянный цвет из общего набора', () {
    for (final s in ['Математика', 'Физика', 'Иностранный язык', '']) {
      final h = subjectHue(s);
      expect(kSubjectHues, contains(h));
      expect(subjectHue(s), h, reason: s);
    }
  });

  test('оттенки набора различаются', () {
    expect(kSubjectHues.toSet().length, kSubjectHues.length);
  });
}
