import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:journal/ui/kit/animation/motion.dart';
import 'package:journal/ui/kit/animation/tab_switcher.dart';
import 'package:journal/ui/kit/animation/reveal.dart';

void main() {
  tearDown(() => Motion.level = 0);

  testWidgets('быстрый возврат между вкладками сохраняет ввод', (tester) async {
    var index = 0;
    late StateSetter change;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, set) {
      change = set;
      return Scaffold(body: TabSwitcher(index: index, children: const [
        TextField(key: ValueKey('input')), Text('Вторая'), Text('Третья'),
      ]));
    })));
    await tester.enterText(find.byType(TextField), 'Сохранённый ввод');
    change(() => index = 1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    change(() => index = 2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    change(() => index = 0);
    await tester.pumpAndSettle();
    expect(find.text('Сохранённый ввод'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('системное уменьшение движения сразу показывает вкладку и каскад', (tester) async {
    var index = 0;
    late StateSetter change;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, set) {
      change = set;
      return MediaQuery(data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: TabSwitcher(index: index, children: const [
          Text('Первая'), Appear(index: 4, child: Text('Вторая')),
        ])));
    })));
    change(() => index = 1);
    await tester.pump();
    expect(find.text('Вторая').hitTestable(), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });
}
