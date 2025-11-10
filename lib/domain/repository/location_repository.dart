import 'package:geolocator/geolocator.dart';
import 'package:sample_location_comparision/domain/location_policy.dart';

import '../activity_level.dart';

abstract class LocationRepository {
  // 포그라운드 전역 수집 시작 (모션 수준에 맞춰 스트림 주기 자동 조절)
  Future<void> startGlobalSensing();

  // 전역 수집 중단
  Future<void> stopGlobalSensing();

  // 내부 스트림이 사용하는 설정을 모션 상태에 맞게 갱신
  Future<void> ensureStreamFor(ActivityLevel level);

  // 문서 열람 직전
// - bestForNavigation으로 2초 내 측정 성공 & 정확도 만족 -> 즉시 반환
// - 실패시 캐시(최근 60초)의 좌표들을 정확도+모션 가중 평균으로 보정하여 반환
  Future<Position> getBestPositionWithFallback(LocationPolicy policy);
}