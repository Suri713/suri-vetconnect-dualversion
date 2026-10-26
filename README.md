# VeteranConnect

A Flutter app for finding veteran-owned businesses and supporting the veteran community. Built with Firebase, Google Maps, and OpenAI-powered search.

- Search businesses by keyword, ZIP code, or map area.
- Create business profiles with contact details and photos.
- Browse veteran-friendly careers and donation resources.

Veteran business owners can manage listings and access careers. General users can explore businesses, use AI search, and donate. Accounts can switch pathways in Settings.

## Run locally

Install Flutter and configure Firebase for your environment, then run:

```sh
flutter pub get
flutter run
```

Cloud Functions need their own deployment and API secrets. Business photos require a working Firebase Storage bucket.

See [implementation notes](DUALVERSION_NOTES.md) for pathway and search details.
