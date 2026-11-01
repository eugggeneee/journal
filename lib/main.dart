import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'core/haptics.dart';
import 'data/store.dart';
import 'logic/schedule_service.dart';
import 'ui/onboarding/onboarding.dart';
import 'ui/scope.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final store = await AppStore.load();
  runApp(JournalApp(store: store, repo: ScheduleRepo(store)));
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key, required this.store, required this.repo});
  final AppStore store;
  final ScheduleRepo repo;

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  Widget _scope(BuildContext context, Widget? child) =>
      StoreScope(store: store, repo: repo, child: child ?? const SizedBox.shrink());

  /// Приветствие, пока оно не пройдено или не выбрана группа; затем — оболочка с вкладками.
  Widget _home() => ListenableBuilder(
        listenable: store,
        builder: (context, _) => store.onboarded && store.hasGroup ? const Shell() : const OnboardingFlow(),
      );

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final light = lightDynamic?.harmonized() ?? AppTheme.fallback(Brightness.light);
        final dark = darkDynamic?.harmonized() ?? AppTheme.fallback(Brightness.dark);
        return ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            Haptics.enabled = store.settings.haptics;
            return MaterialApp(
              title: 'Journal',
              debugShowCheckedModeBanner: false,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              themeMode: _modes[store.settings.themeMode],
              theme: AppTheme.build(light),
              darkTheme: AppTheme.build(dark),
              builder: _scope,
              home: _home(),
            );
          },
        );
      },
    );
  }
}
