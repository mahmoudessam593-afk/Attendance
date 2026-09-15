import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_key_service.dart';
import '../../services/device_service.dart';
import '../home/home_screen.dart';

class OTPScreen extends StatefulWidget {
  final String employeeCode;
  final String mobileNumber;
  final int expiresInSeconds;

  const OTPScreen({
    super.key,
    required this.employeeCode,
    required this.mobileNumber,
    this.expiresInSeconds = 300,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  bool _isLoading = false;
  String? _error;
  bool _resending = false;

  late AuthService _authService;
  late BiometricKeyService _biometricKeyService;

  Timer? _countdownTimer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(_apiService.client);
    _biometricKeyService = BiometricKeyService(_apiService.client);
    _secondsRemaining = widget.expiresInSeconds;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        setState(() => _secondsRemaining = 0);
        timer.cancel();
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _formattedCountdown {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get _isExpired => _secondsRemaining <= 0;

  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _error = 'Please enter a 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final deviceId = await _deviceService.getDeviceId();
      final deviceName = await _deviceService.getDeviceName();
      final response = await _authService.verifyOTP(
        employeeCode: widget.employeeCode,
        mobileNumber: widget.mobileNumber,
        otp: _otpController.text.trim(),
        deviceId: deviceId,
        platform: _deviceService.platformName,
        deviceName: deviceName,
      );

      if (response['success'] == true) {
        try {
          await _biometricKeyService.ensureKeyRegistered(deviceId);
        } catch (_) {
          // Non-fatal here: home_screen retries this before every check-in,
          // so a failure now (e.g. no biometrics enrolled yet) just delays
          // setup rather than blocking login.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric setup incomplete - you\'ll be asked again before your first check-in.'),
              ),
            );
          }
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _error = response['error'] ?? 'Verification failed';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _resending = true);
    try {
      final response = await _authService.requestOTP(
        employeeCode: widget.employeeCode,
        mobileNumber: widget.mobileNumber,
      );
      if (response['success'] == true) {
        final expiresInSeconds = (response['data']?['expires_in_seconds'] as num?)?.toInt() ?? 300;
        setState(() {
          _secondsRemaining = expiresInSeconds;
          _error = null;
        });
        _startCountdown();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to resend OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Verification'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.lock, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'OTP sent to ${widget.mobileNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _isExpired ? 'OTP expired - tap Resend OTP' : 'Expires in $_formattedCountdown',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _isExpired ? Colors.red : Colors.grey[600],
                fontWeight: _isExpired ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: (_isLoading || _isExpired) ? null : _verifyOTP,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify OTP', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resending ? null : _resendOTP,
              child: const Text('Resend OTP'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }
}