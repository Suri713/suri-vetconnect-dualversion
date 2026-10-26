# VeteranConnect — dual pathway version

Open this folder in Android Studio: **suri-vetconnect-dualversion**.
Choose the **VeteranConnect Dual Version** run configuration and an Android emulator.

```sh
flutter pub get
flutter run -d emulator-5554
```

New accounts choose **Veteran pathway (Veteran business owner)** or **User (All users)**.
Existing accounts choose on their next login if they have not selected a pathway yet.
Change the choice later in Settings.

This is a separate source project using the same Firebase backend and Android app ID.
Running it on the same emulator updates that installed app. It does not edit the original source folder.
The internal Dart package stays `vetconnect` (imports and Firebase configuration are still compatible).

See [DUALVERSION_NOTES.md](DUALVERSION_NOTES.md) for details.
