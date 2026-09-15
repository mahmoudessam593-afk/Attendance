import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:biometric_signature/biometric_signature.dart';

/// Binds attendance actions to a specific device's enrolled biometrics
/// without ever handling raw biometric data (no phone OS exposes that to
/// apps). Instead: a hardware-backed key pair is generated once, right
/// after OTP verification; the private half never leaves Android Keystore /
/// iOS Secure Enclave and can only be used to sign after a successful
/// biometric prompt. The server stores only the public half and verifies a
/// signature on every check-in/out - see
/// backend/src/utils/signature.utils.ts for the matching server-side logic.
class BiometricKeyService {
  final Dio _dio;
  final BiometricSignature _biometric = BiometricSignature();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  BiometricKeyService(this._dio);

  String _keyAlias(String deviceId) => 'attendance_key_$deviceId';
  String _registeredFlagKey(String deviceId) => 'biometric_key_registered_$deviceId';

  /// Call once, right after OTP verification succeeds (the device is
  /// already registered server-side as part of that same call). No-op if
  /// this device already has a registered key.
  Future<void> ensureKeyRegistered(String deviceId) async {
    final alreadyDone = await _storage.read(key: _registeredFlagKey(deviceId));
    if (alreadyDone == 'true') return;

    final alias = _keyAlias(deviceId);
    final exists = await _biometric.biometricKeyExists(keyAlias: alias, checkValidity: true);

    String? publicKeyPem;
    if (exists) {
      final info = await _biometric.getKeyInfo(keyAlias: alias, keyFormat: KeyFormat.pem);
      publicKeyPem = info.publicKey;
    }

    if (publicKeyPem == null) {
      final result = await _biometric.createKeys(
        keyAlias: alias,
        keyFormat: KeyFormat.pem,
        promptMessage: 'Set up biometric verification for attendance',
        config: CreateKeysConfig(
          signatureType: SignatureType.ecdsa,
          enforceBiometric: true,
        ),
      );
      publicKeyPem = result.publicKey;
      if (publicKeyPem == null) {
        throw Exception(result.error ?? 'Failed to set up biometric verification');
      }
    }

    await _dio.post('/devices/register-key', data: {
      'device_id': deviceId,
      'public_key': publicKeyPem,
      'key_algorithm': 'EC',
    });

    await _storage.write(key: _registeredFlagKey(deviceId), value: 'true');
  }

  /// Whether this device already completed biometric enrollment (key
  /// created and its public half accepted by the server) - used to decide
  /// whether to even offer a "Login with fingerprint" option, since a login
  /// signature is only useful once a previous OTP/password login has set
  /// this up.
  Future<bool> hasRegisteredKey(String deviceId) async {
    return (await _storage.read(key: _registeredFlagKey(deviceId))) == 'true';
  }

  /// Signs a login payload tagged distinctly from attendance signatures
  /// (see backend/src/utils/signature.utils.ts buildLoginSignaturePayload)
  /// - triggers the OS biometric prompt. Throws if the user cancels,
  /// authentication fails, or no key exists yet for this device.
  Future<({String signature, String signedAt})> signLogin({
    required String deviceId,
    required String employeeCode,
  }) async {
    final signedAt = DateTime.now().toUtc().toIso8601String();
    final payload = '$employeeCode|$deviceId|LOGIN|$signedAt';

    final result = await _biometric.createSignature(
      payload: payload,
      keyAlias: _keyAlias(deviceId),
      signatureFormat: SignatureFormat.base64,
      promptMessage: 'Log in with biometric authentication',
    );

    if (result.signature == null) {
      throw Exception(result.error ?? 'Biometric authentication failed');
    }

    return (signature: result.signature!, signedAt: signedAt);
  }

  /// Signs the canonical attendance payload - this call itself triggers the
  /// OS biometric prompt. Throws if the user cancels or authentication
  /// fails; callers should treat that the same way the old
  /// local_auth.authenticate() failure was treated (block the submission).
  Future<({String signature, String signedAt})> signAttendance({
    required String deviceId,
    required String employeeId,
    required String siteId,
    required String attendanceType,
  }) async {
    final signedAt = DateTime.now().toUtc().toIso8601String();
    // Must match backend/src/utils/signature.utils.ts buildAttendanceSignaturePayload exactly.
    final payload = '$employeeId|$deviceId|$siteId|$attendanceType|$signedAt';

    final result = await _biometric.createSignature(
      payload: payload,
      keyAlias: _keyAlias(deviceId),
      signatureFormat: SignatureFormat.base64,
      promptMessage: 'Confirm attendance with biometric authentication',
    );

    if (result.signature == null) {
      throw Exception(result.error ?? 'Biometric authentication failed');
    }

    return (signature: result.signature!, signedAt: signedAt);
  }
}
