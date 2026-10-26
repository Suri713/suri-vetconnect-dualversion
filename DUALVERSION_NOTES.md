# Implementation notes

## Account pathways

- **Veteran business owner:** business listings, careers, search, and donations.
- **General user:** business discovery, AI search, donations, and personal settings.
- Guests use the general-user pathway without account or business writes.
- The selection is stored in `users/{uid}.accountPathway` and can be changed in Settings.

## Business profiles

Profiles are stored in `users/{uid}.business` and searched alongside imported `known_businesses` records. Creating a profile requires a five-digit ZIP and a ten-digit DoD ID format check. This does not verify veteran status. The raw DoD ID is not saved to Firebase or logs.

## Nearby search

AI search uses the selected map area, ZIP, or device location and filters results to a 20-mile radius. ZIP-centroid coordinates are approximate. Recommendation ranking uses interests, search history, viewed businesses, and distance.

## Tests

Pathway, search, and upload tests are in `test/`. The live integration test is `integration_test/dualversion_live_test.dart`.
