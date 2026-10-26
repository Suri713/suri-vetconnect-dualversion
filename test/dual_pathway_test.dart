import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetconnect/registration/pathway_page.dart';
import 'package:vetconnect/registration/register.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:vetconnect/services/business_directory_entry.dart';
import 'package:vetconnect/services/nearby_business_search.dart';
import 'package:vetconnect/main.dart';

void main() {
  test('pathways keep business and careers exclusive to veteran owners', () {
    expect(AccountPathway.user.canManageBusiness, isFalse);
    expect(AccountPathway.user.canViewCareers, isFalse);
    expect(AccountPathway.veteran.canManageBusiness, isTrue);
    expect(AccountPathway.veteran.canViewCareers, isTrue);
    expect(AccountPathway.fromValue('veteran'), AccountPathway.veteran);
    expect(AccountPathway.fromValue('user'), AccountPathway.user);
    expect(AccountPathway.fromValue(null), isNull);
    expect(AccountPathway.fromValue('unknown'), isNull);
  });

  test('DoD field accepts exactly ten digits including leading zeroes', () {
    expect(isValidDodId('0123456789'), isTrue);
    for (final value in [
      '',
      '123456789',
      '12345678901',
      '123456789x',
      '12345 6789',
    ]) {
      expect(isValidDodId(value), isFalse);
    }
  });

  test(
    'public directory whitelist excludes account and identification data',
    () {
      final entry = publicBusinessEntry({
        'id': 'business-id',
        'name': 'Community Coffee',
        'description': 'Espresso',
        'lat': 37.0,
        'lng': -122.0,
        'postalCode': '94303',
        'photoUrls': ['https://example.com/photo'],
        'dodId': '0123456789',
        'email': 'private@example.com',
        'password': 'private',
      }, 'owner');
      final business = entry['business'] as Map;
      expect(business.keys, isNot(contains('dodId')));
      expect(business.keys, isNot(contains('email')));
      expect(business.keys, isNot(contains('password')));
      expect(business['postalCode'], '94303');
      expect(
        entry['searchPrefixes'],
        containsAll(['coffee', 'cof', 'espresso']),
      );
    },
  );

  test(
    'radius filter rejects distant and invalid locations before showing results',
    () {
      const center = LatLng(37.45, -122.12);
      const distance = Distance();
      final inside = distance.offset(center, 19.99 * 1609.344, 0);
      final outside = distance.offset(center, 20.01 * 1609.344, 0);
      Map<String, dynamic> coffee(String id, LatLng p) => {
        'id': id,
        'name': 'Coffee',
        'lat': p.latitude,
        'lng': p.longitude,
      };
      final source = [
        coffee('outside', outside),
        coffee('inside', inside),
        coffee('center', center),
        {'name': 'Coffee', 'lat': 91, 'lng': -122},
        {'name': 'Coffee', 'lat': double.nan, 'lng': -122},
        {'name': 'Coffee'},
        {
          'name': 'Auto repairs',
          'lat': center.latitude,
          'lng': center.longitude,
        },
      ];
      final results = nearbyBusinessMatches(source, 'coffee', center);
      expect(results.map((e) => e['id']), ['center', 'inside']);
      expect(results.every((e) => (e['distanceMiles'] as num) <= 20), isTrue);
      expect(source[1].containsKey('distanceMiles'), isFalse);
    },
  );

  for (final pathway in AccountPathway.values) {
    testWidgets('mission and ${pathway.label} lead to matching registration', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: const PathwayPage(),
          onGenerateRoute: (settings) => settings.name == AppRoutes.register
              ? MaterialPageRoute(
                  builder: (_) => RegisterPage(
                    pathway: settings.arguments! as AccountPathway,
                  ),
                )
              : null,
        ),
      );
      expect(find.text('Our mission'), findsOneWidget);
      final choice = find.text('Choose ${pathway.label.toLowerCase()}');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(
        tester.widget<RegisterPage>(find.byType(RegisterPage)).pathway,
        pathway,
      );
      expect(find.text('Create account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
