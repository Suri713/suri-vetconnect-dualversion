import 'package:geolocator/geolocator.dart';

enum LocationAccessStatus { available, serviceDisabled, denied, deniedForever }

class LocationManager {
  bool _serviceEnabled = false;
  bool _locationPermission = false;

  bool get serviceEnabled => _serviceEnabled;
  bool get locationPermission => _locationPermission;
  Future<Position> Function() get location => () async {
    return await Geolocator.getCurrentPosition();
  };

  LocationManager._(this._serviceEnabled, this._locationPermission);

  static Future<LocationManager> init() async {
    return LocationManager._(false, false);
  }

  Future<LocationAccessStatus> refreshLocationAccess({
    bool requestPermissionIfNeeded = true,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    _serviceEnabled = serviceEnabled;

    if (!serviceEnabled) {
      _locationPermission = false;
      return LocationAccessStatus.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied && requestPermissionIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      _locationPermission = false;
      return LocationAccessStatus.deniedForever;
    }

    if (permission == LocationPermission.denied) {
      _locationPermission = false;
      return LocationAccessStatus.denied;
    }

    _locationPermission = true;
    return LocationAccessStatus.available;
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }
}
