import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetconnect/business/pages/business_search.dart';
import 'package:vetconnect/services/zip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled ZIP data supports ZIP+4 and nearby lookup', () async {
    final service = await ZipService.instance();
    final center = service.centroidOf(' 33602-1234 ');
    expect(center, isNotNull);
    expect(service.nearestZip(center!.$1, center.$2), '33602');
    expect(service.zipsAroundZip('33602'), contains('33602'));
    expect(service.centroidOf('invalid'), isNull);
    // A ZIP missing from the bundled table can still be queried directly.
    expect(service.zipsAroundZip('21797'), ['21797']);
  });

  test(
    'nearby ZIPs are ordered by distance and respect the query cap',
    () async {
      final service = await ZipService.instance();
      final center = service.centroidOf('10001')!;
      final zips = service.zipsWithin(
        center.$1,
        center.$2,
        milesRadius: 50,
        limit: 30,
      );
      expect(zips, hasLength(30));
      final distances = zips.map((zip) {
        final point = service.centroidOf(zip)!;
        return ZipService.milesBetween(
          center.$1,
          center.$2,
          point.$1,
          point.$2,
        );
      }).toList();
      expect(distances, orderedEquals([...distances]..sort()));
      expect(distances.last, lessThanOrEqualTo(50));
    },
  );

  test(
    'missing ZIP gains a session-only center from business coordinates',
    () async {
      final service = await ZipService.instance();
      const missingZip = '00001';
      expect(service.centroidOf(missingZip), isNull);
      service.rememberBusinessLocation(missingZip, 39.33118, -77.06861);
      expect(service.centroidOf(missingZip), (39.33118, -77.06861));
      expect(service.zipsAroundZip(missingZip), contains(missingZip));
      service.rememberBusinessLocation(missingZip, 0, 0);
      expect(service.centroidOf(missingZip), (39.33118, -77.06861));
    },
  );

  test(
    'fallback centers reject invalid coordinates and preserve known ZIPs',
    () async {
      final service = await ZipService.instance();
      final existing = service.centroidOf('33602');
      service.rememberBusinessLocation('33602', 0, 0);
      expect(service.centroidOf('33602'), existing);
      service.rememberBusinessLocation('00002', double.nan, 0);
      service.rememberBusinessLocation('00002', 91, 0);
      service.rememberBusinessLocation('00002', 0, 181);
      expect(service.centroidOf('00002'), isNull);
    },
  );

  testWidgets('area search uses its supplied lookup and delivers results', (
    tester,
  ) async {
    String? query;
    List<Map<String, dynamic>>? results;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessSearch(
            dense: true,
            onSearch: (value) async {
              query = value;
              return [
                {'id': 'local', 'name': 'Local coffee'},
              ];
            },
            onResultsChanged: (value) => results = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), ' coffee ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(query, 'coffee');
    expect(results?.single['id'], 'local');
  });

  testWidgets('clearing search discards an outstanding result', (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>>? results;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BusinessSearch(
            onSearch: (_) => pending.future,
            onResultsChanged: (value) => results = value,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    pending.complete([
      {'id': 'stale'},
    ]);
    await tester.pumpAndSettle();
    expect(results, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'leaving during a failed search does not update a disposed widget',
    (tester) async {
      final pending = Completer<List<Map<String, dynamic>>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BusinessSearch(onSearch: (_) => pending.future)),
        ),
      );
      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpWidget(const SizedBox());
      pending.completeError(StateError('Connection interrupted'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
