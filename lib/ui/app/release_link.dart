import 'package:flutter/services.dart' show PlatformException;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../kit/components/feedback.dart';

Future<void> openRelease(BuildContext context, Uri page) async {
  try {
    if (await launchUrl(page, mode: LaunchMode.externalApplication)) return;
  } on PlatformException {
    // Например, устройство не разрешает запуск браузера.
  }
  if (context.mounted) showNote(ScaffoldMessenger.of(context), 'Не удалось открыть страницу релиза');
}
