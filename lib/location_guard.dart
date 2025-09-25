
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';

// -----------------------------
// 모델 & 정책
// -----------------------------

class GeoCircle {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  const GeoCircle({required this.latitude, required this.longitude, required this.radiusMeters});
}

enum LocationConfidence { good, borderline, bad, spoofed } // 채취한 샘플의 품질 등급

enum GuardDecision { allow, rejectNeedFreshSample, rejectPolicy, rejectSpoofed } // 열람전 판정 결과
/// 정확도·신선도 기준, 워밍업 샘플/타임아웃 등 튜닝 포인트
// 워밍업 수집: getCurrentPosition으로 한방에 수집되길 바라는 것이 아닌 아주 짧은 시간동안 getPositionStream

class LocationPolicy { // -- 정책임 (설정값)
  // 허용 기준 (조정 가능)
  final double targetAccuracyMeters; // 수평 정확도 기준 (예: 25m)
  final Duration maxAge; // 위치 timestamp 신선도 (예: 5s)
  final double maxSpeedAccuracy; // 속도 정확도 허용치(없으면 무시) (예: 1.5 m/s)
  final bool rejectMock; // 모의 위치 거부
  final int minGoodSamples; // 워밍업 중 good 샘플 몇 개 모아야 수락할지
  final int maxWarmupSamples; // 워밍업 샘플 최대 수
  final Duration warmupTimeout; // 워밍업 타임아웃
  final Duration timeLimitForCurrent; // getCurrentPosition 타임리밋
  final bool useLastKnownAsLastResort; // 최후의 수단으로만 lastKnown 사용
  final double jitterRejectMultiplier; // outlier 판정 (acc * k 배 이상 튀면 제거) 이상치 제거의 역할

  const LocationPolicy({
    this.targetAccuracyMeters = 25.0,
    this.maxAge = const Duration(seconds: 5),
    this.maxSpeedAccuracy = 2.0,
    this.rejectMock = true,
    this.minGoodSamples = 1,
    this.maxWarmupSamples = 8,
    this.warmupTimeout = const Duration(seconds: 10),
    this.timeLimitForCurrent = const Duration(seconds: 5),
    this.useLastKnownAsLastResort = false,
    this.jitterRejectMultiplier = 2.5,
  });

  LocationPolicy copyWith({
    double? targetAccuracyMeters,
    Duration? maxAge,
    double? maxSpeedAccuracy,
    bool? rejectMock,
    int? minGoodSamples,
    int? maxWarmupSamples,
    Duration? warmupTimeout,
    Duration? timeLimitForCurrent,
    bool? useLastKnownAsLastResort,
    double? jitterRejectMultiplier,
  }) => LocationPolicy(
    targetAccuracyMeters: targetAccuracyMeters ?? this.targetAccuracyMeters,
    maxAge: maxAge ?? this.maxAge,
    maxSpeedAccuracy: maxSpeedAccuracy ?? this.maxSpeedAccuracy,
    rejectMock: rejectMock ?? this.rejectMock,
    minGoodSamples: minGoodSamples ?? this.minGoodSamples,
    maxWarmupSamples: maxWarmupSamples ?? this.maxWarmupSamples,
    warmupTimeout: warmupTimeout ?? this.warmupTimeout,
    timeLimitForCurrent: timeLimitForCurrent ?? this.timeLimitForCurrent,
    useLastKnownAsLastResort: useLastKnownAsLastResort ?? this.useLastKnownAsLastResort,
    jitterRejectMultiplier: jitterRejectMultiplier ?? this.jitterRejectMultiplier,
  );

  // 문서 열람 시 기본 정책 (실내/사무실 기준) 비교적 엄격
  static LocationPolicy docReadingDefault() => const LocationPolicy(
    targetAccuracyMeters: 25,
    maxAge: Duration(seconds: 5),
    maxSpeedAccuracy: 2.0,
    rejectMock: true,
    minGoodSamples: 1,
    maxWarmupSamples: 8,
    warmupTimeout: Duration(seconds: 10),
    timeLimitForCurrent: Duration(seconds: 5),
    useLastKnownAsLastResort: false,
    jitterRejectMultiplier: 2.5,
  );

  // 야외/대형 반경
  static LocationPolicy outdoorLoose() => const LocationPolicy(
    targetAccuracyMeters: 50,
    maxAge: Duration(seconds: 8),
    maxSpeedAccuracy: 3.0,
    minGoodSamples: 1,
    maxWarmupSamples: 6,
    warmupTimeout: Duration(seconds: 8),
  );
}

