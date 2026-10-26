# Teacher changes merged — October 3, 2026

The working project is `/Users/suricharlu/Desktop/suri-vetconnect-main`.
Teacher source: `/Users/suricharlu/Desktop/suri-vetconnect-main(v2)`.

## Included

- ZIP lookup service and bundled ZIP centroid data.
- Business map ZIP filter, area-only search, map pan/zoom refresh, zoom controls, separated overlapping pins, search-result markers, and clear-results control.
- Smaller map search field and the option to supply an area-specific search function.
- New Firebase helper methods for ZIP-based lookup and keyword matching.
- Teacher's winged shield logo, generated Android/iOS launcher icons, and icon generation configuration.
- Missing iOS Xcode project files from the teacher's copy.
- Business scraper updates, postal-code backfill, and street-address geocoding functions.
- Donation text uses the requested 80% charity / 20% app upkeep split.

## Preserved from the current project

- Updated navigation, Home, Careers, registration, settings, create-business and AI-search pages, and shared visual components.
- Existing website and platform folders.
- The Donate page layout, QR fallback, and removal of the direct-donation section.
- Map-controller cleanup, a visible map while loading, an eight-second optional GPS timeout, and loading failure/Retry behavior.
- Existing business/job query timeouts and errors. New ZIP queries also time out and expose errors to the Retry UI instead of silently returning an empty list.

The map was manually combined because its loading behavior overlapped with the teacher's ZIP changes. Late GPS results do not replace an already selected ZIP. Overlapping ZIP requests discard stale results. Search ignores late results after clearing or leaving the page.

## Validation

- `flutter pub get`: completed.
- `flutter test test/teacher_merge_test.dart --no-pub`: all five tests passed. Covers the real bundled ZIP asset, ZIP+4 input, ZIPs missing from the table, query caps/distance ordering, area-search routing, clearing an outstanding search, and leaving during a failed search.
- `flutter build apk --debug --no-pub`: succeeded.
- Targeted Dart analysis: no compile errors; existing unused-method and style/logging notices remain.
- `node --check` on the four imported/updated backend JavaScript files: passed.
- `plutil -lint ios/Runner.xcodeproj/project.pbxproj`: passed.
- Source hashes confirm the only existing Dart files changed are `business_home.dart`, `business_search.dart`, `firebase_helper.dart`, and `donate_page.dart`. All other original Dart files are unchanged.

The existing counter-template test in `test/widget_test.dart` was not part of this focused test run. No iOS build or live database migration was performed. The Android build still reports pre-existing future-support warnings for Gradle, AGP, and Kotlin.

## Separate live/platform setup

The Firebase function files are merged locally. Deployment and database backfill/geocoding have not been run, and the remote deployment state has not been checked. ZIP-based map results depend on `known_businesses.business.postalCode`; older records without that field need the supplied backfill. Street geocoding requires the `GOOGLE_GEOCODING_API_KEY` secret. The teacher's new callable maintenance functions do not check caller authorization; add appropriate administrator restrictions before deploying them.

The restored iOS project uses bundle identifier `com.codingminds.vetconnect` and the teacher's signing team. Existing `lib/firebase_options.dart` still specifies `com.projectname.flutterproject` for iOS. Confirm the intended Firebase iOS app and signing account before running/releasing on iPhone; no app identifiers or credentials were guessed during this merge.

## Backup

Original changed files are in `.teacher-merge-backup/20261003-233005/`. Its `manifest.json` records original and resulting hashes, plus which files were newly added. `lib-before.json` records all pre-merge Dart source hashes. This backup is a partial snapshot of the files touched by the merge, not a second runnable project.
