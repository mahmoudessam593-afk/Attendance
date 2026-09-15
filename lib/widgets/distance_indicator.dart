import 'package:flutter/material.dart';

class DistanceIndicator extends StatelessWidget {
  final double? distance;
  final double radius;
  final double accuracy;
  final bool isWithinRadius;

  const DistanceIndicator({
    super.key,
    this.distance,
    required this.radius,
    required this.accuracy,
    required this.isWithinRadius,
  });

  @override
  Widget build(BuildContext context) {
    final displayDistance = distance ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Distance:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${displayDistance.toStringAsFixed(1)} meters',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isWithinRadius ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Required radius:'),
                Text('${radius.toStringAsFixed(0)}m'),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GPS accuracy:'),
                Text(
                  '${accuracy.toStringAsFixed(1)}m',
                  style: TextStyle(
                    color: accuracy > 25 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (displayDistance / radius).clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                isWithinRadius ? Colors.green : Colors.orange,
              ),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }
}