import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// A single stable device identity, generated once and persisted, used
/// consistently for both device registration (OTP verification) and every
/// later attendance request. The backend rejects attendance from a device_id
/// that wasn't registered, so these two call sites must agree on the value.
class DeviceService {
  static const _deviceIdKey = 'device_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String> getDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  /// kIsWeb has to be checked first: in a browser defaultTargetPlatform still
  /// reports the underlying OS, so a browser on an Android phone would
  /// otherwise register as a native Android device - and the server decides
  /// whether biometric proof is required from exactly this value.
  String get platformName {
    if (kIsWeb) return 'Web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'Android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'iOS';
    return 'Unknown';
  }

  Future<String> getDeviceName() async {
    if (kIsWeb) return 'Browser';
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}'.trim();
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await deviceInfo.iosInfo;
        return info.utsname.machine;
      }
    } catch (_) {
      // Fall through to the generic name below.
    }
    return '$platformName device';
  }
}
