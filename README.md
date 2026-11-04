# APTraining

APTraining contains a Flutter client in `mobile/` and a Spring Boot API in `backend/`.

## Mobile error reporting

The Flutter app reports uncaught errors, explicitly recorded operation failures, and backend HTTP 5xx responses to Firebase Crashlytics. Without Firebase platform configuration, the app still starts and writes diagnostic details to Flutter/IDE output or Android Logcat.

### One-time Firebase setup

1. Create or select a Firebase project and register the Android and iOS apps using the application/bundle identifiers in the Flutter project.
2. From a terminal with Firebase CLI authentication, run `dart pub global activate flutterfire_cli` and then `flutterfire configure` from `mobile/`. Select Android and iOS and the Firebase project. This generates Firebase app configuration and adds the required Crashlytics Android Gradle plugin.
3. Enable Crashlytics in the Firebase console. Add `mobile/android/app/google-services.json` and the iOS `GoogleService-Info.plist` to the Runner target as directed by FlutterFire. Do not commit private signing credentials; Firebase client configuration is not a server secret.
4. Rebuild and install the app. Verify a non-fatal test event with `--dart-define=CRASHLYTICS_SMOKE_TEST=true`, then rebuild normally without that flag. The test event should appear in Firebase Console → Crashlytics.

Crashlytics is only enabled when Firebase initializes successfully. Error messages are redacted before reporting: Crashlytics receives the error type, stack trace, and a fixed context; HTTP 5xx events include method, status, and `requestId`, but not request URLs or bodies. Local Flutter logs retain the original exception for debugging.

### Roadmap to centralized logs

1. **Crashlytics:** complete the Firebase project/app registration above, then run the smoke test on a real Android/iOS build and verify events in the Firebase console.
2. **Backend:** ECS already forwards backend console output to CloudWatch Logs at `/ecs/aptraining-dev/backend` with a 7-day retention period. Increase retention if needed and confirm a request's `requestId` can be searched there.
3. **Correlate incidents:** when Crashlytics reports a backend 5xx, use its `requestId` to find the matching backend log event in CloudWatch.
4. **Production readiness:** register a separate Firebase app/project for production if you need environment isolation; set appropriate Crashlytics data retention/access, protect the AWS CloudWatch console with least-privilege IAM, and configure longer CloudWatch retention for production.
5. **Optional unified search:** if one console is required later, configure Firebase Crashlytics export to BigQuery/Cloud Logging or forward AWS logs to a chosen observability platform. The current setup intentionally keeps mobile crash diagnostics in Firebase and backend operational logs in CloudWatch.

See [Crashlytics DEV setup](mobile/docs/crashlytics-dev.md) for the setup and smoke-test procedure.

## Backend logs

`LOG_DIR` is read in `backend/src/main/resources/application.yaml` as `logging.file.path`, defaulting to `logs`. It controls the rolling log file produced by Logback; it is a filesystem path inside the backend process/container, not an S3 destination.

The AWS dev deployment runs the backend on ECS Fargate. Terraform configures the container's stdout/stderr to go to the CloudWatch Logs group `/ecs/aptraining-dev/backend` (7-day retention). Use CloudWatch Logs for centralized AWS log storage and search; ECS already forwards the console logs there. S3 is intended for object/archive storage, not as a live Logback directory. In ECS, a `LOG_DIR` path inside the container is ephemeral unless backed by a persistent filesystem, so do not point it at an S3 URI. For the current deployment, rely on CloudWatch for durable operational logs; use a local path or mounted volume for the rolling file only when that local copy is needed.
