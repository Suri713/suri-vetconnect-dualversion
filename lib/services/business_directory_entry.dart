/// Explicit public fields: account details and DoD IDs never enter the directory.
Map<String, dynamic> publicBusinessEntry(
  Map<String, dynamic> business,
  String ownerId,
) {
  const fields = [
    'id',
    'name',
    'startDate',
    'lat',
    'lng',
    'description',
    'photoUrls',
    'postalCode',
    'address',
    'ownershipStatus',
  ];
  final publicBusiness = <String, dynamic>{
    for (final key in fields)
      if (business.containsKey(key)) key: business[key],
  };
  final words = '${business['name'] ?? ''} ${business['description'] ?? ''}'
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.isNotEmpty);
  final prefixes = <String>{};
  for (final word in words.take(100)) {
    for (var length = 1; length <= word.length && length <= 40; length++) {
      prefixes.add(word.substring(0, length));
    }
  }
  return {
    'ownerId': ownerId,
    'business': publicBusiness,
    'searchPrefixes': prefixes.toList(),
  };
}
