import 'package:material_ui/material_ui.dart';

import '../kit/selectors.dart';
import '../kit/widgets.dart';
import '../scope.dart';
import '../theme.dart';
import 'theme_widgets.dart';

/// Экран «Тема и значок»: режим (светлая/тёмная), цвет и значок приложения.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: ContentFrame(
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(title: const Text('Тема и значок')),
            Inset(children: [
              const ThemePreview(),
              const SectionHeader('Режим'),
              const ThemeSelector(),
              const SectionHeader('Цвет'),
              const ThemeColorField(),
              ValueListenableBuilder<bool>(
                valueListenable: AppTheme.dynamicAvailable,
                builder: (context, hasDynamic, _) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    hasDynamic && store.settings.themeColor == AppPalette.auto
                        ? 'Цвета подстраиваются под обои телефона. Выберите любую тему, чтобы закрепить её.'
                        : 'Тема применяется сразу ко всему приложению.',
                    style: textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant, height: 1.4),
                  ),
                ),
              ),
              const SectionHeader('Значок приложения'),
              const AppIconSection(),
            ]),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
