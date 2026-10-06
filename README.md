# Guardian — personal safety app for India

Guardian is an Android-first Flutter app that gets help to you fast. SOS alerts
go out **by SMS**, so they work without mobile data. The app also shares your
location, watches over your journeys, and shows the nearest police stations and
hospitals on a live map.

```
guardian_ai_mobile/   Flutter app (Android primary, iOS supported with fallbacks)
tracking-server/      Optional Node.js live-map server for real-time location links
docker-compose.yml    Runs the tracking server + MongoDB
```

## Features

| Feature | How it works |
|---|---|
| **SOS** | Tap the SOS button, or shake the phone, to start a cancellable 3/5/10 s countdown. The app then SMSes every trusted contact your name, a Google Maps link, GPS accuracy, time, battery level and optional medical info. Each message's delivery is confirmed by Android (sent / failed, per contact). |
| **SOS follow-up** | Location keeps updating in the background (foreground service) and contacts get an update SMS every N minutes when you've moved. Optional auto-call to your primary contact or 112, a loud siren (alarm stream at full volume), and a flashlight strobe. "I'm safe" ends it and tells everyone. |
| **Journey check-in** | Set a destination and a time limit. Guardian tracks the trip, reminds you 2 minutes before the deadline, and if you don't check in it **automatically** alerts your contacts with your last location, then stays in SOS mode. You can extend the timer or finish early ("I've arrived"). |
| **Live location sharing** | Share for 15 min to 8 h. If a tracking server is configured, contacts get a **live map link** that updates every few seconds. Otherwise they get an SMS location update every N minutes. It stops automatically. |
| **Interactive map** | An OpenStreetMap map (no API key needed) with your live position and accuracy circle. It shows nearby **police stations, hospitals, pharmacies and fire stations** from OpenStreetMap data, with filters, "search this area", distances, one-tap directions, calls and sharing. |
| **Trusted contacts** | Pick from the phone book (no contacts permission needed) or type a number. Set a primary contact, choose who gets SOS alerts, and send a test/intro SMS. Indian number formats are handled. |
| **Helplines** | One-tap dialling of 112, 100, 1091, 181, 108, 102, 101, 1098, 1930 and 14567. |
| **Fake call** | A realistic incoming call using your real ringtone and vibration, after a delay you choose, to help you leave an uncomfortable situation. |
| **History** | Every SOS, journey and live share, with the route drawn on a map and the delivery status of every message. |
| **Languages** | Full English and Hindi UI and alert messages. |
| **Privacy** | Profile, contacts and history are stored encrypted on the phone (Android Keystore / iOS Keychain). No account and no analytics. The optional server only sees location points during an active share. |

## Tech stack

**App:** Flutter 3.44 / Dart 3.12
- **Maps:** `flutter_map` + OpenStreetMap tiles
- **Nearby places:** Overpass API
- **Location:** native Android `LocationManager` bridge (with a foreground service while tracking)
- **State:** `provider`
- **Platform services:** `permission_handler`, `sensors_plus` (shake), `flutter_local_notifications`, `flutter_secure_storage`, `share_plus`, `url_launcher`, `http`
- **Custom Kotlin method channel:** direct SMS with sent-confirmation, the system contact picker, direct calls, torch, synthesized siren, ringtone and battery level

**Tracking server:** Node 20+ with Express 4, `helmet` and `express-rate-limit`. Storage is in-memory, or MongoDB if configured. The web viewer uses Leaflet, served locally with no CDN.

## Do I need the server?

**No.** The app works on its own. Everything below works with **no server at
all**: SOS by SMS with your location, automatic location-update SMS, journey
check-in and its automatic alert, the map with nearby police and hospitals,
helplines, fake call, siren, flashlight strobe and history.

The tracking server adds one thing: a **live map link** that contacts can open
in a browser. Without it, live location sharing sends an SMS with your
location every few minutes instead.

## Run the app for development

Requirements: Flutter 3.44+, Android SDK (API 36 platform), JDK 17.

```bash
cd guardian_ai_mobile
flutter pub get
flutter run            # on a connected Android phone or emulator
```

**Testing SMS on an emulator:** add a contact with the emulator's own number,
`+15555215554`. The app really sends the SMS; it appears as a sent message in
the emulator's Messages app. Set a fake GPS position with
`adb emu geo fix <longitude> <latitude>`.

## Install the app on a phone

There are two editions of the same app. Both are signed with the same key, so
you can switch between them later without losing data.

| | **Full** (`app-full-release.apk`) | **Lite** (`app-lite-release.apk`) |
|---|---|---|
| SOS alert | SMS sent automatically in the background | SMS app opens pre-filled; you press **Send** |
| Location-update SMS during SOS | Automatic, every few minutes | Tap **Send alert again** (or use a live-map link) |
| Missed journey check-in | Contacts alerted automatically | You get a notification and the SMS app opens |
| Everything else | ✓ | ✓ |
| How to install | **USB only** (see below) | Any way: WhatsApp, Drive, browser, file manager |

**Why two editions?** In India, Google Play Protect's *enhanced fraud
protection* automatically blocks installing apps with SMS permissions from
WhatsApp, browsers or file managers ("App blocked to protect your device").
There's no "Install anyway" for this. Installs over USB aren't affected, so
the full edition goes on over USB, and the Lite edition, which has no SMS or
call permissions, installs normally from anywhere.

### Build

```bash
cd guardian_ai_mobile
flutter build apk --release --flavor full
flutter build apk --release --flavor lite
```

