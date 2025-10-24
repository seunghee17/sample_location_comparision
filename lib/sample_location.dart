import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';

class SampleLocationPage extends StatefulWidget {
  const SampleLocationPage({super.key});
  
  @override
  State<StatefulWidget> createState() => _SampleLocationPageState();
  
}

class _SampleLocationPageState extends State<SampleLocationPage> {
  final Location location = Location();
  DateTime? _lastUpdateTime;
  LocationData? _currentLocation;

  Future<void> getLocation() async {
    bool serviceEnabled = await location.serviceEnabled();
    if(!serviceEnabled) {
      await location.requestService();
    }
    await collectLocation();
  }

  Future<void> collectLocation() async {
    location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000, // 1초 단위 체크
    );

    location.onLocationChanged.listen((LocationData newLocation) {
      final now = DateTime.now();

      // 응답 지연 계산
      if (_lastUpdateTime != null) {
        final delay = now.difference(_lastUpdateTime!).inMilliseconds;
        developer.log('⏱️ 위치 응답 지연: ${delay}ms');
      }

      setState(() {
        _currentLocation = newLocation;
        _lastUpdateTime = now;
      });

      developer.log(
        "📍 lat=${newLocation.latitude}, lon=${newLocation.longitude}, time=$now",
        name: 'LocationUpdate',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FSV Location Sample'),),
      body: Column(
        children: [
          FilledButton.icon(
            onPressed: () async {
              await getLocation();
            },
            icon: const Icon(Icons.gps_fixed), label: const Text('신뢰 위치 획득'),
          ),
          SizedBox(
            width: 20,
            height: 20,
            child: Text('dododo'),
          )
        ],
      )
    );
  }
  
}