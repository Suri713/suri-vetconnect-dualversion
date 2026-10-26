import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetconnect/services/business_recommendations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final coffee = {
    'id': 'coffee',
    'name': 'Morning Coffee',
    'description': 'Coffee cafe bakery',
    'lat': 37.45,
    'lng': -122.1,
  };
  final auto = {
    'id': 'auto',
    'name': 'Auto repair',
    'description': 'Car tires mechanic',
    'lat': 37.451,
    'lng': -122.1,
  };

  test('chosen interests change the highest-ranked nearby business', () {
    expect(
      rankBusinesses(
        [coffee, auto],
        interests: ['Auto services'],
      ).first.business['id'],
      'auto',
    );
    expect(
      rankBusinesses(
        [auto, coffee],
        interests: ['Food & coffee'],
      ).first.business['id'],
      'coffee',
    );
  });
  test('searches and previous business views provide relevant reasons', () {
    final search = rankBusinesses([auto, coffee], recentSearches: ['coffee']);
    expect(search.first.business['id'], 'coffee');
    expect(search.first.reason, 'Based on your recent searches');
    final viewed = rankBusinesses(
      [auto, coffee],
      viewed: [
        {
          'id': 'another-cafe',
          'terms': ['coffee', 'cafe'],
        },
      ],
    );
    expect(viewed.first.business['id'], 'coffee');
    expect(viewed.first.reason, 'Similar to businesses you viewed');
  });
  test('location breaks cold-start ties and duplicate IDs are excluded', () {
    final rows = rankBusinesses(
      [coffee, coffee, auto],
      latitude: 37.451,
      longitude: -122.1,
    );
    expect(rows.length, 2);
    expect(rows.first.business['id'], 'auto');
    expect(rows.first.miles, closeTo(0, 0.001));
    expect(rankBusinesses([]), isEmpty);
    expect(rankBusinesses([auto, coffee], limit: 1), hasLength(1));
  });
  test('preferences and history persist under separate account keys', () async {
    SharedPreferences.setMockInitialValues({});
    final alice = await RecommendationProfile.forUser(
      'recommendations-test-alice',
    );
    final bob = await RecommendationProfile.forUser('recommendations-test-bob');
    await alice.setInterests([
      'Food & coffee',
      'Auto services',
      'Shopping',
      'Home services',
      'unknown',
    ]);
    await alice.recordSearch('COFFEE');
    await alice.recordView(coffee);
    expect(alice.interests, hasLength(3));
    expect(bob.interests, isEmpty);
    expect(bob.recentSearches, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    final key =
        'business_recommendations_v1_${base64Url.encode(utf8.encode('recommendations-test-alice'))}';
    expect(jsonDecode(prefs.getString(key)!)['searches'], ['coffee']);
    await alice.clearHistory();
    expect(alice.viewed, isEmpty);
    expect(alice.recentSearches, isEmpty);
    expect(alice.interests, hasLength(3));
  });
  test(
    'history is bounded and repeat searches and views are deduplicated',
    () async {
      final profile = await RecommendationProfile.forUser(
        'recommendations-test-bounded',
      );
      for (var i = 0; i < 25; i++) {
        await profile.recordSearch('query $i');
        await profile.recordView({'id': '$i', 'name': 'Coffee $i'});
      }
      await profile.recordSearch('query 24');
      await profile.recordView({'id': '24', 'name': 'Coffee 24'});
      expect(profile.recentSearches, hasLength(10));
      expect(profile.viewed, hasLength(20));
      expect(profile.viewed.where((item) => item['id'] == '24'), hasLength(1));
    },
  );
}
