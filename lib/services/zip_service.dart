import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// Offline ZIP code lookup backed by the Census ZCTA centroid table bundled
/// at `assets/zip_centroids.json`.
///
/// The business directory only locates listings to a ZIP, so the map queries
/// by ZIP rather than by coordinates. Resolving "where am I" to "which ZIPs
/// are near me" happens here, on-device, against the bundled table -- there is
/// no geocoding API call, no key, and no per-lookup cost.
class ZipService {
  static const String _assetPath = 'assets/zip_centroids.json';

  /// zip -> [latitude, longitude]
  final Map<String, List<double>> _centroids;

  ZipService._(this._centroids);

  static ZipService? _instance;

  /// Loads and caches the table. Safe to call repeatedly; the ~1MB asset is
  /// parsed once per app session.
  static Future<ZipService> instance() async {
    final existing = _instance;
    if (existing != null) return existing;

    final raw = await rootBundle.loadString(_assetPath);
    final decoded = json.decode(raw) as Map<String, dynamic>;

    final centroids = <String, List<double>>{};
    decoded.forEach((zip, value) {
      if (value is List && value.length >= 2) {
        final lat = (value[0] as num).toDouble();
        final lng = (value[1] as num).toDouble();
        centroids[zip] = [lat, lng];
      }
    });

    return _instance = ZipService._(centroids);
  }

  int get zipCount => _centroids.length;

  bool isKnownZip(String zip) => _centroids.containsKey(normalize(zip));

  /// Provides an approximate map center for a ZIP absent from the Census
  /// table, using an existing directory listing. Kept only for this session;
  /// bundled centroids and Firebase records are never overwritten.
  void rememberBusinessLocation(String zip, double latitude, double longitude) {
    final normalized = normalize(zip);
    if (normalized.isEmpty ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      return;
    }
    _centroids.putIfAbsent(normalized, () => [latitude, longitude]);
  }

  /// Accepts "21797", "21797-1234" or padded input and returns the 5-digit
  /// form, or an empty string when it is not a usable ZIP.
  static String normalize(String input) {
    final digits = input.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 5) return '';
    return digits.substring(0, 5);
  }

  /// Centroid of [zip] as (latitude, longitude), or null when unknown.
  (double, double)? centroidOf(String zip) {
    final point = _centroids[normalize(zip)];
    if (point == null) return null;
    return (point[0], point[1]);
  }

  /// The ZIP whose centroid is closest to [location].
  ///
  /// Used to turn a device GPS fix into a starting ZIP without a reverse
  /// geocoding call.
  String? nearestZip(double latitude, double longitude) {
    String? best;
    double bestMiles = double.infinity;

    _centroids.forEach((zip, point) {
      final miles = _approximateMiles(latitude, longitude, point[0], point[1]);
      if (miles < bestMiles) {
        bestMiles = miles;
        best = zip;
      }
    });

    return best;
  }

  /// ZIPs whose centroid lies within [milesRadius] of [location], nearest
  /// first.
  ///
  /// [limit] caps the result because dense metros return a lot of ZIPs --
  /// central Manhattan has ~194 within 10 miles -- and every extra ZIP costs
  /// another slot in the Firestore query.
  List<String> zipsWithin(
    double latitude,
    double longitude, {
    double milesRadius = 10,
    int limit = 30,
  }) {
    final matches = <MapEntry<String, double>>[];

    _centroids.forEach((zip, point) {
      final miles = _approximateMiles(latitude, longitude, point[0], point[1]);
      if (miles <= milesRadius) matches.add(MapEntry(zip, miles));
    });

    matches.sort((a, b) => a.value.compareTo(b.value));
    return matches.take(limit).map((entry) => entry.key).toList();
  }

  /// ZIPs near [location], widening the radius until something turns up.
  ///
  /// A 10-mile radius in rural Wyoming can contain a single ZIP with no
  /// businesses in it, so fall back to progressively larger rings rather than
  /// showing an empty map.
  List<String> zipsNear(
    double latitude,
    double longitude, {
    List<double> radiiMiles = const [10, 25, 50, 100],
    int limit = 30,
  }) {
    for (final radius in radiiMiles) {
      final zips = zipsWithin(
        latitude,
        longitude,
        milesRadius: radius,
        limit: limit,
      );
      if (zips.isNotEmpty) return zips;
    }
    return const [];
  }

  /// ZIPs surrounding a typed ZIP, including the ZIP itself.
  List<String> zipsAroundZip(
    String zip, {
    double milesRadius = 10,
    int limit = 30,
  }) {
    final center = centroidOf(zip);
    if (center == null) {
      final normalized = normalize(zip);
      return normalized.isEmpty ? const [] : [normalized];
    }
    return zipsWithin(
      center.$1,
      center.$2,
      milesRadius: milesRadius,
      limit: limit,
    );
  }

  /// Approximate distance in miles between two coordinate pairs.
  static double milesBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) => _approximateMiles(lat1, lng1, lat2, lng2);

  /// Equirectangular approximation -- accurate enough at these distances and
  /// far cheaper than haversine across 33,000 entries on every lookup.
  static double _approximateMiles(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double milesPerDegreeLat = 69.0;
    final deltaLat = (lat2 - lat1) * milesPerDegreeLat;
    final deltaLng = (lng2 - lng1) * milesPerDegreeLat * cos(lat1 * pi / 180.0);
    return sqrt(deltaLat * deltaLat + deltaLng * deltaLng);
  }
}
