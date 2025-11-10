import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import 'location_viewmodel.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationViewModel(),
      child: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LocationViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('FSV Reliable Location Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: vm.isRunning ? null : vm.startGlobal,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('전역 수집 시작'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.isRunning ? vm.stopGlobal : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('중지'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: vm.getBestPosition,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('열람용 위치 측정'),
            ),
            const SizedBox(height: 12),
            if (vm.lastBest != null) _ResultCard(p: vm.lastBest!),
            if (vm.lastError != null)
              Text('Error: ${vm.lastError}', style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Position p;
  const _ResultCard({required this.p});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Text('열람용 위치 결과'),
        subtitle: Text(
          '위도: ${p.latitude.toStringAsFixed(6)}\n'
              '경도: ${p.longitude.toStringAsFixed(6)}\n'
              '정확도: ${p.accuracy.toStringAsFixed(1)}m\n'
              '시간: ${p.timestamp}',
        ),
      ),
    );
  }
}
