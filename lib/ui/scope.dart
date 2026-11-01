import 'package:material_ui/material_ui.dart';

import '../data/store.dart';
import '../logic/schedule_service.dart';

/// Доступ к хранилищу и репозиторию из любого места дерева
/// (scope стоит над Navigator, поэтому работает и в диалогах/шторках).
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({
    super.key,
    required AppStore store,
    required this.repo,
    required super.child,
  }) : super(notifier: store);

  final ScheduleRepo repo;

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static ScheduleRepo repoOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.repo;
}
