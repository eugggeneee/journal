import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/schedule/schedule_service.dart';
import 'package:journal/ui/app/scope.dart';
import 'package:journal/ui/home/day_card.dart';
import 'package:journal/ui/home/home_page.dart';
import 'package:journal/ui/schedule/day_timeline.dart';
import 'package:journal/ui/schedule/schedule_page.dart';
import 'package:journal/ui/tasks/tasks_page.dart';
import 'package:journal/ui/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const slots = [
  LessonSlot(
    number: 2,
    entries: [
      LessonEntry(subject: 'Высшая математика', room: '214', teacher: 'Петрова А. С.'),
      LessonEntry(subject: 'Физика', room: '108', teacher: 'Громов С. Н.'),
    ],
  ),
  LessonSlot(
    number: 3,
    entries: [LessonEntry(subject: 'История', room: '305', teacher: 'Лебедев И. П.')],
  ),
  LessonSlot(
    number: 4,
    entries: [LessonEntry(subject: 'Информатика', room: '', teacher: '')],
  ),
];
const profile = BellProfile(
  slots: {2: BellSlot(start: 680, end: 780, breakStart: 770, breakEnd: 775), 3: BellSlot(start: 790, end: 850)},
);
final now = DateTime(2026, 11, 18, 12, 16);

class _FixtureRepo extends ScheduleRepo {
  _FixtureRepo(super.store);
  final refreshed = <DateTime>[];

  @override
  Future<DayState> load(DateTime date, {bool force = false}) async {
    if (force) refreshed.add(date);
    final cached = store.cachedSchedule(store.settings.group, date);
    return DayState(
      DayStatus.ok,
      schedule: cached ?? DaySchedule(date: date, slots: slots, group: store.settings.group, fetchedAt: now),
    );
  }
}

void main() {
  late AppStore store;
  late _FixtureRepo repo;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.load();
    store.setGroup('ИС-31');
    store.setBellProfile(kBellWeek, profile);
    store.setBellProfile(kBellSat, profile);
    repo = _FixtureRepo(store);
  });

  Future<void> screen(
    WidgetTester tester,
    Widget child, {
    double width = 360,
    double scale = 1,
    Brightness brightness = Brightness.dark,
    bool scroll = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 812);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeFor('auto', brightness),
        builder: (context, navigator) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
          child: StoreScope(store: store, repo: repo, child: navigator!),
        ),
        home: Scaffold(body: scroll ? SingleChildScrollView(child: child) : child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget hero(DateTime time) => DayCard(
    now: time,
    slots: slots,
    profile: profile,
    store: store,
    header: (fg) => Text('Среда, 18 ноября', style: TextStyle(color: fg)),
    onOpenDay: () {},
    onShortDay: () {},
    onMark: () {},
  );

  testWidgets('отсчёт до внутреннего перерыва, во время перерыва и после занятий', (tester) async {
    await screen(tester, hero(now));
    expect(find.text('34'), findsOneWidget);
    expect(find.text('до перерыва\nв 12:50'), findsOneWidget);
    expect(find.text('12:16'), findsOneWidget);
    await tester.tap(find.byTooltip('Свернуть карточку'));
    expect(store.settings.dayCardFolded, isTrue);
    store.setDayCardFolded(false);
    await screen(tester, hero(DateTime(2026, 11, 18, 12, 52)), scale: 1.8);
    expect(find.text('до продолжения\nв 12:55'), findsOneWidget);
    await screen(tester, hero(DateTime(2026, 11, 18, 18)), width: 900, brightness: Brightness.light);
    expect(find.text('Без времени звонков'), findsOneWidget);
  });

  testWidgets('таймлайн показывает данные подгрупп и все привязанные записи', (tester) async {
    const label = 'Подготовить индивидуальный проект к зачёту';
    store.saveMark(DayMark(id: 'm', date: now, lesson: 2, label: label));
    store.saveAbsence(
      Absence(id: 'a', date: now, lesson: 2, subject: 'Физика', hours: 1, note: 'Справка', excused: true),
    );
    for (var i = 1; i <= 3; i++) {
      store.saveTask(
        Task(id: '$i', text: 'Упражнение $i', due: now, date: now, lesson: 2, homework: i != 3, done: i == 2),
      );
    }
    final timeline = DayTimeline(date: now, slots: slots, store: store, now: now);
    await screen(tester, timeline, scale: 1.8);
    for (final text in [
      label,
      'Упражнение 3',
      'Справка',
      '1 ч · по уважительной',
      'ауд. 108 · Громов С. Н.',
      '12:16',
      'Время звонков не задано',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    await screen(tester, timeline, brightness: Brightness.light);
    await tester.tap(find.text('Высшая математика'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить оценку по предмету'), findsOneWidget);
  });

  testWidgets('главная обновляет расписание при смене группы', (tester) async {
    final day = DateTime.now();
    for (final group in ['ИС-31', 'ИС-32']) {
      store.putSchedule(
        DaySchedule(
          group: group,
          date: day,
          fetchedAt: day,
          slots: [
            LessonSlot(
              number: 1,
              entries: [LessonEntry(subject: 'Предмет $group', room: '', teacher: '')],
            ),
          ],
        ),
      );
    }
    await screen(tester, HomePage(onTab: (_) {}, onDay: (_) {}), scroll: false);
    expect(find.text('Предмет ИС-31'), findsWidgets);
    store.setGroup('ИС-32');
    await tester.pumpAndSettle();
    expect(find.text('Предмет ИС-32'), findsWidgets);
    expect(find.text('Предмет ИС-31'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('оценка и пропуск сохраняются с выбранной пары', (tester) async {
    await screen(tester, DayTimeline(date: now, slots: slots, store: store, now: now));
    await tester.tap(find.byTooltip('Отметить пропуск').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('По уважительной').last);
    await tester.pumpAndSettle();
    expect(store.absenceFor(now, 2)?.excused, isTrue);
    await tester.tap(find.text('Высшая математика').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Добавить оценку по предмету'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(store.grades.single.value, 9);
    expect(store.grades.single.subject, 'Высшая математика');
  });

  testWidgets('календарь открывает дальнюю дату, обновление запрашивает именно её', (tester) async {
    final controller = ScheduleController();
    await screen(tester, SchedulePage(controller: controller), scroll: false);
    final distant = DateTime(2031, 3, 5);
    controller.jumpTo(distant);
    await tester.pumpAndSettle();
    expect(controller.selected, distant);
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Обновить расписание'));
    await tester.pumpAndSettle();
    expect(repo.refreshed, contains(distant));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('добавить задание, завершить и отменить прямо из списка', (tester) async {
    await screen(tester, const TasksPage(), scroll: false);
    await tester.tap(find.text('Добавить задание'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Решить задачу');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.text, 'Решить задачу');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Отметить выполненным'));
    await tester.pumpAndSettle();
    expect(store.tasks.single.done, isTrue);
    await tester.tap(find.text('Отменить').last);
    await tester.pumpAndSettle();
    expect(store.tasks.single.done, isFalse);
  });
}
