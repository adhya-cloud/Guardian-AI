# Guardian — Flutter app

See the [repository README](../README.md) for features, setup and the tracking server.

## Structure

```
lib/
  main.dart                    wires real services into SafetyController
  core/                        strings (en/hi), SMS message templates, phone utils, helplines, theme
  models/                      Profile/AppSettings, TrustedContact, Incident, GeoPoint, Place
  services/                    platform boundaries, each behind an interface:
    device_bridge.dart           SMS, calls, contact picker, torch, siren, ringtone (Kotlin channel)
    location_service.dart        geolocator + Android foreground service
    permissions.dart             permission_handler
    places_service.dart          OpenStreetMap Overpass API
    tracking_client.dart         optional live-map server
    local_notifications.dart     reminders / alerts
    shake_detector.dart          accelerometer shake detection
    storage.dart                 encrypted JSON state
  state/safety_controller.dart app state + all safety logic (SOS, journey, live share)
  ui/                          screens (home, sos, map, contacts, history, settings, tools, onboarding)
android/app/src/main/kotlin/com/guardian/safety/NativeBridge.kt   native Android features
test/                          fakes + controller, core and widget tests
```

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```
