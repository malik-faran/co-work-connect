import 'dart:async';

import 'package:geolocator/geolocator.dart';

class UserLocation {
  final double latitude;
  final double longitude;

  /// GPS horizontal accuracy in meters (lower is better). Null if unknown.
  final double? accuracyMeters;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });
}

/// Resolves the user's current GPS location across mobile and web.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const _fixTimeout = Duration(seconds: 15);
  static const _maxStaleAge = Duration(minutes: 10);
  /// Do not trust last-known fixes older than this for map distance.
  static const _maxImmediateLastKnownAge = Duration(minutes: 2);
  static const _goodAccuracyMeters = 30.0;

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  /// Returns current position, or `null` if unavailable or denied.
  Future<UserLocation?> getCurrentLocation() async {
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      final position = await _resolveBestPosition();
      return _fromPosition(position);
    } catch (_) {
      return null;
    }
  }

  UserLocation _fromPosition(Position position) => UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );

  bool _isRecent(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= _maxStaleAge;
  }

  bool _isUsableLastKnown(Position position) =>
      _isRecent(position) && position.accuracy <= 200;

  bool _isFreshEnoughForImmediate(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= _maxImmediateLastKnownAge;
  }

  /// Picks the most accurate fix within [_fixTimeout], falling back to a recent
  /// last-known position only when it is still reasonably fresh.
  Future<Position> _resolveBestPosition() async {
    Position? best;

    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && _isUsableLastKnown(lastKnown)) {
      best = lastKnown;
      if (lastKnown.accuracy <= _goodAccuracyMeters &&
          _isFreshEnoughForImmediate(lastKnown)) {
        return lastKnown;
      }
    }

    try {
      final quick = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      best = _betterOf(best, quick);
      if (quick.accuracy <= _goodAccuracyMeters) {
        return quick;
      }
    } catch (_) {}

    final streamBest = await _bestFromStream(
      initial: best,
      timeout: _fixTimeout,
    );
    if (streamBest != null) return streamBest;

    if (best != null) return best;

    if (lastKnown != null && _isRecent(lastKnown)) {
      return lastKnown;
    }

    throw StateError('Unable to obtain location fix');
  }

  Position? _betterOf(Position? current, Position candidate) {
    if (current == null) return candidate;
    return candidate.accuracy < current.accuracy ? candidate : current;
  }

  Future<Position?> _bestFromStream({
    Position? initial,
    required Duration timeout,
  }) async {
    Position? best = initial;
    final completer = Completer<Position?>();
    StreamSubscription<Position>? subscription;
    Timer? timer;

    void finish() {
      timer?.cancel();
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete(best);
      }
    }

    subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        best = _betterOf(best, position);
        if (position.accuracy <= _goodAccuracyMeters) {
          finish();
        }
      },
      onError: (_) => finish(),
    );

    timer = Timer(timeout, finish);

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await subscription.cancel();
    }
  }
}
