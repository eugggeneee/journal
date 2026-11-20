import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:journal/core/palette.dart';
import 'package:journal/ui/kit/foundation/ctx.dart';
import 'package:journal/ui/theme/app_theme.dart';

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
  test('текст читается на карточках всех 20 тем при обеих яркостях', () {
    for (final theme in AppPalette.choices) {
      for (final brightness in Brightness.values) {
        final cs = AppTheme.themeFor(theme.id, brightness).colorScheme;
        for (final tone in [
          Tone(cs.primaryContainer, cs.onPrimaryContainer),
          Tone(cs.secondaryContainer, cs.onSecondaryContainer),
          Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
          Tone(cs.surface, cs.onSurface),
        ]) {
          final light = [tone.bg.computeLuminance(), tone.fg.computeLuminance()]..sort();
          expect(
            (light.last + .05) / (light.first + .05),
            greaterThanOrEqualTo(4.5),
            reason: '${theme.id}, $brightness',
          );
        }
      }
    }
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
