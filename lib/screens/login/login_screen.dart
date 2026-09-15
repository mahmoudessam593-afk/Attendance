import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_key_service.dart';
import '../../services/device_service.dart';
import '../home/home_screen.dart';
import '../otp/otp_screen.dart';
import 'password_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeCodeController = TextEditingController();
  final _mobileController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  bool _isLoading = false;
  String? _error;
  String? _deviceId;
  bool _biometricLoginAvailable = false;

  late AuthService _authService;
  late BiometricKeyService _biometricKeyService;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(_apiService.client);
    _biometricKeyService = BiometricKeyService(_apiService.client);
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final deviceId = await _deviceService.getDeviceId();
    final available = await _biometricKeyService.hasRegisteredKey(deviceId);
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
        _biometricLoginAvailable = available;
      });
    }
  }

  Future<void> _loginWithBiometric() async {
    if (_deviceId == null) return;
    final employeeCode = _employeeCodeController.text.trim();
    if (employeeCode.isEmpty) {
      setState(() => _error = 'Enter your employee code first');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final proof = await _biometricKeyService.signLogin(
        deviceId: _deviceId!,
        employeeCode: employeeCode,
      );
      final response = await _authService.loginBiometric(
        employeeCode: employeeCode,
        deviceId: _deviceId!,
        signature: proof.signature,
        signedAt: proof.signedAt,
      );

      if (response['success'] == true) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() => _error = response['error'] ?? 'Biometric login failed');
      }
    } catch (e) {
      setState(() => _error = 'Biometric authentication failed. Try OTP or password login instead.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _authService.requestOTP(
        employeeCode: _employeeCodeController.text.trim(),
        mobileNumber: _mobileController.text.trim(),
      );

      if (response['success'] == true) {
        final expiresInSeconds = (response['data']?['expires_in_seconds'] as num?)?.toInt() ?? 300;
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OTPScreen(
                employeeCode: _employeeCodeController.text.trim(),
                mobileNumber: _mobileController.text.trim(),
                expiresInSeconds: expiresInSeconds,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _error = response['error'] ?? 'Failed to send OTP';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/egypt_gas_logo.png', height: 110),
              const SizedBox(height: 16),
              const Text(
                'Attendance System',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _employeeCodeController,
                decoration: const InputDecoration(
                  labelText: 'Employee Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your employee code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your mobile number';
                  }
                  return null;
                },
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
                  onPressed: _isLoading ? null : _requestOTP,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Request OTP', style: TextStyle(fontSize: 16)),
                ),
              ),
              if (_biometricLoginAvailable) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Login with fingerprint', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PasswordLoginScreen()),
                        ),
                child: const Text('Login with password instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _employeeCodeController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}