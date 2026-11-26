import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal/ui/settings/theme_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:journal/core/palette.dart';
import 'package:journal/ui/kit/foundation/journal_theme.dart';
import 'package:journal/ui/theme/app_theme.dart';

void main() {
  test('значок следует теме и ближайшему оттенку обоев', () {
    expect(AppPalette.launcherFor('red', Colors.blue), 'red');
    expect(AppPalette.launcherFor('auto', null), AppPalette.standardId);
    expect(AppPalette.launcherFor('auto', Colors.grey), 'mono');
    final teal = AppPalette.byId('teal');
    expect(AppPalette.launcherFor('auto', teal.seed), 'teal');
  });

  test('пиктограммы различимы во всех палитрах и обеих яркостях', () {
    for (final mode in Brightness.values) {
      for (final choice in AppPalette.choices) {
        final tone = iconTone(AppTheme.themeFor(choice.id, mode).colorScheme);
        final levels = [tone.bg.computeLuminance(), tone.fg.computeLuminance()]..sort();
        expect((levels.last + .05) / (levels.first + .05), greaterThanOrEqualTo(3), reason: choice.id);
        expect(tone.fg, isNot(Colors.black));
      }
    }
  });

  testWidgets('все светлые образцы показывают пастельные заливки карточек', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Row(textDirection: TextDirection.ltr, children: [
        for (final theme in AppPalette.choices)
          SchemeDot(scheme: AppPalette.scheme(theme, Brightness.light), size: 32),
      ]),
    ));
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        for (final (i, theme) in AppPalette.choices.indexed) {
          final row = image.height ~/ 2;
          Color pixel(int x, int y) {
            final offset = 4 * (image.width * y + 32 * i + x);
            return Color.fromARGB(255, data.getUint8(offset), data.getUint8(offset + 1), data.getUint8(offset + 2));
          }
          final expected = AppTheme.themeFor(theme.id, Brightness.light).colorScheme.primaryContainer;
          final actual = pixel(16, row - 8);
          for (final (a, b) in [(actual.r, expected.r), (actual.g, expected.g), (actual.b, expected.b)]) {
            expect(a, closeTo(b, 1 / 255), reason: theme.id);
          }
          for (final color in [pixel(16, row - 8), pixel(8, row + 5), pixel(24, row + 5)]) {
            expect(color.computeLuminance(), greaterThan(.3), reason: theme.id);
          }
        }
      } finally {
        image.dispose();
      }
    });
  });

  test('индикатор и значок выбранной вкладки используют основной акцент', () {
    for (final theme in AppPalette.choices) {
      final data = AppTheme.themeFor(theme.id, Brightness.dark);
      final bar = data.navigationBarTheme;
      expect(bar.indicatorColor, iconTone(data.colorScheme).bg);
      expect(bar.iconTheme?.resolve({WidgetState.selected})?.color, iconTone(data.colorScheme).fg);
      expect(data.navigationRailTheme.indicatorColor, bar.indicatorColor);
    }
  });

  test('текст читается на карточках всех 20 тем при обеих яркостях', () {
    for (final theme in AppPalette.choices) {
      for (final brightness in Brightness.values) {
        final cs = AppTheme.themeFor(theme.id, brightness).colorScheme;
        if (brightness == Brightness.dark) {
          expect(cs.primaryContainer.computeLuminance(), lessThan(.25), reason: theme.id);
        }
        for (final tone in [
          Tone(cs.primaryContainer, cs.onPrimaryContainer),
          Tone(cs.secondaryContainer, cs.onSecondaryContainer),
          Tone(cs.tertiaryContainer, cs.onTertiaryContainer),
          Tone(cs.surface, cs.onSurface),
          Tone(cs.primary, cs.onPrimary),
          Tone(cs.surface, cs.primary),
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
              for (var g = 1; g <= 10; g++) {
                final levels = [gradeTone(context, g).bg.computeLuminance(),
                  gradeAccent(context, g).computeLuminance()]..sort();
                expect((levels.last + .05) / (levels.first + .05), greaterThanOrEqualTo(3), reason: 'Отметка $g, $b');
              }
              final tones = [
                for (var g = 1; g <= 10; g++) gradeTone(context, g),
                absenceTone(context, excused: true),
                absenceTone(context, excused: false),
                warnTone(context),
                for (final h in [kHueAmber, kHueGreen]) hueTone(context, h),
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
