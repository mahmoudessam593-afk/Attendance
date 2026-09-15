import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_key_service.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';
import '../../services/site_cache_service.dart';
import '../../models/models.dart';
import '../../widgets/distance_indicator.dart';
import '../../widgets/attendance_button.dart';
import '../history/history_screen.dart';
import '../login/login_screen.dart';

/// Turns a Dio failure into a message worth showing a non-technical user:
/// a real server error message when we have one, a plain "check your
/// connection" line for anything network-shaped, instead of a single
/// generic "failed" that hides what actually went wrong.
String friendlyErrorMessage(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Check your internet connection and try again.';
      default:
        break;
    }
    final data = e.response?.data;
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    if (e.response != null) {
      return 'Server error (${e.response!.statusCode}). Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late final AuthService _authService = AuthService(_apiService.client);
  late final BiometricKeyService _biometricKeyService = BiometricKeyService(_apiService.client);
  final LocationService _locationService = LocationService();
  final DeviceService _deviceService = DeviceService();
  final SiteCacheService _siteCache = SiteCacheService();

  List<Site> _assignedSites = [];
  Site? _nearestSite;
  double? _currentLat;
  double? _currentLon;
  double? _currentAccuracy;
  double? _distance;
  bool _isWithinRadius = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isSyncingSites = false;
  bool _hasLocation = false;
  bool _geoValidated = false;
  String? _error;
  String? _deviceId;
  String? _validationMessage;

  bool _hasCheckedInToday = false;
  bool _hasCheckedOutToday = false;
  DateTime? _checkInTime;
  Timer? _countdownTimer;
  // Server-driven per-site minimum (see attendance_rules.min_minutes_before_checkout
  // on the backend); 30 is only a fallback used before today-status has loaded.
  int _minMinutesBeforeCheckout = 30;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
    _loadSites();
    _loadTodayStatus();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeviceId() async {
    final id = await _deviceService.getDeviceId();
    if (mounted) {
      setState(() => _deviceId = id);
    }
  }

  /// Reads assigned sites from the local cache (filled in by the splash
  /// screen at startup) instead of hitting the API on every visit - the
  /// authoritative site data is re-checked against the server anyway at
  /// every /attendance/validate call, which also refreshes this cache.
  Future<void> _loadSites() async {
    final cached = await _siteCache.loadSites();
    if (cached.isNotEmpty) {
      setState(() => _assignedSites = cached);
      return;
    }
    await _refreshSitesFromServer();
  }

  Future<void> _refreshSitesFromServer() async {
    setState(() => _isSyncingSites = true);
    try {
      final response = await _apiService.client.get('/employees/me/sites');
      if (response.data['success'] == true) {
        final sites = (response.data['data'] as List)
            .map((s) => Site.fromMap(s))
            .toList();
        await _siteCache.saveSites(sites);
        setState(() => _assignedSites = sites);
      }
    } catch (e) {
      setState(() => _error = friendlyErrorMessage(e));
    } finally {
      setState(() => _isSyncingSites = false);
    }
  }

  Future<void> _loadTodayStatus() async {
    try {
      final response = await _apiService.client.get('/attendance/today-status');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _hasCheckedInToday = data['has_checkin'] == true;
          _hasCheckedOutToday = data['has_checkout'] == true;
          _checkInTime = data['checkin_time'] != null
              ? DateTime.parse(data['checkin_time']).toLocal()
              : null;
          _minMinutesBeforeCheckout = (data['min_minutes_before_checkout'] as num?)?.toInt() ?? 30;
        });
        _restartCountdownIfNeeded();
      }
    } catch (_) {
      // Non-fatal - button gating just falls back to allowing an attempt,
      // and the server still enforces the real rule either way.
    }
  }

  void _restartCountdownIfNeeded() {
    _countdownTimer?.cancel();
    if (_hasCheckedInToday && !_hasCheckedOutToday && !_checkoutUnlocked) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_checkoutUnlocked) {
          _countdownTimer?.cancel();
        }
        setState(() {});
      });
    }
  }

  bool get _checkoutUnlocked {
    if (_checkInTime == null) return false;
    return _secondsUntilCheckoutUnlocked <= 0;
  }

  int get _secondsUntilCheckoutUnlocked {
    if (_checkInTime == null) return _minMinutesBeforeCheckout * 60;
    final elapsedSeconds = DateTime.now().difference(_checkInTime!).inSeconds;
    final totalSeconds = _minMinutesBeforeCheckout * 60;
    return (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);
  }

  String get _formattedCheckoutCountdown {
    final remaining = _secondsUntilCheckoutUnlocked;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoading = true;
      _geoValidated = false;
      _validationMessage = null;
    });

    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      setState(() {
        _error = 'Location permission denied.';
        _isLoading = false;
      });
      return;
    }

    final position = await _locationService.getCurrentPosition();
    if (position == null) {
      setState(() {
        _error = 'Failed to get GPS position.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _currentLat = position.latitude;
      _currentLon = position.longitude;
      _currentAccuracy = position.accuracy;
      _hasLocation = true;
      _error = null;
    });

    _calculateNearestSite();

    if (_nearestSite != null) {
      await _validateWithServer();
    }

    setState(() => _isLoading = false);
  }

  void _calculateNearestSite() {
    if (_assignedSites.isEmpty || _currentLat == null || _currentLon == null) return;

    Site? nearest;
    double minDistance = double.infinity;

    for (var site in _assignedSites) {
      final dist = _locationService.calculateDistance(
        lat1: _currentLat!,
        lon1: _currentLon!,
        lat2: site.latitude,
        lon2: site.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearest = site;
      }
    }

    if (nearest != null) {
      setState(() {
        _nearestSite = nearest;
        _distance = minDistance;
        _isWithinRadius = minDistance <= nearest!.radiusMeters;
      });
    }
  }

  Future<void> _validateWithServer() async {
    if (_nearestSite == null || _currentLat == null || _currentLon == null) return;

    try {
      final response = await _apiService.client.post('/attendance/validate', data: {
        'siteId': _nearestSite!.id,
        'latitude': _currentLat,
        'longitude': _currentLon,
        'accuracy': _currentAccuracy ?? 0,
        'attendanceType': 'CHECK_IN',
        'deviceId': _deviceId ?? 'unknown',
      });

      if (response.data['success'] == true) {
        final data = response.data['data'];
        await _syncSiteFromServer(data['site']);
        setState(() {
          _geoValidated = true;
          _distance = data['distance'] ?? _distance;
          _validationMessage = 'Geo validated - Inside attendance area';
        });
      } else {
        setState(() {
          _geoValidated = false;
          _validationMessage = response.data['error'] ?? 'Geo validation failed';
        });
      }
    } catch (e) {
      setState(() {
        _geoValidated = false;
        _validationMessage = friendlyErrorMessage(e);
      });
    }
  }

  /// The validate/check-in/check-out calls always check against the live
  /// site row on the server, so a successful response is the freshest
  /// possible copy of that site's data (e.g. a radius an admin just
  /// changed) - use it to keep the local cache and on-screen numbers in
  /// sync without having to poll the sites list separately.
  Future<void> _syncSiteFromServer(dynamic siteJson) async {
    if (siteJson is! Map<String, dynamic>) return;
    final updated = Site.fromMap(siteJson);
    await _siteCache.updateSite(updated);
    setState(() {
      _nearestSite = updated;
      final idx = _assignedSites.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _assignedSites[idx] = updated;
    });
  }

  Future<void> _openDirections() async {
    final site = _nearestSite;
    if (site == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${site.latitude},${site.longitude}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Future<void> _submitAttendance({required String type}) async {
    if (_currentLat == null || _currentLon == null || _nearestSite == null) return;
    if (!_geoValidated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm $type'),
        content: Text('Submit attendance for ${_nearestSite!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deviceId = _deviceId ?? 'unknown';
    final employeeId = await _authService.getEmployeeId();
    if (employeeId == null) return;

    try {
      // No-op if already set up (e.g. right after OTP) - a safety net for
      // accounts that missed enrollment earlier (declined, no biometrics
      // available at the time, etc).
      await _biometricKeyService.ensureKeyRegistered(deviceId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric setup failed: ${e.toString()}')),
        );
      }
      return;
    }

    final ({String signature, String signedAt}) proof;
    try {
      proof = await _biometricKeyService.signAttendance(
        deviceId: deviceId,
        employeeId: employeeId,
        siteId: _nearestSite!.id,
        attendanceType: type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication failed')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _apiService.client.post(
        type == 'CHECK_IN' ? '/attendance/check-in' : '/attendance/check-out',
        data: {
          'siteId': _nearestSite!.id,
          'latitude': _currentLat,
          'longitude': _currentLon,
          'accuracy': _currentAccuracy ?? 0,
          'attendanceType': type,
          'deviceId': deviceId,
          'signature': proof.signature,
          'signedAt': proof.signedAt,
        },
      );

      if (response.data['success'] == true) {
        setState(() => _geoValidated = false);
        await _loadTodayStatus();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance recorded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['error'] ?? 'Failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  bool get _canCheckIn =>
      _geoValidated && !_isSubmitting && !_hasCheckedInToday && !_hasCheckedOutToday;

  bool get _canCheckOut =>
      _geoValidated &&
      !_isSubmitting &&
      _hasCheckedInToday &&
      !_hasCheckedOutToday &&
      _checkoutUnlocked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isSyncingSites
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Sync assigned sites',
            onPressed: _isSyncingSites ? null : _refreshSitesFromServer,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Attendance history',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _nearestSite?.name ?? 'No site found',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        if (_nearestSite != null)
                          TextButton.icon(
                            onPressed: _openDirections,
                            icon: const Icon(Icons.directions, size: 18),
                            label: const Text('Directions'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_hasLocation && _validationMessage != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _geoValidated ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _geoValidated ? Icons.check_circle : Icons.error,
                              color: _geoValidated ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationMessage!,
                                style: TextStyle(
                                  color: _geoValidated ? Colors.green[700] : Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_hasLocation)
                      Text(
                        'Status: ${_isWithinRadius ? "Inside" : "Outside"} (local)',
                        style: TextStyle(
                          color: _isWithinRadius ? Colors.green : Colors.red,
                        ),
                      )
                    else
                      const Text(
                        'Tap Refresh to get your location',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _refreshLocation,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(_isLoading ? 'Validating...' : 'Refresh Location'),
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
            if (_hasLocation && _nearestSite != null)
              DistanceIndicator(
                distance: _distance,
                radius: _nearestSite!.radiusMeters.toDouble(),
                accuracy: _currentAccuracy ?? 0,
                isWithinRadius: _isWithinRadius,
              ),
            const SizedBox(height: 24),
            AttendanceButton(
              isEnabled: _canCheckIn,
              onPressed: () => _submitAttendance(type: 'CHECK_IN'),
              label: _hasCheckedInToday ? 'CHECKED IN' : 'CHECK IN',
            ),
            const SizedBox(height: 12),
            AttendanceButton(
              isEnabled: _canCheckOut,
              onPressed: () => _submitAttendance(type: 'CHECK_OUT'),
              label: _hasCheckedOutToday ? 'CHECKED OUT' : 'CHECK OUT',
            ),
            if (_hasCheckedInToday && !_hasCheckedOutToday && !_checkoutUnlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Check-out available in $_formattedCheckoutCountdown minutes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