The APKs are written to `guardian_ai_mobile/build/app/outputs/flutter-apk/` and
work on any Android 7.0+ phone. If a rebuilt APK seems to contain old code, run
`flutter clean` first.

### Full edition, over USB (recommended for your own phone)

1. On the phone: *Settings → About phone* → tap **Build number** 7 times, then
   *Settings → System → Developer options* → turn on **USB debugging**.
2. Connect the phone to the PC with a USB cable and tap **Allow** on the phone.
3. Install:
   ```bash
   adb install -r guardian_ai_mobile/build/app/outputs/flutter-apk/app-full-release.apk
   ```
   (or `flutter install --flavor full` from `guardian_ai_mobile`). `adb` lives in
   `%LOCALAPPDATA%\Android\Sdk\platform-tools`.
4. Open Guardian, add contacts, allow Location, SMS, Phone and Notifications,
   then press **Send test SMS** on a contact. This needs a SIM with SMS
   balance, but no mobile data.

### Full edition installed from a file? Unblock SMS once

On Android 15 and newer, an app installed from a file (WhatsApp, Drive, a
browser, a file manager) can't get the SMS permission straight away. Tapping
Allow shows **"App was denied access to SMS"**, and Guardian shows
**Automatic SMS is off** with a **How to allow** button. To fix it:

1. In Guardian, tap **How to allow**, close Android's message, then tap **Open app settings**.
2. Tap **⋮** (top right) → **Allow restricted settings**, and confirm with your PIN or fingerprint.
3. Open **Permissions → SMS → Allow**, then go back to Guardian. It shows *SMS allowed*.

The ⋮ option only appears after Android has shown its "denied" message once,
which step 1 makes sure of. Installing over USB (above) avoids this entirely.
Until SMS is allowed, SOS still works: your SMS app opens with the alert ready
and you press Send.

### Lite edition, without a cable (e.g. for family members)

Send `app-lite-release.apk` by WhatsApp, Google Drive or email. Open it on the
phone, allow *Install unknown apps* for that app, and install. If Play Protect
warns that the app is unrecognised, choose **More details → Install anyway**.

### Signing key

Release builds are signed with `android/guardian-release.jks`, and its
passwords are in `android/key.properties`. Both files are git-ignored. **Back
them up somewhere safe:** updates to an installed app must be signed with the
same key, or users have to uninstall first, which deletes their data. A fresh
clone without these files falls back to the debug key.

## Run the tracking server (optional, for live-map links)

Your phone and your contacts' phones must be able to reach the server, and a
release build of the app only talks to it over **HTTPS**. So for real use,
deploy the server; a server on your PC is only for testing.

**Deploy for free on Render** (gives you an HTTPS address):
1. Push this project to a GitHub repository.
2. On [render.com](https://render.com), choose **New → Blueprint** and select the repository. It uses [`render.yaml`](render.yaml).
3. When it's live, copy the address (e.g. `https://guardian-tracking.onrender.com`).
4. In the app, open **Settings → Live-map server**, paste the address, and tap **Test**. It should say *Connected*. Then tap **Save**.

The free plan sleeps after 15 minutes without traffic, and waking takes about
a minute. If the server is asleep when you press SOS, the alert SMS still goes
out immediately with a Google Maps link; only the live-map link is left out.
Tap **Test** in settings before a trip to wake it. Any Node 20+ host with HTTPS
works too (Railway, Fly.io, a VPS). Set `NODE_ENV=production` and
`TRUST_PROXY_HOPS` as described in `tracking-server/.env.example`.

**Run locally for testing:**

```bash
cd tracking-server
npm install
npm start              # http://localhost:4000, in-memory store
```

Or, with MongoDB: `docker compose up --build` from the repository root.
Addresses to enter in the app:
- Android emulator: `http://10.0.2.2:4000`
- Real phone over USB: first run `adb reverse tcp:4000 tcp:4000`, then use `http://localhost:4000`
- A phone on the same Wi-Fi using `http://192.168.x.x:4000`: this only works with a debug build (`flutter run`), because release builds block plain HTTP to other addresses.

Contacts open links like `https://your-server/t/<token>`: a mobile web page with
a live map, an accuracy circle, the route travelled, battery level, and
"Directions" / "Call 112" buttons. Links are unguessable, expire with the share,
and are deleted about 1 h after it ends.

## Tests

```bash
cd guardian_ai_mobile && flutter analyze && flutter test
cd tracking-server && npm test
# MongoDB store integration test:
MONGO_TEST_URI=mongodb://localhost:27017/guardian_tracking_test npm test
```

## Platform notes and limits

- **Android** has every feature. Background SMS needs the SEND_SMS permission and a SIM with SMS service. Google Play restricts SEND_SMS to certain app categories, so for a Play Store release, declare the app as a safety/emergency app or fall back to the SMS composer.
- **iOS** doesn't allow apps to send SMS silently, so Guardian opens the Messages app pre-filled and you tap *Send*. Calls go through the dialer. Siren, strobe and the contact picker are Android-only.
- Shake-to-SOS works while the app is open. SOS, journey and live-share tracking keep running in the background, but if you force-close the app from the recents screen, Android stops them. A journey whose deadline passes while the app is closed is escalated as soon as the app opens again.
- Emergency numbers (112 etc.) always open the dialer: Android doesn't let apps auto-dial them.
- Nearby-place data comes from OpenStreetMap volunteers and can be incomplete. In an emergency, call 112.
