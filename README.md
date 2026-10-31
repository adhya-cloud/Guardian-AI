<div align="center">🛡️ GUARDIAN AI

Personal Safety & Emergency Response for India

Your Safety. Your Guardian. Your Life.

An Android-first personal safety application built with Flutter to help users send emergency SMS alerts, share their location, monitor journeys, and discover nearby emergency services—even when mobile data is unavailable.

""Flutter" (https://img.shields.io/badge/Flutter-3.44-02569B?style=for-the-badge&logo=flutter&logoColor=white)" (https://flutter.dev/)
""Dart" (https://img.shields.io/badge/Dart-3.12-0175C2?style=for-the-badge&logo=dart&logoColor=white)" (https://dart.dev/)
""Kotlin" (https://img.shields.io/badge/Kotlin-Android-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)" (https://kotlinlang.org/)
""Node.js" (https://img.shields.io/badge/Node.js-Optional_Backend-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)" (https://nodejs.org/)

Emergency Alerts • Location Sharing • Journey Monitoring • Privacy-First Design

"Features" (#-key-features) · "Screenshots" (#-application-screenshots) · "Architecture" (#-system-architecture) · "Installation" (#-getting-started) · "Deployment" (#-deployment) · "Contributing" (#-contributing)

</div>---

📌 Table of Contents

- "Overview" (#-overview)
- "The Problem" (#-the-problem)
- "Our Solution" (#-our-solution)
- "Key Features" (#-key-features)
- "Application Screenshots" (#-application-screenshots)
- "Deployment Photos" (#-deployment-photos)
- "How It Works" (#-how-it-works)
- "System Architecture" (#-system-architecture)
- "Technology Stack" (#-technology-stack)
- "Project Structure" (#-project-structure)
- "Getting Started" (#-getting-started)
- "Tracking Server Setup" (#-tracking-server-setup)
- "Deployment" (#-deployment)
- "Privacy and Security" (#-privacy-and-security)
- "Limitations" (#-limitations)
- "Roadmap" (#-roadmap)
- "Contributing" (#-contributing)
- "Team" (#-team)
- "License" (#-license)

---

🚀 Overview

Guardian AI is an Android-first personal safety application designed to make emergency communication faster, simpler, and more accessible.

In an emergency, a person may not have enough time to navigate multiple screens, explain their location, or rely on mobile internet. Guardian addresses these challenges by bringing essential safety features into a single mobile application.

The application prioritizes SMS-based SOS alerts, location-aware emergency communication, journey check-ins, live location sharing, and access to nearby emergency services.

An optional Node.js tracking server enables a shareable live-map experience. The core safety workflows can operate independently of that server.

«Core principle: Essential emergency communication should not depend entirely on an internet connection.»

✨ Highlights

- 🔴 SOS alerts through SMS without requiring mobile data for the SMS transmission itself.
- 📍 GPS-based location information and location-update messages.
- 🚶 Journey check-ins with automatic escalation after a missed deadline.
- 🗺️ OpenStreetMap-based maps and nearby emergency-place discovery.
- 🚨 Emergency utilities, including a siren and flashlight strobe.
- 📞 Quick access to important Indian emergency helplines.
- 🇮🇳 English and Hindi interfaces and alert messages.
- 🔐 Local-first data storage with platform-backed secure storage.
- 🌐 Optional tracking server for shareable live-map links.

---

❗ The Problem

During an emergency, people may face several challenges:

- Difficulty contacting trusted people quickly.
- Lack of mobile internet connectivity.
- Inability to communicate their current location.
- Safety concerns while travelling alone.
- Missed arrival times without an automated notification.
- Difficulty locating nearby police stations, hospitals, or pharmacies.
- Privacy concerns associated with sharing sensitive personal information.

Traditional communication methods may require multiple manual steps, especially when the user is under stress.

💡 Our Solution

Guardian brings essential personal safety capabilities together in one application.

Instead of treating emergency alerts, journey monitoring, and location sharing as separate tasks, Guardian combines them into a connected safety workflow.

The user can configure trusted contacts, initiate an SOS, share location information, establish a journey deadline, and access nearby emergency resources from the same application.

Guardian is designed to assist emergency communication—not replace professional emergency services.

---

🔥 Key Features

1. 🔴 Emergency SOS

Initiate an emergency alert with a single tap or a supported shake-based trigger.

How it works:

1. The user activates SOS.
2. A configurable 3-, 5-, or 10-second countdown begins.
3. The user can cancel an accidental activation.
4. The application attempts to send SMS alerts to configured trusted contacts.
5. The message can include the user's name, available Google Maps location link, GPS accuracy, timestamp, battery level, and optional medical information.
6. Android SMS status callbacks provide sent or failed status for individual messages.

Important: A successful send status does not guarantee that the recipient received or read the message.

2. 📍 SOS Follow-Up

Emergency communication can continue after the initial alert.

- Background location tracking while enabled.
- Periodic location-update SMS messages.
- Configurable update intervals.
- Optional automatic calling to a primary contact or emergency number.
- Emergency siren and flashlight strobe.
- An "I'm Safe" action to end the SOS workflow and notify contacts.

Background operation depends on device permissions, Android restrictions, and the configured implementation.

3. 🚶 Journey Check-In

Designed for people travelling alone or wanting additional journey oversight.

Users can configure a destination and a time limit.

Journey workflow:

1. Enter the destination.
2. Set the journey deadline.
3. Start journey monitoring.
4. Receive a reminder two minutes before the deadline.
5. Confirm arrival or extend the timer.
6. If the deadline is missed, initiate the configured automatic alert workflow using the last available location.
7. Continue into SOS mode according to the application's escalation logic.

This feature helps trusted contacts respond when a journey does not proceed as expected.

4. 🌐 Live Location Sharing

Share your location with selected contacts for a configurable period, from 15 minutes to 8 hours.

Guardian supports two approaches:

Mode| Behaviour
Tracking server configured| Contacts receive a shareable live-map link that can update every few seconds.
No tracking server| Contacts receive periodic SMS location updates.

Location sharing stops automatically when its configured duration ends.

5. 🗺️ Interactive Emergency Map

The application uses OpenStreetMap-based mapping to display location information and nearby emergency resources.

Supported place categories:

- 🚓 Police stations
- 🏥 Hospitals
- 💊 Pharmacies
- 🚒 Fire stations

Map capabilities:

- Current position and location-accuracy circle.
- Nearby-place discovery.
- Category filters.
- Search within the visible map area.
- Distance information.
- One-tap directions and calling options where available.
- Location sharing.

Nearby-place discovery uses the Overpass API. Results depend on the available OpenStreetMap data and network connectivity.

6. 👥 Trusted Contacts

Configure the people who should be notified during an emergency.

- Select contacts through the system contact picker.
- Enter a phone number manually.
- Configure a primary emergency contact.
- Select recipients for SOS notifications.
- Send test or introductory SMS messages.
- Handle Indian phone-number formats.

7. 🇮🇳 Indian Emergency Helplines

Guardian provides one-tap dialling shortcuts for important helplines.

Number| Service
112| National Emergency Response Support System
100| Police
1091| Women Helpline
181| Women Helpline
108| Ambulance
102| National Ambulance Service
101| Fire Services
1098| Child Helpline
1930| Cyber Fraud Helpline
14567| Elderline

Note: Availability and service coverage may vary by location. Use the applicable official emergency service for your situation.

8. 📲 Fake Call

The fake-call feature simulates an incoming call after a configurable delay, using the device's ringtone and vibration where supported.

It is designed to give users an additional way to leave an uncomfortable situation.

It does not connect the user to a real caller or guarantee personal safety.

9. 📜 Emergency History

Review previous safety activities.

- SOS events.
- Journey history.
- Live-location-sharing sessions.
- Route visualization on a map.
- Individual SMS status information.

10. 🌐 Bilingual Experience

Guardian supports English and Hindi for its user interface and emergency messages.

The goal is to make essential safety functionality accessible to a wider range of users across India.

---

📱 Application Screenshots

Explore the application's interface and safety workflows.

Screenshot Gallery

«Add your actual app screenshots to "docs/screenshots/" and update the filenames below. GitHub will render the images directly in your README.»

<table>
  <tr>
    <td align="center" width="33%">
      <img src="docs/screenshots/home.png" alt="Guardian home screen" width="220"/>
      <br/><b>Home Screen</b>
      <br/>Quick access to safety features
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/sos.png" alt="Guardian SOS screen" width="220"/>
      <br/><b>Emergency SOS</b>
      <br/>Rapid emergency alert workflow
    </td>
    <td align="center" width="33%">
      <img src="docs/screenshots/live-location.png" alt="Guardian live location screen" width="220"/>
      <br/><b>Live Location</b>
      <br/>Location sharing and tracking
    </td>
  </tr>
  <tr>
    <td align="center">
      <img src="docs/screenshots/journey.png" alt="Guardian journey check-in screen" width="220"/>
      <br/><b>Journey Check-In</b>
      <br/>Timed journey monitoring
    </td>
    <td align="center">
      <img src="docs/screenshots/emergency-map.png" alt="Guardian emergency map" width="220"/>
      <br/><b>Emergency Map</b>
      <br/>Nearby emergency resources
    </td>
    <td align="center">
      <img src="docs/screenshots/settings.png" alt="Guardian settings screen" width="220"/>
      <br/><b>Safety Settings</b>
      <br/>Contacts, permissions, and preferences
    </td>
  </tr>
</table>📂 Browse All Screenshots

"View Application Screenshots" (docs/screenshots/)

Repository path: "docs/screenshots/"

If you prefer hosting the images externally, replace the relative image paths with links to your actual GitHub-hosted image files.

---

📸 Deployment Photos

This section documents the project presentation, application demonstration, testing, and deployment setup.

Project Demonstration

Add photos showing the application running on a real Android device, including the SOS workflow, location map, and journey check-in.

"View Deployment Photos" (docs/deployment/)

Suggested Photo Collection

Photo| Description
"app-running.jpg"| Guardian running on an Android device
"sos-demonstration.jpg"| Demonstration of the SOS workflow
"location-map.jpg"| Nearby emergency-place map
"journey-checkin.jpg"| Journey monitoring demonstration
"server-deployment.jpg"| Optional tracking server deployment
"team-presentation.jpg"| Project presentation or demonstration

Deployment Gallery

Once the photographs are added, you can display selected images here:

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/deployment/app-running.jpg" alt="Guardian running on a device" width="100%"/>
      <br/><b>Application Demonstration</b>
    </td>
    <td align="center" width="50%">
      <img src="docs/deployment/server-deployment.jpg" alt="Guardian tracking server deployment" width="100%"/>
      <br/><b>Server Deployment</b>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <img src="docs/deployment/sos-demonstration.jpg" alt="Guardian SOS demonstration" width="100%"/>
      <br/><b>SOS Workflow</b>
    </td>
    <td align="center" width="50%">
      <img src="docs/deployment/team-presentation.jpg" alt="Guardian project team presentation" width="100%"/>
      <br/><b>Project Presentation</b>
    </td>
  </tr>
</table>These are proposed repository paths. Add your actual photos with the matching filenames or update the paths to match your assets.

---

⚙️ How It Works

Emergency SOS Workflow

flowchart TD
    A[User Activates SOS] --> B[Start Configurable Countdown]
    B --> C{Cancelled?}
    C -->|Yes| D[Stop SOS Activation]
    C -->|No| E[Acquire Available Location]
    E --> F[Prepare Emergency Message]
    F --> G[Send SMS to Trusted Contacts]
    G --> H[Record Individual Send Status]
    H --> I[Optional Location Follow-Up]
    I --> J{User Confirms Safety?}
    J -->|No| I
    J -->|Yes| K[End SOS and Notify Contacts]

Journey Check-In Workflow

flowchart TD
    A[Set Destination and Deadline] --> B[Start Journey]
    B --> C[Monitor Journey and Timer]
    C --> D{Deadline Approaching?}
    D -->|Yes| E[Send Pre-Deadline Reminder]
    D -->|No| F{Journey Completed?}
    E --> F
    F -->|Yes| G[Confirm Arrival and Finish]
    F -->|No| H{Deadline Missed?}
    H -->|No| C
    H -->|Yes| I[Trigger Configured Escalation]
    I --> J[Notify Trusted Contacts]
    J --> K[Continue in SOS Mode]

Live Location Sharing

flowchart TD
    A[User Starts Location Sharing] --> B[Select Duration and Contacts]
    B --> C{Tracking Server Configured?}
    C -->|Yes| D[Create Shareable Live-Map Link]
    D --> E[Update Location Points]
    C -->|No| F[Send Periodic SMS Location Updates]
    E --> G{Sharing Duration Expired?}
    F --> G
    G -->|No| E
    G -->|Yes| H[Stop Location Sharing]

---

🏗️ System Architecture

Guardian uses a mobile-first architecture with an optional backend service for live-map sharing.

flowchart TB
    subgraph Mobile["Guardian Mobile Application"]
        UI[Flutter and Dart UI]
        STATE[Provider State Management]
        NATIVE[Native Android Integration]
        LOCATION[Location and Tracking]
        SECURITY[Secure Local Storage]
    end

    subgraph Device["Android Device Services"]
        SMS[SMS and Delivery Callbacks]
        GPS[Location Manager]
        CONTACTS[System Contact Picker]
        PHONE[Calling and Torch]
        NOTIFY[Notifications and Sensors]
    end

    subgraph Optional["Optional Tracking Infrastructure"]
        API[Node.js and Express API]
        LIMIT[Helmet and Rate Limiting]
        STORE[In-Memory Storage or MongoDB]
        WEB[Leaflet Live-Map Viewer]
    end

    subgraph External["External Data Services"]
        OSM[OpenStreetMap Tiles]
        OVERPASS[Overpass API]
    end

    UI --> STATE
    STATE --> NATIVE
    NATIVE --> SMS
    NATIVE --> GPS
    NATIVE --> CONTACTS
    NATIVE --> PHONE
    NATIVE --> NOTIFY
    STATE --> LOCATION
    STATE --> SECURITY

    LOCATION -. Optional live sharing .-> API
    API --> LIMIT
    LIMIT --> STORE
    STORE --> WEB

    UI --> OSM
    UI --> OVERPASS

Architecture Principles

- Standalone core: Basic SOS SMS, journey workflows, emergency utilities, and history do not inherently require the optional tracking server.
- Platform integration: Native Android functionality handles device-level capabilities that require platform APIs.
- Optional infrastructure: The tracking server enables shareable live-map links.
- Local-first design: Personal data is intended to remain on the device unless a feature explicitly transmits it.
- Graceful degradation: Features that depend on mobile data or optional infrastructure may be unavailable when connectivity is lost.

---

🧰 Technology Stack

Mobile Application

Technology| Purpose
Flutter 3.44| Cross-platform mobile application framework
Dart 3.12| Application programming language
Kotlin| Native Android integration
Provider| State management
"flutter_map"| Interactive maps
OpenStreetMap| Map tiles and geographic data
Overpass API| Nearby-place discovery
"permission_handler"| Runtime permission management
"sensors_plus"| Shake detection
"flutter_local_notifications"| Local notifications
"flutter_secure_storage"| Platform-backed secure storage
"share_plus"| Sharing functionality
"url_launcher"| Phone, map, and external link actions
"http"| HTTP requests to external services and optional backend

Native Android Capabilities

Custom Kotlin method-channel integration supports:

- Direct SMS sending and send-status callbacks.
- System contact picker.
- Phone calls.
- Flashlight control.
- Siren playback.
- Ringtone and vibration.
- Battery-level information.
- Location and background tracking integration.

Availability depends on Android permissions, API level, device behavior, and implementation.

Optional Tracking Server

Technology| Purpose
Node.js 20+| Server runtime
Express 4| HTTP API
Helmet| HTTP security headers
express-rate-limit| Request rate limiting
MongoDB| Optional persistent tracking storage
In-memory storage| Lightweight, non-persistent alternative
Leaflet| Live-map web viewer
Docker Compose| Local multi-service setup

---

📂 Project Structure

Guardian/
│
├── guardian_ai_mobile/
│   ├── android/
│   ├── ios/
│   ├── lib/
│   ├── test/
│   ├── pubspec.yaml
│   └── README.md
│
├── tracking-server/
│   ├── src/
│   ├── package.json
│   └── README.md
│
├── docs/
│   ├── screenshots/
│   │   ├── home.png
│   │   ├── sos.png
│   │   ├── live-location.png
│   │   ├── journey.png
│   │   ├── emergency-map.png
│   │   └── settings.png
│   │
│   └── deployment/
│       ├── app-running.jpg
│       ├── sos-demonstration.jpg
│       ├── location-map.jpg
│       ├── journey-checkin.jpg
│       ├── server-deployment.jpg
│       └── team-presentation.jpg
│
├── docker-compose.yml
└── README.md

The directory and filenames above are the recommended documentation layout. Adjust them to match your actual repository.

---

🚀 Getting Started

Prerequisites

Install the following tools before building the application:

- Flutter SDK 3.44 or a compatible version.
- Dart SDK compatible with the Flutter installation.
- Android Studio or another Android development environment.
- Android SDK and platform tools.
- A physical Android device for testing SMS, calls, GPS, flashlight, and background services.
- Git.

The optional tracking server additionally requires Node.js 20+ and Docker with Docker Compose if you intend to use the supplied container setup.

1. Clone the Repository

git clone <YOUR_GITHUB_REPOSITORY_URL>
cd <YOUR_REPOSITORY_DIRECTORY>

Replace the placeholders with your actual repository URL and directory name.

2. Open the Mobile Application

cd guardian_ai_mobile

3. Install Dependencies

flutter pub get

4. Check the Development Environment

flutter doctor

Resolve any missing Android SDK, device, or Flutter configuration requirements reported by the command.

5. Connect an Android Device

Enable developer options and USB debugging on a compatible Android device, then connect it to your computer.

Verify that Flutter detects the device:

flutter devices

6. Run the Application

flutter run

Grant the permissions requested by the application when testing the corresponding features.

7. Build an Android APK

flutter build apk --release

The generated APK is normally located at:

build/app/outputs/flutter-apk/app-release.apk

The precise output location can vary if the project uses a customized Android build configuration.

Testing recommendation: Test on a physical device before distributing a build. SMS, location, shake detection, calls, and background behavior cannot be validated fully through a typical desktop-only workflow.

---

🌐 Do I Need the Tracking Server?

No. The mobile application is designed to operate without the optional tracking server.

Capability| Server Required?
SOS SMS alerts| No
Location information in SMS| No
Periodic SMS location updates| No
Jou
