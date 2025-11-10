import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/src/models/position.dart';
import 'package:sample_location_comparision/data/location_cache_manager.dart';
import 'package:sample_location_comparision/data/weighted_average.dart';
import 'package:sample_location_comparision/domain/activity_level.dart';
import 'package:sample_location_comparision/domain/location_policy.dart';
import 'package:sample_location_comparision/domain/repository/location_repository.dart';
import 'package:sample_location_comparision/domain/repository/motion_repository.dart';

class LocationRepositoryImpl implements LocationRepository {
  final MotionRepository motionRepository;
  LocationRepositoryImpl({required this.motionRepository});

  StreamSubscription<Position>? _posSub;
  StreamSubscription<double>? _motionSub;
  ActivityLevel _level = ActivityLevel.still;
  double _motionLevel = 0.0;

  // 위치 권한 관련 메소드
  Future<void> _ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Location services disabled');
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Location permission denied forever');
    }
  }

  @override
  Future<void> ensureStreamFor(ActivityLevel level) async {
    if(_posSub != null && _level == level) return;
    await _posSub?.cancel();
    _level = level;

    final settings = _settingsFor(level);
    _posSub = Geolocator.getPositionStream(locationSettings: settings).listen((p) {
      if(p==null) return;
      LocationCacheManager.instance.add(p);
    });
  }

  LocationSettings _settingsFor(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.vehicle:
        return const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 2));
      case ActivityLevel.walk:
        return const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 4));
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 8));
    }
  }

  @override
  Future<Position> getBestPositionWithFallback(LocationPolicy policy) async {
    await _ensurePermission();

    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(policy.currentTimeout);
      if(p.accuracy <= policy.targetAccuracyMeters) return p;
    } catch(_) {}

    final samples = LocationCacheManager.instance.recentWithin(policy.cacheWindow);
    if(samples.isNotEmpty) {
      final avg = WeightedAverager().weightedAverage(samples: samples, motionLevel: _motionLevel);
      if(avg != null) return avg;
      return samples.last;
    }

    final last = await Geolocator.getLastKnownPosition();
    if(last != null) return last;

    throw Exception('No location available');
  }

  @override
  Future<void> startGlobalSensing() async {
    await _ensurePermission();
    await motionRepository.start();
    await _motionSub?.cancel();
    
    _motionSub = motionRepository.motionLevelStream.listen((m) async {
      _motionLevel = m;
      await ensureStreamFor(motionRepository.classify(m));
    });
    await ensureStreamFor(ActivityLevel.still);
  }

  @override
  Future<void> stopGlobalSensing() async {
    await _posSub?.cancel();
    await _motionSub?.cancel();
    await motionRepository.stop();
  }
}