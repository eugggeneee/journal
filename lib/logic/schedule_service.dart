import 'dart:async';

import 'package:http/http.dart' as http;

import '../core/dates.dart';
import '../data/models.dart';
import '../data/store.dart';
import 'cp1251.dart';
import 'schedule_parser.dart';

enum FetchStatus { ok, notPublished, noGroup, sunday, offline, error }

class FetchResult {
  const FetchResult(this.status, {this.slots, this.page, this.message});
  final FetchStatus status;
  final List<LessonSlot>? slots;
  final ParsedPage? page;
  final String? message;
}

/// Сетевой слой: строит URL, скачивает страницу и разбирает её.
class ScheduleService {
  ScheduleService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const base = 'https://bseumtc.by/schedule/public/rasp/';

  /// https://bseumtc.by/schedule/public/rasp/PODNAM%2030_10.htm
  static Uri urlFor(DateTime d) => Uri.parse('${base}PODNAM%20${two(d.day)}_${two(d.month)}.htm');

  /// Страница должна относиться именно к запрошенной дате (в URL нет года).
  static bool pageMatchesDate(ParsedPage page, DateTime d) {
    if (page.headerDates.isEmpty) return true;
    final expected = '${two(d.day)}.${two(d.month)}.${two(d.year % 100)}';
    return page.headerDates.contains(expected);
  }

  /// Скачивает и разбирает страницу дня целиком (все группы).
  Future<FetchResult> download(DateTime date) async {
    if (date.weekday == DateTime.sunday) return const FetchResult(FetchStatus.sunday);
    final http.Response res;
    try {
      res = await _client
          .get(urlFor(date), headers: const {'Accept': 'text/html'})
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return const FetchResult(FetchStatus.offline, message: 'Сайт не отвечает');
    } catch (_) {
      return const FetchResult(FetchStatus.offline, message: 'Нет подключения к интернету');
    }
    if (res.statusCode == 404 || res.statusCode == 403) {
      return const FetchResult(FetchStatus.notPublished);
    }
    if (res.statusCode != 200) {
      return FetchResult(FetchStatus.error, message: 'Ошибка сайта (${res.statusCode})');
    }
    if (res.bodyBytes.isEmpty) return const FetchResult(FetchStatus.notPublished);

    final ParsedPage page;
    try {
      page = ScheduleParser.parse(decodeHtmlBytes(res.bodyBytes));
    } catch (_) {
      return const FetchResult(FetchStatus.error, message: 'Не удалось разобрать страницу');
    }
    if (!page.hasText || page.rows.isEmpty) return const FetchResult(FetchStatus.notPublished);
    if (!pageMatchesDate(page, date)) return const FetchResult(FetchStatus.notPublished);
    return FetchResult(FetchStatus.ok, page: page);
  }

  Future<FetchResult> fetch(DateTime date, String group) async {
    final r = await download(date);
    if (r.status != FetchStatus.ok) return r;
    final slots = ScheduleParser.slotsFor(r.page!, group);
    if (slots.isEmpty) return const FetchResult(FetchStatus.noGroup);
    return FetchResult(FetchStatus.ok, slots: slots);
  }

  /// Список групп, которые сейчас есть на сайте (берётся ближайший опубликованный день).
  Future<({List<String> groups, bool offline})> listGroups() async {
    final t = today();
    const offsets = [0, 1, 2, 3, 4, 5, -1, -2, -3, -4, -5, -6];
    for (final o in offsets) {
      final r = await download(addDays(t, o));
      if (r.status == FetchStatus.offline) return (groups: const <String>[], offline: true);
      if (r.status == FetchStatus.ok) {
        final set = {for (final row in r.page!.rows) row.group};
        final list = set.toList()
          ..sort((a, b) {
            final x = int.tryParse(a), y = int.tryParse(b);
            if (x != null && y != null) return x.compareTo(y);
            return a.compareTo(b);
          });
        return (groups: list, offline: false);
      }
    }
    return (groups: const <String>[], offline: false);
  }
}

enum DayStatus { ok, notPublished, noGroup, sunday, offline, error }

/// Итог для экрана одного дня.
class DayState {
  const DayState(this.status, {this.schedule, this.fromCache = false, this.note});
  final DayStatus status;
  final DaySchedule? schedule;
  final bool fromCache;
  final String? note;
}

/// Репозиторий: кэш + сеть.
class ScheduleRepo {
  ScheduleRepo(this.store, {ScheduleService? service}) : service = service ?? ScheduleService();
  final AppStore store;
  final ScheduleService service;
  final Map<String, Future<DayState>> _inflight = {};

  static const _freshFor = Duration(minutes: 20);

  Future<DayState> load(DateTime date, {bool force = false}) {
    final group = store.settings.group;
    final key = '$group|${ymd(date)}|$force';
    return _inflight.putIfAbsent(key, () async {
      try {
        return await _load(dateOnly(date), group, force);
      } finally {
        _inflight.remove(key);
      }
    });
  }

  /// Тихая подгрузка ближайших дней в кэш.
  ///
  /// [respectSetting] — учитывать переключатель «Автообновление». Ручные действия
  /// (смена группы, кнопка «Обновить») передают false или force.
  Future<void> prefetch({int days = 4, bool force = false, bool respectSetting = true}) async {
    if (!store.hasGroup) return;
    if (respectSetting && !force && !store.settings.autoRefresh) return;
    final t = today();
    await Future.wait([
      for (var i = 0; i <= days; i++)
        if (addDays(t, i).weekday != DateTime.sunday)
          load(addDays(t, i), force: force).catchError((_) => const DayState(DayStatus.error)),
    ]);
  }

  Future<DayState> _load(DateTime date, String group, bool force) async {
    if (group.isEmpty) return const DayState(DayStatus.noGroup);
    if (date.weekday == DateTime.sunday) return const DayState(DayStatus.sunday);

    final cached = store.cachedSchedule(group, date);
    final isPast = date.isBefore(today());
    final isFresh = cached != null && (isPast || DateTime.now().difference(cached.fetchedAt) < _freshFor);
    if (!force && isFresh) return DayState(DayStatus.ok, schedule: cached, fromCache: true);

    final res = await service.fetch(date, group);
    switch (res.status) {
      case FetchStatus.ok:
        final loaded = DaySchedule(date: date, group: group, slots: res.slots!, fetchedAt: DateTime.now());
        store.putSchedule(loaded);
        return DayState(DayStatus.ok, schedule: loaded);
      case FetchStatus.sunday:
        return const DayState(DayStatus.sunday);
      case FetchStatus.noGroup:
      case FetchStatus.notPublished:
      case FetchStatus.offline:
      case FetchStatus.error:
        if (cached != null) {
          return DayState(
            DayStatus.ok,
            schedule: cached,
            fromCache: true,
            note: res.status == FetchStatus.offline ? 'Нет сети — показано сохранённое расписание' : null,
          );
        }
        final status = switch (res.status) {
          FetchStatus.offline => DayStatus.offline,
          FetchStatus.error => DayStatus.error,
          FetchStatus.noGroup => DayStatus.noGroup,
          _ => DayStatus.notPublished,
        };
        return DayState(status, note: res.message);
    }
  }
}
