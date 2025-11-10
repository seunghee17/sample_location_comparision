import 'package:geolocator/geolocator.dart';

class WeightedAverager {
  Position? weightedAverage({
    required List<Position> samples,
    required double motionLevel,
  }) {
    if(samples.isEmpty) return null;

    double sumLat = 0;
    double sumLng = 0;
    double sumW =0;

    for(final p in samples) {
      final acc = p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : 50.0;
      final wAcc = 1.0/(1.0+acc);
      final wMotion = 1.0 / (1.0+motionLevel);
      final weight = wAcc * wMotion;
      sumLat += p.latitude * weight;
      sumLng += p.longitude * weight;
      sumW += weight;
    }

    if(sumW <=0) return null;

    final avgAcc = samples.map((p) => p.accuracy).reduce((a,b) => a+b);
    final last = samples.last;

    return Position(
      latitude: sumLat / sumW,
      longitude: sumLng / sumW,
      accuracy: avgAcc,
      timestamp: DateTime.now(),
      altitude: last.altitude,
      heading: last.heading,
      speed: last.speed,
      speedAccuracy: last.speedAccuracy,
      altitudeAccuracy: last.altitudeAccuracy,
      headingAccuracy: null, /// TODO 무슨값을 넣어야할까
    );
  }
}
