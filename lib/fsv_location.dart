
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sample_location_comparision/section_widget.dart';

import 'location_guard.dart';

class SampleHomePage extends StatefulWidget {
  const SampleHomePage({super.key});

  @override
  State<SampleHomePage> createState() => _SampleHomePageState();
}

class _SampleHomePageState extends State<SampleHomePage> {
  // 허용 구역 기본값(예: 서울시청)
  final _latCtrl = TextEditingController(text: '37.579569760813015');
  final _lngCtrl = TextEditingController(text: '126.8908091061977');
  final _radCtrl = TextEditingController(text: '600');

  final _log = <String>[];
  EvaluatedPosition? _lastEval;
  GuardResult? _lastDecision;
  double? _lastDistance;

  //지오펜싱 가드
  ReadingGeofenceGuard? _fence;
  bool _fenceRunning = false;

  //메트릭 수집 도우미
  final _metrics = LocationSessionMetrics();

  // TTFF 스트림 -- TTFF이란?
  StreamSubscription<Position>? _firstFixSub;

  void _appendLog(String msg) {
    final ts = DateFormat('HH:mm:ss').format(DateTime.now());
    setState(() => _log.insert(0, '[$ts] $msg'));
  }

  GeoCircle _readAllowedCircle() {
    final lat = double.tryParse(_latCtrl.text.trim()) ?? 0;
    final lng = double.tryParse(_lngCtrl.text.trim()) ?? 0;
    final rad = double.tryParse(_radCtrl.text.trim()) ?? 100;
    return GeoCircle(latitude: lat, longitude: lng, radiusMeters: rad);
  }

  Future<void> _acquireReliablePosition() async {
    final policy = LocationPolicy.docReadingDefault();
    final acquirer = ReliableLocationAcquirer(policy: policy);

    _metrics.reset();
    _appendLog('신뢰 위치 획득 시작');



    //TTFF 측정을 위한 보조 스트림
    final locSettings = _highAccuracySettings();
    _firstFixSub?.cancel();
    _firstFixSub = Geolocator.getPositionStream(locationSettings: locSettings).listen((p) {
      if(_metrics.timeToFirstFix == null) {
        _metrics.markFirstFix();
        _appendLog('첫 샘플 도착(TTFF=${_metrics.timeToFirstFix?.inMilliseconds}ms)');
      }
      _metrics.onSample(p);
    });
    _metrics.start();

    try {
      final eval = await acquirer.getReliablePosition();
      _metrics.markAccepted();


      setState(() => _lastEval = eval);
      _appendLog('채택 위치: (${eval.position.latitude.toStringAsFixed(6)}, ${eval.position.longitude.toStringAsFixed(6)})'
          ' acc=${eval.position.accuracy.toStringAsFixed(1)}m, conf=${eval.confidence.name}, score=${eval.score.toStringAsFixed(2)}');
    } catch(e) {
      _appendLog('신뢰 위치 획득 실패: $e');
    } finally {
      await _firstFixSub?.cancel();
      _firstFixSub = null;
      _appendLog('세션 메트릭: ${_metrics.toMap()}');
      setState(() {});
    }
  }

  Future<void> _checkAccessAndStartFence() async {
    final allowed = _readAllowedCircle();
    final guard = LocationAccessGuard();

    _appendLog('열람 시작 가능 여부 확인 중...');
    try {
      final res = await guard.canStartReading(allowed);
      setState(() => _lastDecision = res);
      _appendLog('판정: ${res.decision} (${res.evaluated?.note ?? ''})');
      if (res.decision == GuardDecision.allow) {
        await _startFence(allowed);
      }
    } catch (e) {
      _appendLog('접근 가드 오류: $e');
    }
  }

