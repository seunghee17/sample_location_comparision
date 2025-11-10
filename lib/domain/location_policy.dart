class LocationPolicy {
  final double targetAccuracyMeters; //좋다고 볼 정확도 기준
  final Duration currentTimeout; // 문서 열람 직전
  final Duration cacheWindow; // 캐시 보정시 사용할 최근 윈도우

  const LocationPolicy(
      {this.targetAccuracyMeters = 25.0,
      this.currentTimeout = const Duration(seconds: 2),
      this.cacheWindow = const Duration(seconds: 60)});

  static const strict = LocationPolicy(
    targetAccuracyMeters: 25,
    currentTimeout: Duration(seconds: 2),
    cacheWindow: Duration(seconds: 60),
  );

}
