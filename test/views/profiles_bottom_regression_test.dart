import 'package:fl_clash/views/profiles/profiles_locator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'long masonry list reaches real bottom without stranding last card',
    (tester) async {
      final controller = ScrollController();
      final locator = ProfilesLocator(controller);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MasonryGridView.count(
              controller: controller,
              crossAxisCount: 1,
              itemCount: 80,
              itemBuilder: (_, index) => SizedBox(
                height: index % 7 == 0 ? 360 : 110,
                child: Text('profile-$index'),
              ),
            ),
          ),
        ),
      );
      for (var repeat = 0; repeat < 3; repeat++) {
        locator.toBottom();
        await tester.pump();
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(microseconds: 16667));
        }
        await tester.pump();
        expect(find.text('profile-79'), findsOneWidget);
        expect(
          controller.position.maxScrollExtent - controller.offset,
          lessThanOrEqualTo(0.5),
        );
        expect(controller.offset, greaterThan(8000));
        locator.toTop();
        await tester.pumpAndSettle();
        expect(find.text('profile-0'), findsOneWidget);
        expect(controller.offset, closeTo(0, 0.5));
      }
      locator.cancel();
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
