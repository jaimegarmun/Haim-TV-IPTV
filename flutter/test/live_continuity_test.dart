import 'package:flutter_test/flutter_test.dart';
import 'package:open_tv/services/live_continuity.dart';

void main() {
  /// A clock that only moves when a test says so.
  var now = DateTime(2026, 1, 1, 12);
  late LiveContinuityGuard guard;

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    guard = LiveContinuityGuard(clock: () => now);
  });

  void elapse(Duration time) => now = now.add(time);

  /// Plays on from [from] in one second steps, as the player reports it.
  Duration playOn(Duration from, {int seconds = 10}) {
    var position = from;
    for (var i = 0; i < seconds; i++) {
      position += const Duration(seconds: 1);
      elapse(const Duration(seconds: 1));
      expect(
        guard.positionChanged(position),
        isNull,
        reason: "playing on at ${position.inSeconds}s",
      );
    }
    return position;
  }

  test('playing on normally is left alone', () {
    playOn(Duration.zero, seconds: 120);
  });

  test('a jump backwards is sent back to where it was', () {
    final before = playOn(Duration.zero, seconds: 60);
    elapse(const Duration(seconds: 1));
    expect(
      guard.positionChanged(before - const Duration(seconds: 24)),
      before,
    );
  });

  test('small steps backwards are not corrected', () {
    final before = playOn(Duration.zero, seconds: 60);
    elapse(const Duration(seconds: 1));
    expect(
      guard.positionChanged(before - const Duration(milliseconds: 800)),
      isNull,
    );
  });

  test('the stream settling after opening is not corrected', () {
    expect(guard.positionChanged(const Duration(seconds: 3)), isNull);
    expect(guard.positionChanged(Duration.zero), isNull);
  });

  test('a correction that holds is forgotten', () {
    final before = playOn(Duration.zero, seconds: 60);
    elapse(const Duration(seconds: 1));
    expect(guard.positionChanged(before - const Duration(seconds: 24)), before);
    // The seek lands and playback carries on, so the next jump is corrected
    // again instead of counting as a second failed attempt.
    elapse(LiveContinuityGuard.quietTime);
    final after = playOn(before, seconds: 30);
    elapse(const Duration(seconds: 1));
    expect(guard.positionChanged(after - const Duration(seconds: 20)), after);
  });

  test('it gives up when the corrections do not hold, and retries later', () {
    final before = playOn(Duration.zero, seconds: 60);
    var corrections = 0;
    // The position keeps coming back behind: the moment is no longer cached.
    for (var i = 0; i < 10; i++) {
      elapse(LiveContinuityGuard.quietTime + const Duration(seconds: 1));
      if (guard.positionChanged(before - const Duration(seconds: 24)) != null) {
        corrections++;
      }
    }
    expect(corrections, LiveContinuityGuard.maxAttempts);

    // After the pause it tries again, so a stream that recovers is not left
    // broken for the rest of the session.
    elapse(LiveContinuityGuard.retryAfter);
    final after = playOn(before, seconds: 10);
    elapse(const Duration(seconds: 1));
    expect(guard.positionChanged(after - const Duration(seconds: 24)), after);
  });

  test('the viewer rewinding is never undone', () {
    final before = playOn(Duration.zero, seconds: 60);
    guard.viewerSeeked();
    expect(
      guard.positionChanged(before - const Duration(minutes: 2)),
      isNull,
    );
    // And playing on from there is normal, not a jump to correct.
    elapse(LiveContinuityGuard.quietTime);
    playOn(before - const Duration(minutes: 2), seconds: 30);
  });

  test('reopening the stream starts over', () {
    playOn(Duration.zero, seconds: 60);
    guard.reset();
    // The new timeline starts from zero and that is not a jump.
    expect(guard.positionChanged(const Duration(seconds: 1)), isNull);
    playOn(const Duration(seconds: 1), seconds: 30);
  });
}
