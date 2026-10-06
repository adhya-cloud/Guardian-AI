# AGENTS.md

## Snapshot

Guardian is a Flutter personal-safety app (Android-first). All logic lives in
`lib/state/safety_controller.dart`. Platform access goes through the
interfaces in `lib/services/`, so everything is testable with the fakes in
`test/fakes.dart`. Native Android features are in
`android/app/src/main/kotlin/com/guardian/safety/NativeBridge.kt`
(method channel `guardian/native`).

## Conventions

- **Strings:** all user-facing text uses `AppStrings.of(context).t('key')`. Add every new key to both `en` and `hi` in `lib/core/strings.dart`. `test/core_test.dart` fails if a key is missing.
- **SMS texts:** these live in `lib/core/messages.dart`. Keep the English messages plain ASCII, because it keeps SMS segments small.
- **Delivery honesty:** only mark a message `sent` when the OS confirms it. The composer fallback is recorded as `composer`, never as `sent`.
- **Nothing is sent without the user acting:** SOS always goes through the countdown. Journey escalation only happens after the user started a journey.
- **Tests:** new platform features need an interface in `services/`, a fake in `test/fakes.dart`, and controller tests using `fake_async`.

## Validation (run before finishing)

```bash
flutter analyze        # must report no issues
flutter test           # must pass
cd ../tracking-server && npm test
```
