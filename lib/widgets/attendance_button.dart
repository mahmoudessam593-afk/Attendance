import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AttendanceButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;
  final String label;

  const AttendanceButton({
    super.key,
    required this.isEnabled,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.brandGreen : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}