import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:journal/ui/kit/foundation/ctx.dart';

void main() {
  test('значки настроек используют постоянный оттенок', () {
    for (final s in ['Математика', 'Физика', 'Иностранный язык', '']) {
      final h = settingHue(s);
      expect(kSettingHues, contains(h));
      expect(settingHue(s), h, reason: s);
    }
  });

  test('оттенки набора различаются', () {
    expect(kSettingHues.toSet().length, kSettingHues.length);
  });
  testWidgets('приглушённые акценты сохраняют контраст в обеих темах', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: b),
          home: Builder(
            builder: (context) {
              final tones = [
                for (var g = 1; g <= 10; g++) gradeTone(context, g),
                absenceTone(context, excused: true),
                absenceTone(context, excused: false),
                warnTone(context),
                for (final h in kSettingHues) hueTone(context, h),
              ];
              for (final tone in tones) {
                final l = [tone.fg.computeLuminance(), tone.bg.computeLuminance()]..sort();
                expect((l.last + .05) / (l.first + .05), greaterThanOrEqualTo(4.5));
              }
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
  });
}
