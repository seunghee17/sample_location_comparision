import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../data/locator.dart';
import '../domain/location_policy.dart';
import '../domain/repository/location_repository.dart';

class LocationViewModel extends ChangeNotifier {
  final LocationRepository _repo = locator<LocationRepository>();

  bool isRunning = false;
  Position? lastBest;
  String? lastError;

  Future<void> startGlobal() async {
    try {
      await _repo.startGlobalSensing();
      isRunning = true;
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> stopGlobal() async {
    await _repo.stopGlobalSensing();
    isRunning = false;
    notifyListeners();
  }

  Future<void> getBestPosition() async {
    try {
      lastBest = await _repo.getBestPositionWithFallback(LocationPolicy.strict);
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }
}
