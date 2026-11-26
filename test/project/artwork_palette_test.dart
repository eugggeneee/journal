import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/palette.dart';
import 'package:journal/ui/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('цвета иллюстраций совпадают с темами Journal', () {
    final palettes = <String, Object>{};
    for (final choice in AppPalette.choices) {
      final modes = <String, Object>{};
      for (final mode in Brightness.values) {
        final scheme = AppTheme.themeFor(choice.id, mode).colorScheme;
        final colors = {
          'surface': scheme.surface, 'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
          'onSurface': scheme.onSurface, 'onSurfaceVariant': scheme.onSurfaceVariant,
          'primary': scheme.primary, 'onPrimary': scheme.onPrimary,
          'primaryContainer': scheme.primaryContainer, 'onPrimaryContainer': scheme.onPrimaryContainer,
          'secondaryContainer': scheme.secondaryContainer, 'outline': scheme.outline,
        };
        modes[mode.name] = colors.map((role, color) =>
          MapEntry(role, '#${color.toARGB32().toRadixString(16).substring(2)}'));
      }
      palettes[choice.id] = modes;
    }
    final file = File('scripts/icons/artwork_palettes.json');
    final json = '${const JsonEncoder.withIndent('  ').convert(palettes)}\n';
    if (const bool.fromEnvironment('EXPORT_ARTWORK_PALETTES')) file.writeAsStringSync(json);
    expect(jsonDecode(file.readAsStringSync()), palettes);
  });
}
