import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:material_ui/material_ui.dart';

import '../../../core/dates.dart';
import '../../../core/haptics.dart';
import '../animation/motion.dart';
import '../animation/reveal.dart';
import '../foundation/journal_theme.dart';

part 'page_layout.dart';
part 'badges.dart';
part 'grouped_cards.dart';

/// Время удержания карточки до срабатывания (отметка пропуска): короче системных 500 мс.
const Duration kQuickHold = Duration(milliseconds: 260);

/// Запас снизу под плавающую кнопку, чтобы она не закрывала последние элементы списка.
const double kFabClearance = 104;