  Future<void> _startFence(GeoCircle allowed) async {
    if (_fenceRunning) return;
    _appendLog('지오펜싱 시작: center=(${allowed.latitude}, ${allowed.longitude}), r=${allowed.radiusMeters}m');
    _fence = ReadingGeofenceGuard(
      allowed: allowed,
      onTick: (pos, dist) {
        setState(() => _lastDistance = dist);
      },
    );
    await _fence!.start(onExit: (pos, dist) {
      _appendLog('반경 이탈 감지! dist=${dist.toStringAsFixed(1)}m → 문서 종료');
      _showExitDialog();
    });
    setState(() => _fenceRunning = true);
  }

  Future<void> _stopFence() async {
    if (!_fenceRunning) return;
    await _fence?.stop();
    setState(() => _fenceRunning = false);
    _appendLog('지오펜싱 정지');
  }

  void _showExitDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이탈 감지'),
        content: const Text('허용 반경을 벗어나 문서 열람을 종료합니다.'),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); }, child: const Text('확인')),
        ],
      ),
    );
  }

  LocationSettings _highAccuracySettings() => const LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );

  String _prettyMap(Map<String, Object?> m) => m.entries.map((e) => '${e.key}: ${e.value}').join('');

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radCtrl.dispose();
    _firstFixSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _readAllowedCircle();
    return Scaffold(
      appBar: AppBar(title: const Text('FSV Location Sample'),),
      body: ListView (
        padding: const EdgeInsets.all(16),
        children: [
          Section(
            title: '허용 구역',
            child: Column(
              children: [
                Row(
                    children: [
                      Expanded(child: LabeledField(label: '위도', controller: _latCtrl)),
                      const SizedBox(width: 8),
                      Expanded(child: LabeledField(label: '경도', controller: _lngCtrl)),
                      const SizedBox(width: 8),
                      SizedBox(width: 120, child: LabeledField(label: 'Radius(m)', controller: _radCtrl)),
                      const SizedBox(width: 8),
                      Text('현재 거리: ${_lastDistance == null ? '-' : '${_lastDistance!.toStringAsFixed(1)} m'}'),
                    ]),
                const SizedBox(height: 12),
                Section(
                    title: '액션',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _acquireReliablePosition,
                          icon: const Icon(Icons.gps_fixed), label: const Text('신뢰 위치 획득'),
                        ),
                        FilledButton.icon(
                          onPressed: _checkAccessAndStartFence,
                          icon: const Icon(Icons.play_circle), label: const Text('열람 시작+지오펜싱'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _stopFence,
                          icon: const Icon(Icons.stop_circle_outlined), label: const Text('지오펜싱 정지'),
                        ),
                      ],
                    )
                ),
                const SizedBox(height: 12),
                Section(
                  title: '결과 - 위치 평가(EvaluatedPosition)',
                  child: _lastEval == null
                      ? const Text('아직 없음')
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('lat,lng: ${_lastEval!.position.latitude.toStringAsFixed(6)}, ${_lastEval!.position.longitude.toStringAsFixed(6)}'),
                    Text('accuracy: ${_lastEval!.position.accuracy.toStringAsFixed(1)} m'),
                    Text('timestamp: ${_lastEval!.position.timestamp}'),
                    Text('confidence: ${_lastEval!.confidence.name}'),
                    Text('score: ${_lastEval!.score.toStringAsFixed(2)}'),
                    if (_lastEval!.note != null) Text('note: ${_lastEval!.note}')
                  ]),
                ),
                const SizedBox(height: 12),
                Section(
                    title: '결과 - 접근 판정(GuardResult)',
                    child: _lastDecision == null
                        ? const Text('아직 없음')
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('decision: ${_lastDecision!.decision.name}'),
                        if(_lastDecision!.evaluated != null)
                          Text('evaluated acc: ${_lastDecision!.evaluated!.position.accuracy.toStringAsFixed(1)} m')
                      ],
                    )
                ),
                const SizedBox(height: 12),
                Section(
                  title: '세션 메트릭',
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_prettyMap(_metrics.toMap())),
                  ]),
                ),
                const SizedBox(height: 12),
                Section(
                  title: '로그',
                  child: LogView(lines: _log),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}