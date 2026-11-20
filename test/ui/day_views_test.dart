import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal/data/models.dart';
import 'package:journal/data/store.dart';
import 'package:journal/logic/schedule/schedule_service.dart';
import 'package:journal/ui/app/scope.dart';
import 'package:journal/ui/home/day_card.dart';
import 'package:journal/ui/home/day_metrics.dart';
import 'package:journal/ui/absences/absence_limit.dart';
import 'package:journal/ui/grades/grades_page.dart';
import 'package:journal/ui/settings/home_layout_page.dart';
import 'package:journal/ui/kit/inputs/settings_tiles.dart';
import 'package:journal/ui/home/day_bar.dart';
import 'package:journal/ui/kit/inputs/pickers.dart';
import 'package:journal/ui/kit/sheets/select_sheet.dart';
import 'package:journal/ui/absences/absence_actions.dart';
import 'package:journal/core/dates.dart';
import 'package:journal/ui/home/home_page.dart';
import 'package:journal/ui/home/hero_surface.dart';
import 'package:journal/ui/schedule/day_timeline.dart';
import 'package:journal/ui/schedule/week_view.dart';
import 'package:journal/ui/schedule/calendar_grid.dart';
import 'package:journal/ui/schedule/lesson_card.dart';
import 'package:journal/ui/kit/components/widgets.dart';
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
  DayStatus status = DayStatus.ok;

  @override
  Future<DayState> load(DateTime date, {bool force = false}) async {
    if (force) refreshed.add(date);
    if (status != DayStatus.ok) return DayState(status);
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
    double height = 812,
    double scale = 1,
    Brightness brightness = Brightness.dark,
    bool scroll = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
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

  Widget hero(DateTime time, {double viewportHeight = 812}) => DayCard(
    viewportHeight: viewportHeight,
    metrics: (tone, compact) => DayMetrics(store: store, onTab: (_) {}, tone: tone, compact: compact),
    now: time,
    slots: slots,
    profile: profile,
    store: store,
    header: (fg, _) => Text('Среда, 18 ноября', style: TextStyle(color: fg)),
    onOpenDay: () {},
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
    expect(find.textContaining(RegExp(r'до продолжения\s+в 12:55')), findsOneWidget);
    await screen(tester, hero(DateTime(2026, 11, 18, 18)), width: 900, brightness: Brightness.light);
    expect(find.text('Без времени звонков'), findsOneWidget);
  });

  testWidgets('вся карточка с крупным отсчётом помещается над навигацией', (tester) async {
    for (final (width, height, top, bottom, scale) in [
      (320.0, 568.0, 20.0, 80.0, 1.0),
      (320.0, 568.0, 20.0, 80.0, 2.0),
      (375.0, 667.0, 20.0, 80.0, 2.0),
      (390.0, 844.0, 59.0, 114.0, 1.0),
      (812.0, 375.0, 0.0, 21.0, 1.5),
    ]) {
      tester.view.padding = FakeViewPadding(top: top);
      await screen(
        tester,
        hero(now, viewportHeight: height - bottom),
        width: width,
        height: height,
        scale: scale,
      );
      expect(
        tester.getBottomLeft(find.byType(HeroSurface)).dy,
        lessThanOrEqualTo(height - bottom),
        reason: '${width}×$height, масштаб $scale',
      );
      expect(tester.widget<Text>(find.text('34')).style!.fontSize, 148);
      final surface = find.byType(HeroSurface);
      expect(find.descendant(of: surface, matching: find.byType(DayMetrics)), findsOneWidget);
      expect(find.descendant(of: surface, matching: find.byType(DayBar)), findsOneWidget);
    }
  });

  testWidgets('во время пары быстрые действия сохраняют предмет, дату и номер пары', (tester) async {
    await screen(tester, hero(now));
    Future<void> tap(String label) async {
      await tester.ensureVisible(find.text(label).last);
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tap('Оценка');
    await tap('8');
    await tap('Сохранить');
    expect(store.grades.single.subject, slots.first.subject);
    expect(sameDay(store.grades.single.date, now), isTrue);
    await tap('Пропуск');
    final choices = find.byType(ExcuseTile);
    final first = tester.getRect(choices.first);
    final second = tester.getRect(choices.last);
    expect((first.top, first.bottom, first.width), (second.top, second.bottom, second.width));
    await tap('Без уважительной');
    expect(store.absenceFor(now, 2)?.excused, isFalse);
    await tap('Пометка');
    expect(find.text('К чему относится'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Пересдача');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(store.markFor(now, 2)?.label, 'Пересдача');
    expect(store.markFor(now, 0), isNull);
    await screen(tester, hero(DateTime(2026, 11, 18, 18)));
    expect(find.text('Пометка'), findsNothing);
    final tile = find.descendant(of: find.byType(DayBar), matching: find.byType(InkWell)).last;
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.text('История'), findsWidgets);
    expect(find.text('Добавить оценку по предмету'), findsOneWidget);
  });

  testWidgets('обе причины доступны при крупном шрифте на узком телефоне', (tester) async {
    await screen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => toggleLessonAbsence(context, store, now, slots.last),
          child: const Text('Пропуск'),
        ),
      ),
      width: 320,
      scale: 1.8,
    );
    await tester.tap(find.text('Пропуск'));
    await tester.pumpAndSettle();
    final tiles = find.byType(ExcuseTile);
    await tester.ensureVisible(tiles.last);
    final a = tester.getRect(tiles.first);
    final b = tester.getRect(tiles.last);
    expect((a.top, a.bottom, a.width), (b.top, b.bottom, b.width));
    await tester.tap(tiles.last);
    await tester.pumpAndSettle();
    expect(store.absenceFor(now, slots.last.number)?.excused, isTrue);
  });

  testWidgets('поиск по меню находит е и ё и принимает выбор с клавиатуры', (tester) async {
    String? result;
    await screen(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSelectSheet<String>(
            context,
            title: 'Предмет',
            options: [const MenuOption('test', 'Зачёт'), for (var i = 0; i < 9; i++) MenuOption('$i', 'Предмет $i')],
            onSelected: (value) => result = value,
          ),
          child: const Text('Открыть'),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' зачет ');
    await tester.pumpAndSettle();
    expect(find.text('Зачёт'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(result, 'test');
  });

  testWidgets('под часами видна карточка при обновлении и поверхность списка после прокрутки', (tester) async {
    const inset = 59.0;
    tester.view.padding = const FakeViewPadding(top: inset);
    tester.view.viewPadding = const FakeViewPadding(top: inset);
    for (var i = 0; i < 3; i++) {
      store.saveTask(Task(id: 't$i', date: today(), lesson: 1, due: today(), text: 'Задание $i', subject: 'Физика'));
    }
    final key = GlobalKey();
    await screen(
      tester,
      RepaintBoundary(
        key: key,
        child: HomePage(onTab: (_) {}, onDay: (_) {}),
      ),
      scroll: false,
    );
    final context = tester.element(find.byType(HomePage));
    final scheme = Theme.of(context).colorScheme;
    expect(tester.getTopLeft(find.byType(CustomScrollView)).dy, 0);
    void checkClock(Color surface) {
      final layer = tester.binding.renderViews.first.debugLayer!;
      final style = layer.find<SystemUiOverlayStyle>(const Offset(180, inset / 2));
      expect(style?.statusBarColor, Colors.transparent);
      expect(style?.statusBarBrightness, ThemeData.estimateBrightnessForColor(surface));
    }

    Future<void> check(Color color, List<int> ys) async {
      final rgba = ((color.toARGB32() & 0xffffff) << 8) | 0xff;
      final samples = await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          return [for (final y in ys) pixels.getUint32((y * image.width + 5) * 4)];
        } finally {
          image.dispose();
        }
      });
      expect(samples, everyElement(rgba));
    }

    final heroHeight = tester.getSize(find.byType(HeroSurface)).height;
    checkClock(scheme.primaryContainer);
    await check(scheme.primaryContainer, [0, 32, 58, 60]);
    final gesture = await tester.startGesture(const Offset(80, 160));
    await gesture.moveBy(const Offset(0, 32));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(position.pixels, lessThan(-30));
    checkClock(scheme.primaryContainer);
    await check(scheme.primaryContainer, [0, 32, 58, 60, 80]);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(repo.refreshed, isNotEmpty);
    await tester.drag(find.byType(CustomScrollView), Offset(0, -heroHeight - 200));
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    expect(position.pixels, greaterThan(heroHeight));
    checkClock(scheme.surface);
    await check(scheme.surface, [0, 32, 58]);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    final bottomPull = await tester.startGesture(const Offset(100, 715));
    await bottomPull.moveBy(const Offset(0, -32));
    await tester.pump();
    await bottomPull.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(position.pixels, greaterThan(position.maxScrollExtent));
    await check(scheme.surface, [795, 810]);
    await bottomPull.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('показатели закреплены, старый порядок и видимость читаются независимо', (tester) async {
    store.setHomeLayout([kBlockRecent, kBlockTasks, kBlockMetrics, kBlockWeek, kBlockTomorrow], [kBlockMetrics]);
    Widget home() => HomePage(onTab: (_) {}, onDay: (_) {});
    await screen(tester, home(), scroll: false);
    expect(find.byType(DayMetrics), findsNothing);
    await screen(tester, const HomeLayoutPage(), scroll: false);
    final pinned = find.byKey(const ValueKey('layout-metrics'));
    expect(find.descendant(of: pinned, matching: find.byTooltip('Ниже')), findsNothing);
    await tester.tap(find.descendant(of: pinned, matching: find.byType(SettingsSwitch)));
    await tester.pumpAndSettle();
    expect(store.settings.homeOrder.where((id) => id != kBlockMetrics), [
      kBlockRecent,
      kBlockTasks,
      kBlockWeek,
      kBlockTomorrow,
    ]);
    await screen(tester, home(), scroll: false);
    expect(find.descendant(of: find.byType(HeroSurface), matching: find.byType(DayMetrics)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('локальные показатели доступны в выходной и без сети', (tester) async {
    for (final status in [DayStatus.sunday, DayStatus.offline]) {
      repo.status = status;
      await screen(tester, HomePage(key: ValueKey(status), onTab: (_) {}, onDay: (_) {}), scroll: false);
      expect(find.text(status == DayStatus.sunday ? 'Сегодня выходной' : 'Не удалось загрузить'), findsOneWidget);
      expect(find.descendant(of: find.byType(HeroSurface), matching: find.byType(DayMetrics)), findsOneWidget);
    }
  });

  testWidgets('кольца показывают запас и превышение, включая крупный шрифт', (tester) async {
    for (final (hours, expected) in [
      (0, 'Осталось часов'),
      (7, 'Близко к лимиту'),
      (10, 'Лимит достигнут'),
      (12, 'Превышено на 2 часа'),
    ]) {
      await screen(
        tester,
        LimitCounters(monthHours: hours, semesterHours: 15, semester: store.semesterOn(now), onSemesterTap: () {}),
        width: 320,
        scale: 2,
      );
      expect(find.text(expected), findsAtLeastNWidgets(1));
      expect(find.text('$hours из 10 ч'), findsOneWidget);
      expect(find.text('57'), findsOneWidget);
      expect(find.text('${(10 - hours).clamp(0, 10)}'), findsOneWidget);
    }
  });

  testWidgets('первая оценка сразу обновляет сводку и доступное описание графика', (tester) async {
    store.putSchedule(DaySchedule(date: today(), group: store.settings.group, slots: slots, fetchedAt: now));
    const early = BellProfile(slots: {2: BellSlot(start: 0, end: 60)});
    store.setBellProfile(store.bellKeyOn(today()), early);
    await screen(tester, const GradesPage(), width: 320, scale: 2, scroll: false);
    await tester.tap(find.text('Добавить оценку'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('9').last);
    await tester.tap(find.text('9').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить'));
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(store.grades.single.value, 9);
    expect(find.text('Распределение оценок'), findsOneWidget);
    expect(find.bySemanticsLabel('Оценка 9, 1 оценка'), findsOneWidget);
  });

  testWidgets('в календаре тон меняется только при смене предмета', (tester) async {
    LessonSlot slot(int n, List<String> names) => LessonSlot(
      number: n,
      entries: [for (final name in names) LessonEntry(subject: name, room: '$n', teacher: 'Преподаватель $n')],
    );
    final day = [
      slot(1, ['АнглЯз']),
      slot(2, ['Английский язык']),
      slot(3, ['Физика', 'Химия']),
      slot(4, ['химия', 'Физика']),
      slot(5, ['АнглЯз']),
    ];
    expect(darkerLessons(day.reversed, store), {3, 4});
    await screen(tester, DayTimeline(date: now, slots: day, store: store, now: now));
    final fills = {
      for (final element in find.byType(LessonCard).evaluate())
        (element.widget as LessonCard).slot.number: tester
            .widget<SegmentCard>(find.descendant(of: find.byWidget(element.widget), matching: find.byType(SegmentCard)))
            .color,
    };
    expect(fills[1], fills[2]);
    expect(fills[1], fills[5]);
    expect(fills[3], fills[4]);
    expect(fills[3], isNot(fills[2]));
  });

  testWidgets('свайп недели и смена ширины сохраняют выбранный день', (tester) async {
    final controller = ScheduleController();
    await screen(tester, SchedulePage(controller: controller), scroll: false);
    final distant = DateTime(2031, 3, 5);
    controller.jumpTo(distant);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView).first, const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(controller.selected, addDays(distant, 7));
    tester.view.physicalSize = const Size(900, 812);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Показать неделю'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Следующая неделя'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(360, 812);
    await tester.pumpAndSettle();
    final selected = addDays(distant, 14);
    expect(controller.selected, selected);
    final dateChip = find
        .descendant(of: find.byType(PageView).first, matching: find.text('${selected.day}'))
        .hitTestable();
    expect(dateChip, findsOneWidget);
    expect(find.text(longDate(selected)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('в недельной сетке время общее для разных профилей звонков', (tester) async {
    final monday = DateTime(2031, 3, 3);
    store.setBellProfile(kBellWeek, const BellProfile(slots: {1: BellSlot(start: 480, end: 540)}));
    store.setBellProfile(kBellSat, const BellProfile(slots: {1: BellSlot(start: 540, end: 600)}));
    for (var i = 0; i < 6; i++) {
      final date = addDays(monday, i);
      store.putSchedule(
        DaySchedule(
          date: date,
          fetchedAt: now,
          group: store.settings.group,
          slots: [
            LessonSlot(
              number: 1,
              entries: [LessonEntry(subject: 'Курс $i', room: '214', teacher: '')],
            ),
          ],
        ),
      );
    }
    store.saveMark(DayMark(id: 'all', date: monday, lesson: 0, label: 'Практика'));
    await screen(
      tester,
      WeekView(refresh: 0, selected: monday, onShift: (_) {}, onOpenDay: (_) {}),
      width: 960,
      scroll: false,
    );
    Rect event(String name) => tester.getRect(find.ancestor(of: find.text(name), matching: find.byType(InkWell)).first);
    expect(event('Курс 0').top, event('Курс 1').top);
    final hour = tester.getTopLeft(find.text('09:00')).dy - tester.getTopLeft(find.text('08:00')).dy;
    expect(event('Курс 5').top - event('Курс 0').top, closeTo(hour, .01));
    expect(find.text('Практика'), findsOneWidget);
    await tester.tap(find.text('Курс 5'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить оценку по предмету'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
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
