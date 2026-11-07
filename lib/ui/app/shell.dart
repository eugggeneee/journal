import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';
import '../absences/absence_sheet.dart';
import '../absences/absences_page.dart';
import '../grades/grade_sheet.dart';
import '../grades/grades_page.dart';
import '../kit/animation/motion.dart';
import '../kit/animation/tab_switcher.dart';
import '../profile/profile_page.dart';
import '../schedule/add_menu.dart';
import '../schedule/schedule_page.dart';
import 'scope.dart';

/// Оболочка: нижняя панель навигации на телефоне, боковая NavigationRail на планшете и ПК.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  static const _wide = 640.0;

  static const _items = [
    (Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Расписание'),
    (Icons.star_outline_rounded, Icons.star_rounded, 'Оценки'),
    (Icons.event_busy_outlined, Icons.event_busy_rounded, 'Пропуски'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  int _tab = 0;
  bool _prefetched = false;

  final ScheduleController _sched = ScheduleController();
  late final List<Widget> _pages = [
    SchedulePage(controller: _sched),
    const GradesPage(),
    const AbsencesPage(),
    const ProfilePage(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefetched) {
      _prefetched = true;
      StoreScope.repoOf(context).prefetch();
    }
  }

  @override
  void dispose() {
    _sched.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (i == _tab) return;
    Haptics.selection();
    setState(() => _tab = i);
  }

  Widget _fab(BuildContext context) {
    switch (_tab) {
      case 0:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-add'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            showAddMenu(context, _sched.selected);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Добавить'),
        );
      case 1:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-grade'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            showGradeSheet(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Оценка'),
        );
      case 2:
        return FloatingActionButton.extended(
          key: const ValueKey('fab-absence'),
          heroTag: null,
          onPressed: () {
            Haptics.selection();
            showAbsenceSheet(context);
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Пропуск'),
        );
      default:
        return const SizedBox.shrink(key: ValueKey('fab-none'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final body = TabSwitcher(index: _tab, children: _pages);

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        body: wide
            ? Row(children: [
                SafeArea(
                  child: NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final it in _items)
                        NavigationRailDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
                    ],
                  ),
                ),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _select,
                destinations: [
                  for (final it in _items) NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: it.$3),
                ],
              ),
        floatingActionButton: AnimatedSwitcher(
          duration: context.motion(Motion.short),
          switchInCurve: Motion.spring,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
          child: _fab(context),
        ),
      ),
    );
  }
}
