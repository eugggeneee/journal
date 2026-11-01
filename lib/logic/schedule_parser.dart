import '../data/models.dart';

class ParsedRow {
  const ParsedRow(this.group, this.lesson, this.entry);
  final String group;
  final int lesson;
  final LessonEntry entry;
}

class ParsedPage {
  const ParsedPage({required this.rows, required this.headerDates, required this.hasText});
  final List<ParsedRow> rows;

  /// Даты из заголовков страницы в формате dd.MM.yy (напр. «30.10.26»).
  final Set<String> headerDates;
  final bool hasText;
}

/// Разбор страницы вида «PODNAM dd_MM.htm» (HTML, сохранённый из Word:
/// каждая строка таблицы — отдельный <p> с псевдографикой «│»).
class ScheduleParser {
  static final _comments = RegExp(r'<!--.*?-->', dotAll: true);
  static final _styleScript =
      RegExp(r'<(style|script)\b.*?</\1>', dotAll: true, caseSensitive: false);
  static final _bodyTag = RegExp(r'<body', caseSensitive: false);
  static final _pOpen = RegExp(r'<p\b[^>]*>', caseSensitive: false);
  static final _tags = RegExp(r'<[^>]*>');
  static final _spaces = RegExp(r'\s+');
  static final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');
  static final _date = RegExp(r'(\d{2})\.(\d{2})\.(\d{2})');
  static final _groupCell = RegExp(r'^\d{3,5}$');
  static final _numCell = RegExp(r'^\d{1,2}$');

  static String _decodeEntities(String s) {
    if (!s.contains('&')) return s;
    return s.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x')) {
        final c = int.tryParse(e.substring(2), radix: 16);
        return c == null ? m.group(0)! : String.fromCharCode(c);
      }
      if (e.startsWith('#')) {
        final c = int.tryParse(e.substring(1));
        return c == null ? m.group(0)! : String.fromCharCode(c);
      }
      switch (e) {
        case 'nbsp':
          return ' ';
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
        default:
          return m.group(0)!;
      }
    });
  }

  static ParsedPage parse(String html) {
    var s = html.replaceAll(_comments, '').replaceAll(_styleScript, '');
    final b = _bodyTag.firstMatch(s);
    if (b != null) s = s.substring(b.start);

    final paragraphs = <String>[];
    for (final chunk in s.split(_pOpen)) {
      var t = chunk.replaceAll(_tags, '');
      t = _decodeEntities(t).replaceAll('\u00a0', ' ').replaceAll(_spaces, ' ').trim();
      if (t.isNotEmpty) paragraphs.add(t);
    }

    final rows = <ParsedRow>[];
    final headerText = StringBuffer();
    var group = '';
    int? lesson;

    for (final p in paragraphs) {
      if (!p.contains('│')) {
        headerText.write('$p ');
        continue;
      }
      final parts = p.split('│').map((e) => e.trim()).toList();
      if (parts.isNotEmpty && parts.first.isEmpty) parts.removeAt(0);
      if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
      if (parts.length != 5) continue;

      final g = parts[0], n = parts[1], subj = parts[2], room = parts[3], teacher = parts[4];
      if (g.isNotEmpty && !_groupCell.hasMatch(g)) continue; // шапка таблицы
      if (n.isNotEmpty && !_numCell.hasMatch(n)) continue;

      if (g.isNotEmpty) {
        group = g;
        lesson = null;
      }
      if (n.isNotEmpty) lesson = int.parse(n);
      if (group.isEmpty || lesson == null) continue;
      if (subj.isEmpty || subj == '√') continue; // «√» — служебная отметка без предмета

      rows.add(ParsedRow(group, lesson, LessonEntry(subject: subj, room: room, teacher: teacher)));
    }

    final dates = <String>{
      for (final m in _date.allMatches(headerText.toString())) m.group(0)!,
    };
    return ParsedPage(rows: rows, headerDates: dates, hasText: paragraphs.isNotEmpty);
  }

  /// Собирает пары одной группы: подгруппы с одним номером — в один слот.
  static List<LessonSlot> slotsFor(ParsedPage page, String group) {
    final byNumber = <int, List<LessonEntry>>{};
    for (final r in page.rows) {
      if (r.group != group) continue;
      final list = byNumber.putIfAbsent(r.lesson, () => []);
      if (!list.contains(r.entry)) list.add(r.entry);
    }
    final numbers = byNumber.keys.toList()..sort();
    return [for (final n in numbers) LessonSlot(number: n, entries: byNumber[n]!)];
  }
}
