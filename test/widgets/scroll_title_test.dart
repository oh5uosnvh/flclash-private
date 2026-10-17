import 'package:fl_clash/ui/scroll_title.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('title tap and 300ms hold remain distinct', (tester) async {
    var taps = 0;
    var holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScrollTitle(
            title: 'Title',
            onTap: () => taps++,
            onLongPress: () => holds++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Title'));
    expect(taps, 1);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Title')),
    );
    await tester.pump(const Duration(milliseconds: 299));
    expect(holds, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(holds, 1);
    await gesture.up();
    expect(taps, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
