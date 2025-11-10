import 'package:sample_location_comparision/domain/activity_level.dart';

abstract class MotionRepository {
  // 모션 강도 기반으로 속도 수집
  Stream<double> get motionLevelStream;

  // 현재 추정된 모션 강도
  double get currentMotionLevel;

  // 간단 모션 종류 분류 결과
  ActivityLevel classify(double motionLevel);

  Future<void> start(); //센서 구독 시작
  Future<void> stop();  //센서 구독 중단
}