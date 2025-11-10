import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sample_location_comparision/domain/activity_level.dart';
import 'package:sample_location_comparision/domain/repository/motion_repository.dart';
import 'dart:math' as math;

class MotionRepositoryImpl implements MotionRepository {
  StreamSubscription<AccelerometerEvent>? _sub;
  final _ctrl = StreamController<double>.broadcast();
  double _ema = 0.0;
  final double _alpha = 0.2; //지수 평활 계수

  @override
  Stream<double> get motionLevelStream => _ctrl.stream;

  @override
  double get currentMotionLevel => _ema;

  @override
  ActivityLevel classify(double m) {
    if(m >= 2.0) return ActivityLevel.vehicle;
    if(m >= 0.5) return ActivityLevel.walk;
    return ActivityLevel.still;
  }

 /// TODO start의 구체적 의미
  @override
  Future<void> start() async {
    await _sub?.cancel();
    _sub = accelerometerEvents.listen((e) {
      final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final delta = (magnitude - 9.8).abs();
      _ema = _alpha * delta + (1-_alpha) * _ema;
      _ctrl.add(_ema);
    });
  }

  @override
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }


}