import 'package:flutter_test/flutter_test.dart';

import 'package:staylocal/utils/download_speed.dart';

DateTime _at(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

void main() {
  test('first sample only establishes the baseline', () {
    final tracker = DownloadSpeedTracker();

    expect(tracker.update(0, _at(0)), isNull);
  });

  test('emitted speed holds steady between half-second gates', () {
    final tracker = DownloadSpeedTracker();

    expect(tracker.update(0, _at(0)), isNull);
    expect(tracker.update(100000, _at(100)), closeTo(300000, 1));
    expect(tracker.update(200000, _at(200)), closeTo(300000, 1));
    expect(tracker.update(300000, _at(300)), closeTo(300000, 1));
  });

  test('emitted speed refreshes once the gate passes', () {
    final tracker = DownloadSpeedTracker();

    tracker.update(0, _at(0));
    tracker.update(100000, _at(100));
    tracker.update(200000, _at(200));
    expect(tracker.update(600000, _at(600)), closeTo(657000, 1));
  });

  test('a stalled stream decays instead of freezing', () {
    final tracker = DownloadSpeedTracker();

    tracker.update(0, _at(0));
    tracker.update(100000, _at(100));
    expect(tracker.update(100000, _at(700)), closeTo(210000, 1));
  });
}
