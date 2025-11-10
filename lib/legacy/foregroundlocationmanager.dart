import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

class ForegroundLocationManager with WidgetsBindingObserver {
  StreamSubscription<Position>? _sub;
  Position? _cached;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startWarmup();
    } else if (state == AppLifecycleState.paused) {
      _stop();
    }
  }

  Future<void> _startWarmup() async {
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // 초기엔 높은 정확도
      distanceFilter: 0,
    );

    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      _cached = pos; // 캐시 업데이트
      debugPrint('[Warmup] ${pos.latitude}, ${pos.longitude}, acc=${pos.accuracy}');
    });
  }

  Position? get cached => _cached;

  void _stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  // Future<void> startReading() async {
  //   final cached = locationManager.cached;
  //   if (cached != null) {
  //     // 🔹 캐시된 최근 위치를 우선 사용해 빠르게 표시
  //     useLocation(cached);
  //   }
  //
  //   // 🔹 이후 ReliableLocationAcquirer 로 보정 위치 수집
  //   final eval = await ReliableLocationAcquirer().getReliablePosition();
  //   useLocation(eval.position);
  // }
}
