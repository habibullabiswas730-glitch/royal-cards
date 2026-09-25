# Royal Cards

A polished Flutter Android app for virtual-coin card-game practice.

## Included
- Login / local player profile
- Persistent virtual coin balance
- Add/remove virtual coins for testing
- Practice card game flow and rewards
- Leaderboard
- Friends and invite UI
- Wallet and activity history
- Profile and settings
- Responsive Material 3 UI
- GitHub Actions Android APK build

## Build APK
The repository intentionally does not contain the generated Android folder. The GitHub Actions workflow creates the Android project and builds the APK.

Locally, after installing Flutter:

```bash
flutter pub get
flutter create --platforms=android .
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Important
This version is virtual-coins/practice only. It does not implement real-money deposits, withdrawals, gambling, or wagering.
