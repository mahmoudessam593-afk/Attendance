import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService(this._dio);

  Future<Map<String, dynamic>> requestOTP({
    required String employeeCode,
    required String mobileNumber,
  }) async {
    final response = await _dio.post('/auth/request-otp', data: {
      'employee_code': employeeCode,
      'mobile_number': mobileNumber,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> verifyOTP({
    required String employeeCode,
    required String mobileNumber,
    required String otp,
    required String deviceId,
    String? platform,
    String? deviceName,
  }) async {
    final response = await _dio.post('/auth/verify-otp', data: {
      'employee_code': employeeCode,
      'mobile_number': mobileNumber,
      'otp': otp,
      'device_id': deviceId,
      if (platform != null) 'platform': platform,
      if (deviceName != null) 'device_name': deviceName,
    });
    if (response.data['success'] == true) {
      await _storage.write(
          key: 'auth_token', value: response.data['data']['token']);
      await _storage.write(
          key: 'employee_id', value: response.data['data']['employee_id']);
    }
    return response.data;
  }

  /// Password-based login (an alternative to the OTP flow, e.g. for an
  /// account provisioned directly by an admin). Unlike [verifyOTP], this
  /// does not register a device as a side effect - call [registerDevice]
  /// separately afterward.
  Future<Map<String, dynamic>> loginWithPassword({
    required String employeeCode,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'employee_code': employeeCode,
      'password': password,
    });
    if (response.data['success'] == true) {
      await _storage.write(
          key: 'auth_token', value: response.data['data']['token']);
      await _storage.write(
          key: 'employee_id', value: response.data['data']['employee_id']);
    }
    return response.data;
  }

  /// Passwordless login using the biometric-gated device key set up after a
  /// previous OTP/password login - see BiometricKeyService.signLogin.
  Future<Map<String, dynamic>> loginBiometric({
    required String employeeCode,
    required String deviceId,
    required String signature,
    required String signedAt,
  }) async {
    final response = await _dio.post('/auth/login-biometric', data: {
      'employee_code': employeeCode,
      'device_id': deviceId,
      'signature': signature,
      'signed_at': signedAt,
    });
    if (response.data['success'] == true) {
      await _storage.write(
          key: 'auth_token', value: response.data['data']['token']);
      await _storage.write(
          key: 'employee_id', value: response.data['data']['employee_id']);
    }
    return response.data;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String platform,
    required String deviceName,
  }) async {
    final response = await _dio.post('/devices/register', data: {
      'device_id': deviceId,
      'platform': platform,
      'device_name': deviceName,
    });
    return response.data;
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'employee_id');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getEmployeeId() async {
    return await _storage.read(key: 'employee_id');
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null;
  }
}