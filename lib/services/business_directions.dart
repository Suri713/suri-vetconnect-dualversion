/// Builds a directions destination from the listing, never from an offset
/// display marker. Imported ZIP centroids are not street addresses.
class BusinessDirections {
  static String _text(Map<String, dynamic> business, String key) =>
      business[key]?.toString().trim() ?? '';

  static bool hasApproximateLocation(Map<String, dynamic> business) {
    final source = _text(business, 'geocodeSource');
    final accuracy = _text(business, 'geocodeAccuracy');
    return source.startsWith('census-zcta-centroid') ||
        accuracy == 'approximate' ||
        accuracy == 'geometric_center';
  }

  static String addressLabel(Map<String, dynamic> business) {
    final formatted = _text(business, 'geocodeFormattedAddress');
    final street = _text(business, 'streetAddress');
    final raw = _text(business, 'locationRaw');
    final area = raw.isNotEmpty
        ? raw
        : [
            _text(business, 'city'),
            _text(business, 'state'),
            _text(business, 'postalCode'),
          ].where((value) => value.isNotEmpty).join(', ');
    if (formatted.isNotEmpty && !hasApproximateLocation(business)) {
      return formatted;
    }
    return [street, area].where((value) => value.isNotEmpty).join(', ');
  }

  static Uri? uriFor(Map<String, dynamic> business) {
    final name = _text(business, 'name');
    final address = addressLabel(business);
    String destination;
    if (address.isNotEmpty) {
      // Maps resolves the named business when the directory only knows its ZIP.
      destination = [name, address].where((s) => s.isNotEmpty).join(', ');
      if (name.isEmpty &&
          hasApproximateLocation(business) &&
          _text(business, 'streetAddress').isEmpty) {
        return null;
      }
    } else {
      if (hasApproximateLocation(business)) return null;
      final lat = double.tryParse(_text(business, 'lat'));
      final lng = double.tryParse(_text(business, 'lng'));
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat.abs() > 90 ||
          lng.abs() > 180) {
        return null;
      }
      destination = '$lat,$lng';
    }
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
  }
}
