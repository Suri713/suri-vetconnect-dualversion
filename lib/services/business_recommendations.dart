import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetconnect/services/zip_service.dart';

const businessInterests = <String, List<String>>{
  'Food & coffee': ['coffee', 'cafe', 'restaurant', 'food', 'bakery'],
  'Shopping': ['shop', 'retail', 'gifts', 'clothing', 'store'],
  'Home services': ['home', 'plumbing', 'electric', 'repair', 'landscaping'],
  'Auto services': ['auto', 'car', 'automotive', 'mechanic', 'tires'],
  'Health & wellness': ['health', 'wellness', 'massage', 'therapy', 'care'],
  'Fitness & outdoors': ['fitness', 'gym', 'outdoor', 'sports', 'training'],
  'Professional services': [
    'consulting',
    'accounting',
    'legal',
    'design',
    'technology',
  ],
};

Set<String> recommendationTerms(String text) {
  const ignored = {
    'the',
    'and',
    'for',
    'with',
    'your',
    'from',
    'this',
    'that',
    'business',
    'services',
    'veteran',
    'owned',
    'need',
    'want',
    'looking',
    'near',
  };
  return RegExp(r'[a-z0-9]+')
      .allMatches(text.toLowerCase())
      .map((match) => match.group(0)!)
      .where((word) => word.length > 2 && !ignored.contains(word))
      .toSet();
}

String businessKey(Map<String, dynamic> business) =>
    business['id']?.toString() ??
    '${business['name']}|${business['lat']}|${business['lng']}';

/// Account-scoped interests and interaction history, stored only on this device.
class RecommendationProfile extends ChangeNotifier {
  static final Map<String, Future<RecommendationProfile>> _profiles = {};
  final SharedPreferences _prefs;
  final String _key;
  List<String> interests = [];
  List<String> recentSearches = [];
  List<Map<String, dynamic>> viewed = [];
  Future<void> _pendingSave = Future.value();

  RecommendationProfile._(this._prefs, this._key);

  static Future<RecommendationProfile> forUser(
    String userId,
  ) => _profiles.putIfAbsent(userId, () async {
    final prefs = await SharedPreferences.getInstance();
    final profile = RecommendationProfile._(
      prefs,
      'business_recommendations_v1_${base64Url.encode(utf8.encode(userId))}',
    );
    try {
      final saved = prefs.getString(profile._key);
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        profile.interests = (data['interests'] as List? ?? [])
            .whereType<String>()
            .where(businessInterests.containsKey)
            .take(3)
            .toList();
        profile.recentSearches = (data['searches'] as List? ?? [])
            .whereType<String>()
            .take(10)
            .toList();
        profile.viewed = (data['viewed'] as List? ?? [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .take(20)
            .toList();
      }
    } catch (_) {
      // Invalid old local data must not prevent browsing the directory.
    }
    return profile;
  });

  Future<void> setInterests(Iterable<String> selected) {
    interests = selected
        .where(businessInterests.containsKey)
        .toSet()
        .take(3)
        .toList();
    return _save();
  }

  Future<void> recordSearch(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return Future.value();
    final bounded = clean.substring(0, math.min(clean.length, 160));
    recentSearches = [
      bounded,
      ...recentSearches.where((item) => item != bounded),
    ].take(10).toList();
    return _save();
  }

  Future<void> recordView(Map<String, dynamic> business) {
    final id = businessKey(business);
    final terms = recommendationTerms(
      '${business['name'] ?? ''} ${business['description'] ?? ''}',
    ).take(24).toList();
    viewed = [
      {'id': id, 'terms': terms},
      ...viewed.where((item) => item['id'] != id),
    ].take(20).toList();
    return _save();
  }

  Future<void> clearHistory() {
    recentSearches = [];
    viewed = [];
    return _save();
  }

  Future<void> _save() {
    final value = jsonEncode({
      'interests': interests,
      'searches': recentSearches,
      'viewed': viewed,
    });
    notifyListeners();
    _pendingSave = _pendingSave
        .then((_) async {
          await _prefs.setString(_key, value);
        })
        .catchError((Object error) {
          debugPrint('Could not save local recommendation preferences: $error');
        });
    return _pendingSave;
  }
}

class BusinessRecommendation {
  final Map<String, dynamic> business;
  final double score;
  final String reason;
  final double? miles;
  const BusinessRecommendation(
    this.business,
    this.score,
    this.reason,
    this.miles,
  );
}

List<BusinessRecommendation> rankBusinesses(
  List<Map<String, dynamic>> businesses, {
  List<String> interests = const [],
  List<String> recentSearches = const [],
  List<Map<String, dynamic>> viewed = const [],
  double? latitude,
  double? longitude,
  int limit = 12,
}) {
  final interestTerms = interests
      .expand((name) => businessInterests[name] ?? const <String>[])
      .toSet();
  final historyTerms = <String, double>{};
  for (var i = 0; i < recentSearches.length; i++) {
    for (final term in recommendationTerms(recentSearches[i])) {
      historyTerms[term] = (historyTerms[term] ?? 0) + 1 / (i + 1);
    }
  }
  final viewedTerms = <String, double>{};
  for (var i = 0; i < viewed.length; i++) {
    for (final term
        in (viewed[i]['terms'] as List? ?? []).whereType<String>()) {
      viewedTerms[term] = (viewedTerms[term] ?? 0) + 1 / (i + 1);
    }
  }
  final seen = <String>{};
  final result = <BusinessRecommendation>[];
  for (final business in businesses) {
    final key = businessKey(business);
    if (!seen.add(key)) continue;
    final terms = recommendationTerms(
      '${business['name'] ?? ''} ${business['description'] ?? ''}',
    );
    final matches = terms.intersection(interestTerms).length;
    final searchScore = terms.fold<double>(
      0,
      (sum, term) => sum + (historyTerms[term] ?? 0),
    );
    final viewScore = terms.fold<double>(
      0,
      (sum, term) => sum + (viewedTerms[term] ?? 0),
    );
    double? miles;
    final lat = business['lat'];
    final lng = business['lng'];
    if (latitude != null &&
        longitude != null &&
        lat is num &&
        lng is num &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180) {
      miles = ZipService.milesBetween(
        latitude,
        longitude,
        lat.toDouble(),
        lng.toDouble(),
      );
    }
    final recentlyViewed = viewed.any((entry) => entry['id'] == key);
    final score =
        math.min(matches, 3) * 5 +
        math.min(searchScore, 3) * 3 +
        math.min(viewScore, 3) * 2 +
        (miles == null ? 0 : 6 / (1 + miles / 5)) -
        (recentlyViewed ? 2 : 0);
    final reason = matches > 0
        ? 'Matches your interests'
        : searchScore > 0
        ? 'Based on your recent searches'
        : viewScore > 0 && !recentlyViewed
        ? 'Similar to businesses you viewed'
        : recentlyViewed
        ? 'Recently viewed'
        : 'In this map area';
    result.add(
      BusinessRecommendation(business, score.toDouble(), reason, miles),
    );
  }
  result.sort((a, b) {
    final score = b.score.compareTo(a.score);
    return score != 0
        ? score
        : businessKey(a.business).compareTo(businessKey(b.business));
  });
  return result.take(limit).toList();
}