class EvaluatedPosition {
  final Position position;
  final LocationConfidence confidence;
  final double score; // 0.0 ~ 1.0 (높을수록 신뢰도 높음)
  final String? note; // 판정 사유
  EvaluatedPosition(this.position, this.confidence, this.score, {this.note});
}

class GuardResult {
  final GuardDecision decision;
  final EvaluatedPosition? evaluated;
  const GuardResult(this.decision, {this.evaluated});
}

// -----------------------------
// 위치 신뢰도 평가기: 정확도 신선도 기준 워밍업 샘플/타임아웃등 튜닝 포인트
// -----------------------------

class LocationValidator {
  EvaluatedPosition evaluate(Position p, LocationPolicy policy) {
    // Mock 위치 거부
    if ((policy.rejectMock) && (p.isMocked == true)) {
      return EvaluatedPosition(p, LocationConfidence.spoofed, 0.0, note: 'Mock location detected');
    }

    final now = DateTime.now();
    final age = p.timestamp == null ? const Duration(days: 9999) : now.difference(p.timestamp!);

    final acc = (p.accuracy.isFinite && p.accuracy > 0) ? p.accuracy : double.infinity;
    final spdAcc = (p.speedAccuracy.isFinite && p.speedAccuracy >= 0) ? p.speedAccuracy : double.nan;

    final ageScore = _expDecay(age, policy.maxAge);
    final accScore = _clamp01(1.0 - (acc / policy.targetAccuracyMeters));
    final spdScore = spdAcc.isNaN ? 1.0 : _clamp01(1.0 - (spdAcc / policy.maxSpeedAccuracy));

    final score = math.pow(ageScore * accScore * spdScore, 1 / 1).toDouble(); // 기하평균 대신 단순 곱

    // 등급 판정
    final conf = (acc <= policy.targetAccuracyMeters && age <= policy.maxAge)
        ? LocationConfidence.good
        : (acc <= policy.targetAccuracyMeters * 1.5 && age <= policy.maxAge * 2)
        ? LocationConfidence.borderline
        : LocationConfidence.bad;

    return EvaluatedPosition(
      p,
      conf,
      _clamp01(score),
      note: 'acc=${acc.toStringAsFixed(1)}m, age=${age.inMilliseconds}ms, spdAcc=${spdAcc.isNaN ? 'n/a' : spdAcc.toStringAsFixed(2)}',
    );
  }

  double _expDecay(Duration age, Duration maxAge) {
    if (age <= Duration.zero) return 1.0;
    final t = age.inMilliseconds / maxAge.inMilliseconds;
    return math.exp(-t); // 나이 들수록 감소
  }

  double _clamp01(double v) => v.isFinite ? v.clamp(0.0, 1.0) as double : 0.0;
}

// -----------------------------
// 위치 획득기 (워밍업 + 품질 평가 + 폴백) -> 빠른 시도+워밍업 수집+스코어링으로 최고 품질의 위치 좌표 1개 선택
// -----------------------------

class ReliableLocationAcquirer {
  ReliableLocationAcquirer({LocationPolicy? policy}) : policy = policy ?? LocationPolicy.docReadingDefault();

  final LocationPolicy policy;
  final LocationValidator _validator = LocationValidator();

  Future<void> _ensureServiceAndPermission({bool request = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && request) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    // iOS 14+ 정밀도 확인 (가능하면 정밀도로 전환)
    try {
      final status = await Geolocator.getLocationAccuracy();
      if (status == LocationAccuracyStatus.reduced) {
        // Info.plist에 NSLocationTemporaryUsageDescriptionDictionary 및 PurposeKey 세팅 필요
        await Geolocator.requestTemporaryFullAccuracy(purposeKey: 'PreciseLocation_Viewer');
      }
    } catch (_) {}
  }

