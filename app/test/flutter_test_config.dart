import 'dart:async';

import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Every widget test also checks that what it created is disposed: a controller, a notifier, an
/// animation that outlives its screen is reported as a failure of the test that made it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  LeakTesting.settings = LeakTesting.settings.withTrackedAll();
  await testMain();
}
