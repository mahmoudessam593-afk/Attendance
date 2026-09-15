import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/site_cache_service.dart';
import '../home/home_screen.dart';
import '../login/login_screen.dart';

enum _BootState {
  checking,
  noPermission,
  permissionDeniedForever,
  locationServiceDisabled,
  noInternet,
  serverUnavailable,
}

/// Gatekeeper shown before the app's real content: makes sure location
/// permission is granted, the device has internet, and the API is actually
/// reachable, before deciding whether to land on the login screen or the
/// home screen. Also warms the site-assignment cache for an already-logged
/// -in employee so the home screen doesn't have to fetch it on every visit.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final LocationService _locationService = LocationService();
  final SiteCacheService _siteCache = SiteCacheService();
  late final AuthService _authService = AuthService(ApiService().client);

  _BootState _state = _BootState.checking;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _state = _BootState.checking);

    final permission = await _locationService.ensureLocationPermission();
    switch (permission) {
      case LocationPermissionState.serviceDisabled:
        setState(() => _state = _BootState.locationServiceDisabled);
        return;
      case LocationPermissionState.deniedForever:
        setState(() => _state = _BootState.permissionDeniedForever);
        return;
      case LocationPermissionState.denied:
        setState(() => _state = _BootState.noPermission);
        return;
      case LocationPermissionState.granted:
        break;
    }

    final connectivity = await Connectivity().checkConnectivity();
    final hasNetwork = connectivity.any((c) => c != ConnectivityResult.none);
    if (!hasNetwork) {
      setState(() => _state = _BootState.noInternet);
      return;
    }

    final serverOk = await _pingServer();
    if (!serverOk) {
      setState(() => _state = _BootState.serverUnavailable);
      return;
    }

    await _proceed();
  }

  Future<bool> _pingServer() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
      ));
      final response = await dio.get(ApiService.healthUrl);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _proceed() async {
    final loggedIn = await _authService.isLoggedIn();

    if (loggedIn) {
      try {
        final response = await ApiService().client.get('/employees/me/sites');
        if (response.data['success'] == true) {
          final sites = (response.data['data'] as List)
              .map((s) => Site.fromMap(s))
              .toList();
          await _siteCache.saveSites(sites);
        }
      } catch (_) {
        // Non-fatal: HomeScreen falls back to whatever is already cached
        // (or fetches fresh itself if the cache is empty).
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => loggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/egypt_gas_logo.png', height: 140),
              const SizedBox(height: 32),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _BootState.checking:
        return const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting up...'),
          ],
        );

      case _BootState.noPermission:
        return _StatusView(
          icon: Icons.location_off,
          message: 'Location permission is required to verify your attendance location.',
          primaryLabel: 'Grant Permission',
          onPrimary: _bootstrap,
        );

      case _BootState.permissionDeniedForever:
        return _StatusView(
          icon: Icons.location_off,
          message:
              'Location permission was permanently denied. Please enable it from app settings to continue.',
          primaryLabel: 'Open Settings',
          onPrimary: () async {
            await Geolocator.openAppSettings();
          },
          secondaryLabel: 'Retry',
          onSecondary: _bootstrap,
        );

      case _BootState.locationServiceDisabled:
        return _StatusView(
          icon: Icons.location_disabled,
          message: 'Location services (GPS) are turned off. Please enable them to continue.',
          primaryLabel: 'Open Location Settings',
          onPrimary: () async {
            await Geolocator.openLocationSettings();
          },
          secondaryLabel: 'Retry',
          onSecondary: _bootstrap,
        );

      case _BootState.noInternet:
        return _StatusView(
          icon: Icons.wifi_off,
          message: 'No internet connection. Please check your network and try again.',
          primaryLabel: 'Retry',
          onPrimary: _bootstrap,
        );

      case _BootState.serverUnavailable:
        return _StatusView(
          icon: Icons.cloud_off,
          message:
              'Cannot reach the attendance server right now. It may be down for maintenance - please try again shortly.',
          primaryLabel: 'Retry',
          onPrimary: _bootstrap,
        );
    }
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final String? secondaryLabel;
  final Future<void> Function()? onSecondary;

  const _StatusView({
    required this.icon,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => onPrimary(),
          child: Text(primaryLabel),
        ),
        if (secondaryLabel != null && onSecondary != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => onSecondary!(),
            child: Text(secondaryLabel!),
          ),
        ],
      ],
    );
  }
}
