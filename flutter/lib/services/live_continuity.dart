/// Undoes the jumps backwards of a live channel.
///
/// The servers these channels come from drop the connection every minute or
/// so. When the player reconnects, the server does not continue where it left
/// off: it starts sending again from the beginning of its own buffer, so
/// around twenty seconds that were already watched arrive with older
/// timestamps and the picture goes back several seconds. Measured on one
/// channel: 17 reconnections in 15 minutes, each one between 18 and 38 seconds
/// behind, which is what makes watching live uncomfortable.
///
/// Everything received so far is still in the player's cache, so the jump is
/// undone by seeking back to the moment that was playing. Playback then
/// carries on from there and runs into the data that just arrived.
///
/// Positions are fed in as they come from the player; the result is the moment
/// to seek to, or null when there is nothing to correct.
class LiveContinuityGuard {
  /// Smaller steps backwards are jitter in the reported position, not a jump.
  static const minJump = Duration(seconds: 2);

  /// Right after opening, the position is still settling.
  static const warmUp = Duration(seconds: 5);

  /// A seek moves the position on its own, so detection pauses for a moment
  /// after correcting or after the viewer seeks.
  static const quietTime = Duration(seconds: 3);

  /// Corrections in a row that do not hold before giving up: if the moment is
  /// no longer in the cache, insisting would make the picture jump even more.
  static const maxAttempts = 3;

  /// How long to leave the stream alone after giving up.
  static const retryAfter = Duration(minutes: 1);

  final DateTime Function() _now;

  LiveContinuityGuard({DateTime Function()? clock}) : _now = clock ?? DateTime.now;

  Duration _position = Duration.zero;
  DateTime? _ignoreUntil;
  DateTime? _retryAt;
  int _attempts = 0;

  /// Call when the viewer seeks, rewinds or jumps to the live edge: their own
  /// jumps are theirs to keep.
  void viewerSeeked() => _ignoreUntil = _now().add(quietTime);

  /// Call when the stream is (re)opened: the new timeline has nothing to do
  /// with the position of the previous one.
  void reset() {
    _position = Duration.zero;
    _ignoreUntil = null;
    _retryAt = null;
    _attempts = 0;
  }

  /// The moment to seek back to, or null if the position is fine.
  Duration? positionChanged(Duration position) {
    final now = _now();
    final previous = _position;
    _position = position;

    // Settling after a seek, or the stream has just been opened.
    if (_ignoreUntil != null && now.isBefore(_ignoreUntil!)) return null;
    if (previous < warmUp) return null;

    // Playing on normally: whatever went wrong before is over.
    if (position > previous - minJump) {
      _attempts = 0;
      return null;
    }

    // Gave up on this stream for the time being.
    if (_retryAt != null && now.isBefore(_retryAt!)) return null;

    _ignoreUntil = now.add(quietTime);
    _attempts++;
    if (_attempts > maxAttempts) {
      _attempts = 0;
      _retryAt = now.add(retryAfter);
      return null;
    }

    // Aim for where playback was, and keep that as the reference so a
    // correction that does not hold is noticed on the next position.
    _position = previous;
    return previous;
  }
}
