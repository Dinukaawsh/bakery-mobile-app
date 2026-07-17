import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

const _prefsKey = 'delivery_location_tracking';

/// Sends GPS updates to the API while the delivery partner has sharing on.
class LocationTrackingService {
  LocationTrackingService(this._api);

  final ApiService _api;
  Timer? _timer;
  bool _running = false;
  bool _posting = false;

  bool get isRunning => _running;

  Future<bool> restoreIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsKey) != true) return false;
    return start();
  }

  Future<bool> start() async {
    final permission = await _ensurePermission();
    if (!permission) return false;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('LOCATION_DISABLED');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);

    _running = true;
    await _sendOnce();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 40), (_) {
      unawaited(_sendOnce());
    });
    return true;
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _running = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
    try {
      await _api.stopLocationTracking();
    } catch (_) {
      // Best-effort; local stop still applies.
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> _sendOnce() async {
    if (!_running || _posting) return;
    _posting = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _api.postLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      // Keep timer alive; next tick may succeed.
    } finally {
      _posting = false;
    }
  }
}
