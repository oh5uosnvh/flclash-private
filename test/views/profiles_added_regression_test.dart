import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/profiles/profiles.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/profile_focus_test.dart' show pumpProfiles;

void main() {
  testWidgets('new profile reveals bottom without losing existing cards', (
    tester,
  ) async {
    final profiles = List.generate(
      60,
      (i) => Profile.normal(label: 'existing-$i'),
    );
    final container = await pumpProfiles(tester, profiles: profiles);
    final added = Profile.normal(label: 'new-import');
    container.read(profilesProvider.notifier).put(added);
    await tester.pumpAndSettle();
    expect(find.text('new-import'), findsOneWidget);
    expect(container.read(profilesProvider).length, 61);
    final title = find.text(currentAppLocalizations.profiles).first;
    await tester.tap(title);
    await tester.pumpAndSettle();
    // A second tap locates the selected first card if it was off-screen.
    if (find.text('existing-0').evaluate().isEmpty) {
      await tester.tap(title);
      await tester.pumpAndSettle();
    }
    expect(find.byType(ProfileItem), findsWidgets);
    expect(container.read(profilesProvider).length, 61);
  });
}