  LocationSettings _highAccuracySettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0, // 가능한 한 잦은 업데이트로 워밍업
        intervalDuration: const Duration(seconds: 1),
        // forceLocationManager: false, // 기본(Fused)
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.otherNavigation,
        showBackgroundLocationIndicator: false,
      );
    } else {
      return const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0);
    }
  }

  /// 캐시/구버전 위치를 피하고 신뢰 가능한 위치를 반환.
  /// 실패 시 예외 발생.
  Future<EvaluatedPosition> getReliablePosition() async {
    await _ensureServiceAndPermission();

    final settings = _highAccuracySettings();

    // 1) 즉시 측정 시도
    Position? first;
    try {
      first = await Geolocator.getCurrentPosition(locationSettings: settings).timeout(policy.timeLimitForCurrent);
    } catch (_) {}

    if (first != null) {
      final e = _validator.evaluate(first, policy);
      if (e.confidence == LocationConfidence.good) {
        return e;
      }
    }

    // 2) 워밍업 스트림 수집 & 최적 샘플 선택
    final samples = <Position>[];
    final sub = Geolocator.getPositionStream(locationSettings: settings).listen((p) {
      if (p == null) return;
      // outlier (정확도 대비 과도한 이동) 제거 옵션은 pick 단계에서 처리
      samples.add(p);
    });

    final sw = Stopwatch()..start();
    while (sw.elapsed < policy.warmupTimeout && samples.length < policy.maxWarmupSamples) {
      await Future.delayed(const Duration(milliseconds: 400));
      final best = _pickBest(samples);
      if (best != null && best.confidence == LocationConfidence.good && samples.length >= policy.minGoodSamples) {
        await sub.cancel();
        return best;
      }
    }
    await sub.cancel();

    // 3) 최종 베스트
    final best = _pickBest(samples);
    if (best != null) return best;

    // 4) 마지막 수단: lastKnown (정책 허용 시)
    if (policy.useLastKnownAsLastResort) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final e = _validator.evaluate(last, policy.copyWith(maxAge: const Duration(seconds: 30)));
        if (e.confidence != LocationConfidence.spoofed) return e;
      }
    }

    throw StateError('Failed to acquire a reliable location');
  }

  EvaluatedPosition? _pickBest(List<Position> samples) {
    if (samples.isEmpty) return null;

    // 1) 최신 순으로 정렬 후, outlier 제거 (이전 샘플 대비 과도한 점프)
    final sorted = [...samples]..sort((a, b) => (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)));

    final filtered = <Position>[];
    for (final p in sorted) {
      if (filtered.isEmpty) {
        filtered.add(p);
        continue;
      }
      final prev = filtered.last;
      final dist = Geolocator.distanceBetween(p.latitude, p.longitude, prev.latitude, prev.longitude);
      final thr = ((p.accuracy.isFinite ? p.accuracy : 50.0) + (prev.accuracy.isFinite ? prev.accuracy : 50.0)) * 0.5 *
          policy.jitterRejectMultiplier;
      if (dist <= thr) {
        filtered.add(p);
      }
      // else drop as outlier
    }

    // 2) 스코어가 가장 높은 샘플 선택
    EvaluatedPosition? best;
    for (final p in filtered) {
      final e = _validator.evaluate(p, policy);
      if (best == null || e.score > best.score) best = e;
    }
    return best;
  }
}

// -----------------------------
// 문서 열람 전 가드 (영역 진입 판단)
// -----------------------------

class LocationAccessGuard {
  LocationAccessGuard({LocationPolicy? policy}) : policy = policy ?? LocationPolicy.docReadingDefault();
  final LocationPolicy policy;
  final ReliableLocationAcquirer _acquirer = ReliableLocationAcquirer();

  Future<GuardResult> canStartReading(GeoCircle allowed) async {
    final eval = await _acquirer.getReliablePosition();
    if (eval.confidence == LocationConfidence.spoofed) {
      return GuardResult(GuardDecision.rejectSpoofed, evaluated: eval);
    }
    final inside = _isInside(eval.position, allowed);
    if (!inside) {
      // 정책 충족했으나 영역 외부
      return GuardResult(GuardDecision.rejectPolicy, evaluated: eval);
    }
    return GuardResult(GuardDecision.allow, evaluated: eval);
  }

  bool _isInside(Position pos, GeoCircle c) {
    final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, c.latitude, c.longitude);
    return d <= c.radiusMeters;
  }
}

// -----------------------------
// 문서 열람 중 지오펜싱 가드 (반경 이탈 시 즉시 종료 콜백)
// -----------------------------

class ReadingGeofenceGuard {
  final GeoCircle allowed;
  final LocationPolicy policy;
  final void Function(Position current, double distanceMeters)? onTick; // UI 갱신용
  StreamSubscription<Position>? _sub;
  final LocationValidator _validator = LocationValidator();

  ReadingGeofenceGuard({required this.allowed, LocationPolicy? policy, this.onTick})
      : policy = policy ?? LocationPolicy.docReadingDefault();

