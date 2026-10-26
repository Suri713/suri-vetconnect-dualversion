# VeteranConnect dual pathway version

This is a separate Android Studio / Flutter project copied from suri-vetconnect-main.
Open this project root in Android Studio and select an Android emulator.
The Dart package and mobile application IDs stay compatible with the existing Firebase configuration.
This project uses the same Firebase backend as the original app.

## Account pathways
- New accounts choose a pathway after reading the mission, before signing up.
- Existing accounts without a saved pathway choose at their next login.
- The choice is stored as users/{uid}.accountPathway and can be changed in Settings.
- User: Home, Explore (including AI search), Donations, personal profile settings.
- Veteran business owner: those features plus Create, Careers, business settings.
- Guest sessions use the User pathway and cannot write accounts or businesses.
- These are product pathways, not proof of veteran status or administrative roles.

## Business creation and privacy
- Creating a business requires a 10-digit DoD ID input and a 5-digit business ZIP.
- The ID checks format only. No verification provider is integrated. The raw number
  is not written to Firebase or logs, and is cleared after submission.
- Business ownership is self-reported; no verified badge is shown.
- Business saves write to users/{uid}.business, with a whitelisted business
  object and businessSearchPrefixes. The map, keyword search, and AI search read
  both these app-created profiles and imported known_businesses records.
- Each app-created entry contains search prefixes and a ZIP so the map and search can find it.
- The supplied Firebase rules permit these reads and owner-only user-document writes.
  No rules or Cloud Functions need to be deployed for this change. Those rules make
  user documents publicly readable, so no raw DoD ID is stored there.

## AI search
- Uses the selected map area, entered ZIP, or available device location.
- Fetches latitude-bounded directory candidates with pagination and filters by
  actual coordinate distance before showing results. No global fallback.
- Results are at most 20 miles from that center. Imported ZIP-centroid locations
  remain approximate; exact business street locations depend on directory data.

## Existing photo limitation
Business image selection is retained. Previous live checks found the configured
Firebase Storage bucket returns 404. Photo uploads require Storage configuration;
business creation without images does not depend on Storage.

## Verification completed
- 31 local Flutter tests passed, including both onboarding choices, DoD format,
  data whitelisting, radius boundary tests, and the earlier app tests.
- Android integration passed for User and Veteran navigation and settings,
  pathway persistence through login, real Firebase business creation/edit/deletion,
  inclusion in map ZIP queries, and AI nearby lookup restricted to 20 miles.
- Test accounts and records from both the initial failed run and successful run
  were removed. Imported business records were not changed.
- Flutter analysis: no errors or warnings; existing style informational notices remain.
- Original project source and test hashes match the pre-change snapshot.
- Public directory writes were initially denied, as expected under the supplied rules.
  The final implementation reads user business profiles alongside imported listings,
  so it works with the existing Firebase rules without a deployment.

The previous version's live smoke test and Storage diagnostic are archived as text in verification/. The current live test is integration_test/dualversion_live_test.dart.
