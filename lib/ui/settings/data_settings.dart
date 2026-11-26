part of 'settings_pages.dart';

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({super.key});

  Future<void> _exportFile(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final d = journalNow();
    final name = 'journal-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
    final box = context.findRenderObject()! as RenderBox;
    final viewport = Offset.zero & MediaQuery.sizeOf(context);
    final origin = (box.localToGlobal(Offset.zero) & box.size).intersect(viewport);
    final ok = await FileIo.shareText(name, store.exportJson(), origin: origin);
    if (!context.mounted) return;
    Haptics.medium();
    if (!ok) showNote(messenger, 'Не удалось открыть меню отправки. Скопируйте копию в буфер обмена.');
  }

  Future<void> _exportClipboard(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: store.exportJson()));
    Haptics.medium();
    showNote(messenger, 'Копия в буфере обмена');
  }

  Future<void> _importFile(BuildContext context) async {
    final text = await FileIo.pickText();
    if (!context.mounted) return;
    if (text == null || text.trim().isEmpty) {
      await infoDialog(context, 'Файл не выбран', 'Выберите файл копии с расширением .json.');
      return;
    }
    await _restore(context, text);
  }

  Future<void> _importClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (!context.mounted) return;
    if (text.trim().isEmpty) {
      await infoDialog(context, 'Буфер обмена пуст', 'Сначала скопируйте текст резервной копии.');
      return;
    }
    await _restore(context, text);
  }

  Future<void> _restore(BuildContext context, String text) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Восстановить данные?',
      message: 'Текущие отметки, пропуски, пометки, задания и звонки будут заменены данными из копии.',
      confirmLabel: 'Восстановить',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final err = store.importJson(text);
    if (err != null) {
      await infoDialog(context, 'Ошибка', err);
    } else {
      showNote(messenger, 'Данные восстановлены');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <(IconData, String, String, ValueChanged<BuildContext>)>[
      (Icons.ios_share_rounded, 'Сохранить в файл', 'Файл .json: отметки, пропуски, пометки, задания и звонки', _exportFile),
      (Icons.folder_open_rounded, 'Восстановить из файла', 'Выбрать файл .json с копией', _importFile),
      (Icons.content_copy_rounded, 'Скопировать в буфер обмена', 'Копия текстом, если файл не подходит', _exportClipboard),
      (Icons.content_paste_rounded, 'Вставить из буфера обмена', 'Восстановить из скопированного текста', _importClipboard),
    ];
    return SettingsScaffold(title: 'Данные', children: [
        for (var i = 0; i < tiles.length; i++)
          Builder(builder: (rowContext) => SegmentCard(
            index: i,
            count: tiles.length,
            onTap: () => tiles[i].$4(rowContext),
            child: SettingsTile(icon: tiles[i].$1, title: tiles[i].$2, subtitle: tiles[i].$3),
          )),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
          child: Text(
            'Отметки, пропуски и пометки хранятся только на этом устройстве. Расписание берётся с сайта bseumtc.by.',
            style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant, height: 1.4),
          ),
        ),
      ]);
  }
}