  Future<void> start({required void Function(Position current, double distanceMeters) onExit}) async {
    // 권한/서비스 확인 (예외 throw)
    final acquirer = ReliableLocationAcquirer(policy: policy);
    await acquirer._ensureServiceAndPermission();

    final settings = _streamSettingsForReading();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen((p) {
      if (p == null) return;
      final e = _validator.evaluate(p, policy);
      if (e.confidence == LocationConfidence.bad || e.confidence == LocationConfidence.spoofed) return; // 품질 낮음 무시
      final dist = Geolocator.distanceBetween(p.latitude, p.longitude, allowed.latitude, allowed.longitude);
      onTick?.call(p, dist);
      if (dist > allowed.radiusMeters) {
        onExit(p, dist); // 즉시 종료 처리 (문서 뷰어 닫기 등)
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  LocationSettings _streamSettingsForReading() {
    // 배터리/정확도 균형: 반경의 1/10 또는 5m 중 큰 값으로 distanceFilter 설정
    final df = math.max(5.0, allowed.radiusMeters * 0.1);
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: df.round(),
        intervalDuration: const Duration(seconds: 2),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: df.round(),
        pauseLocationUpdatesAutomatically: true,
        activityType: ActivityType.other,
      );
    } else {
      return LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: df.round());
    }
  }
}

// -----------------------------
// 성과 측정 (전환 전/후 비교용 메트릭 수집) / TTFF/정확도 등 지표 수집
// -----------------------------

class LocationSessionMetrics {
  final Stopwatch _sw = Stopwatch();
  Duration? timeToFirstFix; // TTFF (getCurrentPosition 또는 첫 스트림 샘플 도달 시간)
  Duration? timeToAccept; // 정책을 만족하는 위치를 채택하기까지 걸린 시간
  final List<double> accuracies = [];
  final List<int> agesMs = [];
  int sampleCount = 0;

  void reset() {
    _sw.reset();
    timeToFirstFix = null;
    timeToAccept = null;
    accuracies.clear();
    agesMs.clear();
    sampleCount = 0;
  }

  void start() => _sw.start();
  void markFirstFix() => timeToFirstFix ??= _sw.elapsed;
  void onSample(Position p) {
    sampleCount += 1;
    if (p.accuracy.isFinite) accuracies.add(p.accuracy);
    final ageMs = p.timestamp == null ? 999999 : DateTime.now().difference(p.timestamp!).inMilliseconds;
    agesMs.add(ageMs);
  }
  void markAccepted() => timeToAccept ??= _sw.elapsed;

  Map<String, Object?> toMap() => {
    'ttff_ms': timeToFirstFix?.inMilliseconds,
    't_accept_ms': timeToAccept?.inMilliseconds,
    'sample_count': sampleCount,
    'acc_med_m': _median(accuracies),
    'acc_p95_m': _percentile(accuracies, 95),
    'age_med_ms': _medianInt(agesMs),
  };

  double? _median(List<double> v) {
    if (v.isEmpty) return null;
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
  }

  int? _medianInt(List<int> v) {
    if (v.isEmpty) return null;
    final s = [...v]..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : ((s[mid - 1] + s[mid]) ~/ 2);
  }

  double? _percentile(List<double> v, int p) {
    if (v.isEmpty) return null;
    final s = [...v]..sort();
    final idx = ((p / 100) * (s.length - 1)).clamp(0, s.length - 1);
    return s[idx.roundToDouble().toInt()];
  }
}

// 간단한 사용 예 (문서 열람 플로우)
/*
final allowed = GeoCircle(latitude: 37.5665, longitude: 126.9780, radiusMeters: 120); // 예: 사무실 반경 120m
final accessGuard = LocationAccessGuard();
final res = await accessGuard.canStartReading(allowed);
switch (res.decision) {
  case GuardDecision.allow:
    // 열람 시작
    final fence = ReadingGeofenceGuard(allowed: allowed, onTick: (pos, d) {
      // UI에 남은 거리 표시 등
    });
    await fence.start(onExit: (pos, d) {
      // 문서 뷰어 종료 처리
    });
    // ... 문서 뷰어 dispose 시 fence.stop()
    break;
  case GuardDecision.rejectSpoofed:
    // 모의 위치 감지 안내
    break;
  case GuardDecision.rejectPolicy:
    // 지정 구역 외부 안내
    break;
  case GuardDecision.rejectNeedFreshSample:
    // 추가 측정 유도 (현 구현에서는 사용하지 않음)
    break;
}
*/
