import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_key_service.dart';
import '../../services/device_service.dart';
import '../home/home_screen.dart';

/// Password-based login, an alternative to the OTP flow for accounts that
/// already have a password set (e.g. provisioned directly by an admin).
/// Since this path doesn't register a device as a side effect the way OTP
/// verification does, it explicitly registers this device right after login.
class PasswordLoginScreen extends StatefulWidget {
  const PasswordLoginScreen({super.key});

  @override
  State<PasswordLoginScreen> createState() => _PasswordLoginScreenState();
}

class _PasswordLoginScreenState extends State<PasswordLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  final DeviceService _deviceService = DeviceService();
  bool _isLoading = false;
  String? _error;

  late final AuthService _authService = AuthService(_apiService.client);

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _authService.loginWithPassword(
        employeeCode: _employeeCodeController.text.trim(),
        password: _passwordController.text,
      );

      if (response['success'] != true) {
        setState(() => _error = response['error'] ?? 'Login failed');
        return;
      }

      final deviceId = await _deviceService.getDeviceId();
      final deviceName = await _deviceService.getDeviceName();
      final deviceResponse = await _authService.registerDevice(
        deviceId: deviceId,
        platform: _deviceService.platformName,
        deviceName: deviceName,
      );

      if (deviceResponse['success'] != true) {
        setState(() => _error = deviceResponse['error'] ?? 'Device registration failed');
        return;
      }

      try {
        await BiometricKeyService(_apiService.client).ensureKeyRegistered(deviceId);
      } catch (_) {
        // Non-fatal: home_screen retries this before every check-in.
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Login'),
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
              Image.asset('assets/egypt_gas_icon_mark.png', height: 90),
              const SizedBox(height: 24),
              TextFormField(
                controller: _employeeCodeController,
                decoration: const InputDecoration(
                  labelText: 'Employee Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter your employee code' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.password),
                ),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter your password' : null,
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
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
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
    _passwordController.dispose();
    super.dispose();
  }
}
