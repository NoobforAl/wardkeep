import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Writes what integration_test/perf_test.dart traced: `build/SCENARIO.timeline_summary.json` for
/// each scenario, and build/memory.json.
Future<void> main() {
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      for (final entry in data.entries) {
        if (entry.key == 'memory') {
          await File('build/memory.json').writeAsString(const JsonEncoder.withIndent('  ').convert(entry.value));
          continue;
        }
        final timeline = driver.Timeline.fromJson(entry.value as Map<String, dynamic>);
        await driver.TimelineSummary.summarize(timeline).writeTimelineToFile(entry.key, destinationDirectory: 'build', pretty: true);
      }
    },
  );
}
