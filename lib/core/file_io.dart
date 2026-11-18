import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Файловый обмен для резервной копии. Весь код плагинов собран здесь: остальное приложение их не знает.
class FileIo {
  const FileIo._();

  /// Отдаёт текст как файл [name] через системное меню «Поделиться» (там можно сохранить в «Файлы», на диск
  /// или отправить себе). Возвращает false, если системное меню не открылось.
  static Future<bool> shareText(String name, String content, {required Rect origin, String mimeType = 'application/json'}) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(content));
      final file = XFile.fromData(bytes, mimeType: mimeType, name: name);
      await SharePlus.instance.share(ShareParams(files: [file], fileNameOverrides: [name], sharePositionOrigin: origin));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Даёт выбрать файл и возвращает его текст; null, если выбор отменён или файл не прочитался.
  static Future<String?> pickText() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (r == null || r.files.isEmpty) return null;
      final bytes = r.files.first.bytes;
      if (bytes == null) return null;
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }
}
