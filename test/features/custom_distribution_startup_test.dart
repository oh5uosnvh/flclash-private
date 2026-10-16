import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom distribution startup has no unregistered Firebase dependency', () {
    final source = File(
      'android/common/src/main/java/com/follow/clash/common/GlobalState.kt',
    ).readAsStringSync();
    expect(source, isNot(contains('FirebaseCrashlytics.getInstance()')));
    expect(source, isNot(contains('FirebaseApp.initializeApp')));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.follow.clash.qiyiguo112"'));
    expect(gradle, isNot(contains('applicationIdSuffix')));
  });
}
