import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vetconnect/business/widgets/business_directions_button.dart';
import 'package:vetconnect/services/business_directions.dart';

void main() {
  testWidgets('directions button launches an external Maps URL', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    MethodCall? launch;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      launch = call;
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BusinessDirectionsButton(
            business: {
              'name': 'YourOwn',
              'locationRaw': 'Palo Alto, CA 94303',
              'geocodeSource': 'census-zcta-centroid',
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Get directions'));
    await tester.pumpAndSettle();
    expect(launch?.method, 'launch');
    final args = launch!.arguments as Map;
    expect(
      Uri.parse(args['url'] as String).queryParameters['destination'],
      'YourOwn, Palo Alto, CA 94303',
    );
    expect(args['useWebView'], isFalse);
    expect(args['useSafariVC'], isFalse);
  });

  testWidgets('unavailable Maps handler displays a recoverable error', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BusinessDirectionsButton(
            business: {'lat': 37.45, 'lng': -122.11},
          ),
        ),
      ),
    );
    await tester.tap(find.text('Get directions'));
    await tester.pumpAndSettle();
    expect(find.text('UNABLE TO OPEN DIRECTIONS'), findsOneWidget);
  });

  test('YourOwn resolves by name and area instead of its ZIP centroid', () {
    final uri = BusinessDirections.uriFor({
      'name': 'YourOwn',
      'locationRaw': 'Palo Alto, CA 94303',
      'geocodeSource': 'census-zcta-centroid',
      'lat': 37.45788,
      'lng': -122.1151,
    })!;
    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters['api'], '1');
    expect(uri.queryParameters['destination'], 'YourOwn, Palo Alto, CA 94303');
    expect(uri.queryParameters.containsKey('origin'), isFalse);
  });

  test(
    'street address includes the business and safely encodes punctuation',
    () {
      final uri = BusinessDirections.uriFor({
        'name': 'A & B #1',
        'streetAddress': '123 Main St',
        'city': 'Tampa',
        'state': 'FL',
        'postalCode': '33602',
      })!;
      expect(
        Uri.parse(uri.toString()).queryParameters['destination'],
        'A & B #1, 123 Main St, Tampa, FL, 33602',
      );
    },
  );

  test(
    'precise geocoded address takes precedence over outdated postal text',
    () {
      expect(
        BusinessDirections.addressLabel({
          'geocodeFormattedAddress': '123 Main St, Tampa, FL 33602, USA',
          'geocodeAccuracy': 'rooftop',
          'locationRaw': 'Tampa, FL 00000',
        }),
        '123 Main St, Tampa, FL 33602, USA',
      );
    },
  );

  test('manual pin can supply directions without an address', () {
    expect(
      BusinessDirections.uriFor({
        'lat': 27.9,
        'lng': -82.4,
      })!.queryParameters['destination'],
      '27.9,-82.4',
    );
  });

  test(
    'unusable locations and unnamed ZIP centroids cannot give directions',
    () {
      expect(BusinessDirections.uriFor({}), isNull);
      expect(BusinessDirections.uriFor({'lat': 91, 'lng': -82}), isNull);
      expect(BusinessDirections.uriFor({'lat': double.nan, 'lng': 0}), isNull);
      expect(
        BusinessDirections.uriFor({
          'geocodeSource': 'census-zcta-centroid',
          'locationRaw': 'Palo Alto, CA 94303',
          'lat': 37.45788,
          'lng': -122.1151,
        }),
        isNull,
      );
    },
  );
}
