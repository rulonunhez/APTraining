# Activar Crashlytics para la APK DEV

La app Flutter está preparada para reportar fallos a Firebase Crashlytics. El backend permanece independiente: ECS envía sus logs a CloudWatch Logs.

## Configuración inicial de Firebase

1. El proyecto Firebase ya está creado: **`aptraining-22d59`**. En Firebase Console, habilita Crashlytics.
2. Los identificadores de aplicación son:
   - Android: `com.aptraining.app`.
   - iOS: `com.aptraining.app`.
   Son dos registros de app dentro del mismo proyecto Firebase.
3. En PowerShell, instala las herramientas si todavía no están instaladas y autentícate:

   ```powershell
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   $env:PATH += ";$env:LOCALAPPDATA\Pub\Cache\bin"
   firebase projects:list
   ```

   Comprueba que la lista incluya `aptraining-22d59`. Si `firebase` o `flutterfire` no se reconocen después de instalar, cierra y vuelve a abrir PowerShell.
4. Desde `mobile/`, ejecuta FlutterFire para crear/vincular los registros Android e iOS:

   ```powershell
   Set-Location C:\ProyectoGymApp\APTraining\mobile
   flutterfire configure --project=aptraining-22d59 --platforms=android,ios
   ```

   Confirma en los prompts los IDs Android `com.aptraining.app` e iOS `com.aptraining.app`. El CLI genera `lib/firebase_options.dart` y configura los plugins de plataforma que necesite Crashlytics. La app inicializa Firebase con `DefaultFirebaseOptions.currentPlatform`.
5. Comprueba que se hayan generado `mobile/lib/firebase_options.dart` y `mobile/android/app/google-services.json`. En esta configuración FlutterFire aporta las opciones de iOS mediante `firebase_options.dart`; si más adelante el flujo nativo de Xcode solicita `GoogleService-Info.plist`, añádelo al target Runner desde Firebase Console. No subas credenciales de firma ni secretos de servidor al repositorio.
6. Ejecuta `flutter pub get` y reconstruye la app. La inicialización de Firebase es intencionadamente tolerante a la ausencia de configuración: hasta completar estos pasos, la app sigue arrancando y conserva el logging local.

## Verificar la APK DEV

Para probar solo Crashlytics sin iniciar AWS, ejecuta `flutter pub get` desde `mobile/` y compila desde la raíz con `.\mobile\scripts\build-dev-apk.ps1 -SmokeTest -ApiBaseUrl 'https://example.invalid'`. La URL es un placeholder HTTPS para que la app supere la validación de release; no es una API real.

Desde la raíz del repositorio, con AWS SSO configurado y la API demo habilitada:

```powershell
$env:AWS_PROFILE = 'aptraining-dev'
aws sso login --profile aptraining-dev
.\mobile\scripts\build-dev-apk.ps1 -SmokeTest
adb install -r .\mobile\build\app\outputs\flutter-apk\app-release.apk
```

Abre la app, ciérrala y vuelve a abrirla para que Crashlytics envíe el evento no fatal; espera unos minutos. En Firebase Console → Crashlytics debe aparecer `APTraining Crashlytics DEV smoke test`. Para compilar la APK normal apuntando al backend AWS, ejecuta el script sin `-SmokeTest`; entonces toma `demo_api_url` desde Terraform y requiere que la API demo esté habilitada.

En un error HTTP 5xx, Crashlytics incluye método, estado HTTP y `requestId`. Busca el mismo `requestId` en CloudWatch Logs, grupo `/ecs/aptraining-dev/backend`, para correlacionar el fallo móvil con el stack trace del backend.

La app no envía el mensaje original de la excepción, URL ni body HTTP. Crashlytics recibe el tipo de error, stack trace y contexto fijo; los detalles completos quedan en logs locales de Flutter/IDE o Android Logcat.

## Producción

Registra las apps release correctas y valora un proyecto Firebase separado para producción. Antes de publicar, verifica la retención y permisos de Crashlytics, configura una retención CloudWatch acorde al entorno y comprueba que el flujo de build incluya la configuración Firebase de release.
