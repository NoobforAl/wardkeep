import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

/// Every widget test also checks that what it created is disposed: a controller, a notifier, an
/// animation that outlives its screen is reported as a failure of the test that made it.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  LeakTesting.enable();
  // An asset image still loading when a test ends (the shield of the loading screen, or at the end of Settings)
  // leaves the image cache's handle open; that is the test ending early, not a leak of the app.
  LeakTesting.settings = LeakTesting.settings.withTrackedAll().withIgnored(classes: ['ImageStreamCompleterHandle']);
  // The same early end leaves the image live in the cache; a slow machine (CI) ends tests before the shield is
  // decoded. Emptying the cache after each test disposes it.
  tearDown(() {
    if (BindingBase.debugBindingType() == null) return; // a plain test, with no images
    final cache = PaintingBinding.instance.imageCache;
    cache
      ..clear()
      ..clearLiveImages();
  });
  await testMain();
}
