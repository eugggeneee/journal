import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:journal/core/dates.dart';
import 'package:journal/logic/cp1251.dart';
import 'package:journal/logic/schedule_parser.dart';
import 'package:journal/logic/schedule_service.dart';

void main() {
  final bytes = File('test/fixtures/PODNAM_30_10.htm').readAsBytesSync();
  final page = ScheduleParser.parse(decodeHtmlBytes(bytes));

  test('url matches shortcut', () {
    expect(ScheduleService.urlFor(DateTime(2026, 10, 30)).toString(),
        'https://bseumtc.by/schedule/public/rasp/PODNAM%2030_10.htm');
  });

  test('group 6312 has 4 lessons with rooms', () {
    final slots = ScheduleParser.slotsFor(page, '6312');
    expect(slots.map((s) => s.number), [1, 2, 3, 4]);
    expect(slots[0].entries.single.subject, 'ТоварПродТов');
    expect(slots[0].entries.single.room, '304');
    expect(slots[0].entries.single.teacher, 'Кузнецова Г.Г.');
    expect(slots[3].entries.single.subject, 'ЭкономикаОрган');
    expect(slots[3].entries.single.room, '201');
  });

  test('subgroups are merged into one slot', () {
    final slots = ScheduleParser.slotsFor(page, '6492');
    final first = slots.firstWhere((s) => s.number == 1);
    expect(first.entries.length, 2);
  });

  test('header date is validated', () {
    expect(ScheduleService.pageMatchesDate(page, DateTime(2026, 10, 30)), isTrue);
    expect(ScheduleService.pageMatchesDate(page, DateTime(2026, 10, 29)), isFalse);
  });

  test('plural', () {
    expect(hoursText(1), '1 час');
    expect(hoursText(2), '2 часа');
    expect(hoursText(5), '5 часов');
  });
}
