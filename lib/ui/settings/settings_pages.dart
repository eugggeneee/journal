import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dates.dart';
import '../../core/file_io.dart';
import '../../core/haptics.dart';
import '../../data/models.dart';
import '../../logic/limits.dart';
import '../app/scope.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/reveal.dart';
import '../kit/components/feedback.dart';
import '../kit/components/gesture_guide.dart';
import '../kit/components/widgets.dart';
import '../kit/foundation/journal_theme.dart';
import '../kit/inputs/selectors.dart';
import '../kit/inputs/settings_tiles.dart';
import '../kit/sheets/sheet.dart';
import 'bells_page.dart';
import 'group_picker.dart';

part 'schedule_settings.dart';
part 'absence_settings.dart';
part 'behavior_settings.dart';
part 'data_settings.dart';

/// Каркас вложенной страницы настроек: крупный заголовок и содержимое.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.cs.surface,
        body: ContentFrame(
          child: CustomScrollView(
            slivers: [
              SubHeader(title),
              Inset(children: children),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      );
}
