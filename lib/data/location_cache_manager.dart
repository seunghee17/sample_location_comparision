import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

class LocationCacheManager {
  static final LocationCacheManager instance = LocationCacheManager._();
  LocationCacheManager._();

  final List<Position> _cache = [];

  void add(Position p) {
    _cache.add(p);
    //오래된 10분 초과 샘플제거
    final now = DateTime.now();
    _cache.removeWhere((e) {
      final ts = e.timestamp;
      return now.difference(ts) > const Duration(minutes: 10);
    });

    // 최대 500개 유지
    const maxKeep = 500;
    if(_cache.length > maxKeep) {
      _cache.removeRange(0, _cache.length - maxKeep);
    }
  }

  List<Position> recentWithin(Duration window) {
    final now = DateTime.now();
    return _cache.where((e) {
      final ts = e.timestamp;
      return now.difference(ts) <= window;
    }).toList();
  }

  void clear() => _cache.clear();
}