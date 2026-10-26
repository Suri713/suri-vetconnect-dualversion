import 'package:latlong2/latlong.dart';

class AiSearchArea {
  final LatLng center;
  final String label;
  const AiSearchArea(this.center, this.label);
}

/// Apply the actual distance cutoff after fetching candidates. Unknown or
/// invalid coordinates never qualify for a radius-restricted result.
List<Map<String, dynamic>> nearbyBusinessMatches(
  Iterable<Map<String, dynamic>> businesses,
  String query,
  LatLng center, {
  double radiusMiles = 20,
}) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toSet();
  final results = <Map<String, dynamic>>[];
  const distance = Distance(roundResult: false);
  for (final business in businesses) {
    final lat = business['lat'];
    final lng = business['lng'];
    if (lat is! num ||
        lng is! num ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180)
      continue;
    final miles = distance.as(
      LengthUnit.Mile,
      center,
      LatLng(lat.toDouble(), lng.toDouble()),
    );
    if (miles > radiusMiles) continue;
    final haystack =
        '${business['name'] ?? ''} ${business['description'] ?? ''}'
            .toLowerCase();
    if (words.isNotEmpty && !words.any(haystack.contains)) continue;
    results.add({...business, 'distanceMiles': miles});
  }
  results.sort(
    (a, b) => (a['distanceMiles'] as num).compareTo(b['distanceMiles'] as num),
  );
  return results;
}
