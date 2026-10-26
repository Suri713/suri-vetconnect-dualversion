// Explicit verification: creates one temporary Firebase Auth account and business,
// exercises the real save/map/edit/delete flow, and removes all test records.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vetconnect/business/business_handler.dart';
import 'package:vetconnect/business/pages/create_business.dart';
import 'package:vetconnect/constants.dart';
import 'package:vetconnect/firebase_options.dart';
import 'package:vetconnect/home_page.dart';
import 'package:vetconnect/route_page.dart';
import 'package:vetconnect/services/account_pathway.dart';
import 'package:vetconnect/services/firebase_helper.dart';
import 'package:vetconnect/services/location_manager.dart';
import 'package:vetconnect/settings/settings.dart';
import 'package:vetconnect/theme/art_deco_theme.dart';

Future<void> settleSettings(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump(const Duration(milliseconds: 200));
    if (find.text('Your account').evaluate().isNotEmpty) return;
  }
  fail('Settings did not finish loading');
}

Widget screen(Widget child) =>
    MaterialApp(theme: ArtDecoTheme.build(), home: child);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('dual pathways and live business persistence', (tester) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final app = await Firebase.initializeApp(
      name: 'dualversion-verification',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    final store = FirebaseFirestore.instanceFor(app: app);
    // The named test app is separate from the normal app's signed-in account.
    // Only delete a stale account if its reserved test email proves its origin.
    final stale = auth.currentUser;
    if (stale != null) {
      final isTestAccount = RegExp(
        r'^dualversion-check-[0-9]+@example\.invalid$',
      ).hasMatch(stale.email ?? '');
      if (!isTestAccount || stale.emailVerified) {
        throw StateError(
          'Refusing cleanup: this is not our temporary test account.',
        );
      }
      await store.collection('users').doc(stale.uid).delete();
      await stale.delete();
      debugPrint('CLEANUP: previous temporary verification account removed.');
    }
    String? uid;
    final unique = DateTime.now().microsecondsSinceEpoch;
    final email = 'dualversion-check-$unique@example.invalid';
    final password = 'Check-$unique-Only!';
    try {
      final helper = await FirebaseHelper.register(
        email,
        password,
        pathway: AccountPathway.user,
        auth: auth,
        store: store,
      );
      expect(helper, isNotNull, reason: 'Temporary Firebase Auth registration');
      uid = helper!.userId;
      Constants.firebaseHelper = helper;
      Constants.locationManager = await LocationManager.init();
      Constants.businessHandler = (await BusinessHandler.init())!;
      expect(helper.pathway, AccountPathway.user);
      final savedProfile = await store
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      expect(savedProfile.data()?['accountPathway'], 'user');
      expect(
        await helper.saveBusiness({'name': 'Should never be written'}),
        isFalse,
      );
      await tester.pumpWidget(screen(const RoutePage()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Create'), findsNothing);
      expect(find.text('Careers'), findsNothing);
      expect(find.text('Create your profile'), findsOneWidget);
      await tester.pumpWidget(screen(const SettingsPage()));
      await settleSettings(tester);
      expect(find.text('Business Settings'), findsNothing);
      expect(find.text('UPLOAD PROFILE PHOTO'), findsNothing);
      await tester.pumpWidget(screen(const CreateBusiness()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dod-id')), findsNothing);

      expect(await helper.setPathway(AccountPathway.veteran), isTrue);
      await auth.signOut();
      final veteran = await FirebaseHelper.login(
        email,
        password,
        auth: auth,
        store: store,
      );
      expect(
        veteran?.pathway,
        AccountPathway.veteran,
        reason: 'Pathway restored after login',
      );
      Constants.firebaseHelper = veteran!;
      Constants.businessHandler = (await BusinessHandler.init())!;
      await tester.pumpWidget(screen(const RoutePage()));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Careers'), findsOneWidget);
      expect(find.text('Create your veteran business profile'), findsOneWidget);

      final saved = await Constants.businessHandler.createBusiness(
        'Temporary verification coffee $unique',
        '2026-10-04',
        const LatLng(37.45788, -122.1151),
        'Temporary automated test; removed after verification.',
        dodId: '0000000000',
        postalCode: '94303',
      );
      expect(saved, isTrue, reason: 'Real Firestore business save');
      final userDoc = await store
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      expect(userDoc.data()?['business']['id'], Constants.businessHandler.id);
      expect(userDoc.data()?['business']['dodId'], isNull);
      expect(userDoc.data()?['businessSearchPrefixes'], contains('coffee'));
      final nearby = await veteran.getBusinessesByZips(['94303']);
      expect(
        nearby.any((b) => b['id'] == Constants.businessHandler.id),
        isTrue,
        reason: 'Map ZIP query returns the new business',
      );
      final aiMatches = await veteran.searchBusinessesWithinRadius(
        'coffee',
        const LatLng(37.45788, -122.1151),
      );
      expect(
        aiMatches.any((b) => b['id'] == Constants.businessHandler.id),
        isTrue,
      );
      expect(aiMatches.every((b) => (b['distanceMiles'] as num) <= 20), isTrue);
      final id = Constants.businessHandler.id;
      expect(
        await Constants.businessHandler.updateBusiness(
          'Updated verification $unique',
          const LatLng(37.45788, -122.1151),
          'Updated test',
          postalCode: '94303',
        ),
        isTrue,
      );
      final updated = await store
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      expect(
        updated.data()?['business']['name'],
        'Updated verification $unique',
      );
      await tester.pumpWidget(screen(const SettingsPage()));
      await settleSettings(tester);
      expect(find.text('Business Settings'), findsOneWidget);
      expect(find.text('UPLOAD PROFILE PHOTO'), findsNothing);
      expect(await Constants.businessHandler.deleteBusiness(), isTrue);
      final removed = await store
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      expect(removed.data()?['business'], isNull);
      expect(
        (await veteran.getBusinessesByZips([
          '94303',
        ])).any((b) => b['id'] == id),
        isFalse,
      );
      debugPrint(
        'VERIFIED: both pathways, persisted choice, Firebase create/edit/delete, map lookup, and 20-mile filtering.',
      );
      await tester.pumpWidget(screen(const HomePage()));
    } finally {
      final created = auth.currentUser;
      if (uid != null &&
          created?.uid == uid &&
          created?.email == email &&
          !created!.emailVerified) {
        await store.collection('users').doc(uid).delete();
        await created.delete();
        debugPrint(
          'CLEANUP: temporary business, profile, and Auth account removed.',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await store.terminate();
      await app.delete();
    }
  });
}
