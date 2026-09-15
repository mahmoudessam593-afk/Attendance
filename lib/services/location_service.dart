import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

enum LocationPermissionState { granted, serviceDisabled, denied, deniedForever }

class LocationService {
  final Distance _distance = Distance();

  /// Requests and classifies location permission/service state, used by the
  /// splash screen to show the right message ("grant permission" vs
  /// "open settings" vs "turn on GPS").
  Future<LocationPermissionState> ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionState.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionState.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionState.denied;
    }
    return LocationPermissionState.granted;
  }

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    final point1 = LatLng(lat1, lon1);
    final point2 = LatLng(lat2, lon2);
    return _distance.as(LengthUnit.Meter, point1, point2);
  }
}