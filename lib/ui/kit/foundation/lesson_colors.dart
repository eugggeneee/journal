import 'package:material_ui/material_ui.dart';

import '../../../core/palette.dart';
import '../../../data/models.dart';
import '../../../data/store.dart';
import 'ctx.dart';

/// Тональные семейства Material 3. Чередуем холодные и тёплые базовые цвета,
/// затем добавляем варианты светлоты в том же семействе.
class LessonColors {
  const LessonColors(this.fill, this.ink, this.edge);
  final Color fill;
  final Color ink;
  final Color edge;

  // Начальные уровни светлоты различают близкие семейства (например, коричневый и коралловый).
  static const _families = [
    ('indigo', .15), ('teal', .35), ('deepOrange', .0), ('purple', .15), ('amber', .0), ('blue', .55),
    ('green', .1), ('pink', .2), ('blueGrey', .85), ('brown', .9), ('cyan', .45), ('red', .4),
    ('lime', .7), ('deepPurple', .75), ('lightBlue', .1), ('orange', .7), ('yellow', .25), ('lightGreen', .5),
  ];

  static LessonColors of(BuildContext context, AppStore store, LessonSlot slot) =>
      forId(store.lessonColorId(slot), Theme.of(context).brightness);

  static LessonColors forId(int id, Brightness brightness) {
    final (family, initialShade) = _families[id % _families.length];
    final scheme = AppPalette.scheme(AppPalette.byId(family), brightness);
    final pass = id ~/ _families.length;
    // После первого круга выбираем промежуточные светлоты той же палитры.
    final strength = (initialShade + pass * .61803398875) % 1;
    final fill = Color.lerp(scheme.secondaryContainer, scheme.secondary, strength * .20)!;
    return LessonColors(fill, scheme.onSecondaryContainer, scheme.secondary);
  }

  Tone get tone => Tone(fill, ink);
}
