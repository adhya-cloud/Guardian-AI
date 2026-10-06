import 'dart:async';
import 'dart:math' as math;

/// Detects a deliberate, vigorous shake: [requiredShakes] acceleration peaks
/// above [threshold] (m/s², gravity excluded) within [window].
///
/// Pure logic, fed with samples, so it can be unit-tested.  See
/// [ShakeDetector.listen] for wiring it to the accelerometer.
class ShakeDetector {
  ShakeDetector({
    required this.onShake,
    this.threshold = 22,
    this.requiredShakes = 4,
    this.window = const Duration(milliseconds: 1500),
    this.minGap = const Duration(milliseconds: 120),
    this.cooldown = const Duration(seconds: 5),
  });

  final void Function() onShake;
  final double threshold;
  final int requiredShakes;
  final Duration window;
  final Duration minGap;
  final Duration cooldown;

  final _peaks = <DateTime>[];
  DateTime? _lastFired;
  StreamSubscription<void>? _sub;

  /// Feed one user-acceleration sample (x, y, z in m/s²).
  void addSample(double x, double y, double z, DateTime at) {
    if (_lastFired != null && at.difference(_lastFired!) < cooldown) return;
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (magnitude < threshold) return;
    if (_peaks.isNotEmpty && at.difference(_peaks.last) < minGap) return;
    _peaks
      ..add(at)
      ..removeWhere((t) => at.difference(t) > window);
    if (_peaks.length >= requiredShakes) {
      _peaks.clear();
      _lastFired = at;
      onShake();
    }
  }

  /// Subscribes to a stream of (x, y, z) user-acceleration samples.
  void listen(Stream<(double, double, double)> samples) {
    _sub?.cancel();
    _sub = samples.listen((s) => addSample(s.$1, s.$2, s.$3, DateTime.now()));
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _peaks.clear();
  }
}
