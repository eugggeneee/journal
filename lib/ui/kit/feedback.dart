import 'package:material_ui/material_ui.dart';

import '../../core/haptics.dart';

/// Сообщение с кнопкой «Отменить». Возвращает управление, когда действие уже выполнено.
void showUndo(ScaffoldMessengerState m, String message, VoidCallback onUndo) {
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message),
    persist: false,
    duration: const Duration(seconds: 5),
    action: SnackBarAction(
      label: 'Отменить',
      onPressed: () {
        Haptics.selection();
        onUndo();
      },
    ),
  ));
}

void showNote(ScaffoldMessengerState m, String message) {
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), persist: false, duration: const Duration(seconds: 3)));
}
