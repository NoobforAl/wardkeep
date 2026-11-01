import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Every widget test also checks that what it created is disposed: a controller, a notifier, an
/// animation that outlives its screen is reported as a failure of the test that made it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  // An asset image still loading when a test ends (the shield at the end of Settings) leaves the image cache's
  // handle open; that is the test ending early, not a leak of the app.
  LeakTesting.settings = LeakTesting.settings.withTrackedAll().withIgnored(classes: ['ImageStreamCompleterHandle']);
  await testMain();
}
