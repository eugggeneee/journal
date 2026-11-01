/// Декодер windows-1251 (сайт колледжа отдаёт страницы в этой кодировке).
library;

import 'dart:convert';

const List<int> _high = [
  0x0402, 0x0403, 0x201A, 0x0453, 0x201E, 0x2026, 0x2020, 0x2021,
  0x20AC, 0x2030, 0x0409, 0x2039, 0x040A, 0x040C, 0x040B, 0x040F,
  0x0452, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
  0x0098, 0x2122, 0x0459, 0x203A, 0x045A, 0x045C, 0x045B, 0x045F,
  0x00A0, 0x040E, 0x045E, 0x0408, 0x00A4, 0x0490, 0x00A6, 0x00A7,
  0x0401, 0x00A9, 0x0404, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x0407,
  0x00B0, 0x00B1, 0x0406, 0x0456, 0x0491, 0x00B5, 0x00B6, 0x00B7,
  0x0451, 0x2116, 0x0454, 0x00BB, 0x0458, 0x0405, 0x0455, 0x0457,
];

String decodeCp1251(List<int> bytes) {
  final out = StringBuffer();
  for (final b in bytes) {
    if (b < 0x80) {
      out.writeCharCode(b);
    } else if (b < 0xC0) {
      out.writeCharCode(_high[b - 0x80]);
    } else {
      out.writeCharCode(0x0410 + (b - 0xC0));
    }
  }
  return out.toString();
}

/// Определяет кодировку по <meta charset> и декодирует. По умолчанию — cp1251,
/// если страница не является корректным UTF-8.
String decodeHtmlBytes(List<int> bytes) {
  final head = latin1.decode(
    bytes.length > 4096 ? bytes.sublist(0, 4096) : bytes,
    allowInvalid: true,
  );
  final m = RegExp(r'charset\s*=\s*["\x27]?\s*([\w-]+)', caseSensitive: false)
      .firstMatch(head);
  final cs = (m?.group(1) ?? '').toLowerCase();
  if (cs == 'utf-8' || cs == 'utf8') {
    return utf8.decode(bytes, allowMalformed: true);
  }
  if (cs.isEmpty) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return decodeCp1251(bytes);
    }
  }
  return decodeCp1251(bytes);
}
