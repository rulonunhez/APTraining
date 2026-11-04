# Firebase setup

The Firebase project is `APTraining` (`aptraining-22d59`). Register the Android and iOS apps with the application ID `com.aptraining.app` and enable Crashlytics.

From PowerShell, install and authenticate the Firebase tools if needed, then configure the app from this folder:

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
$env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"
Set-Location C:\ProyectoGymApp\APTraining\mobile
flutterfire configure --project=aptraining-22d59 --platforms=android,ios
```

FlutterFire generates `lib/firebase_options.dart` and the platform configuration files. Keep those generated files in this repository. Until configuration is complete, the app catches the missing Firebase configuration and continues with local error logging; Crashlytics will not receive reports.

After configuring, run `flutter pub get` and build the app. In Firebase Console, enable Crashlytics for both registered apps.
