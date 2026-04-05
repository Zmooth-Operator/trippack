# TripPack

A minimalist offline-first travel companion for iOS. Plan trips, store documents, and navigate — no internet required.

---

## Features

- **Offline Maps** — Download maps before you travel. Works without internet.
- **Trip Management** — Create, edit, and organize trips with destination, dates, and status tracking.
- **Document Storage** — Store boarding passes, hotel bookings, passports, and more — locally on your device.
- **Live GPS** — See your position on the map in real time.
- **Automatic Status** — Trips automatically switch between Planned, Active, and Completed based on dates.
- **Face ID / Biometrics** — Enable biometric protection in Settings.
- **Face ID App Lock** — App locks on startup, unlock with biometrics.
- **No cloud. No account. No tracking.** — Everything stays on your device.

---

## Upcoming

- **Dark / Light mode toggle**
- **Push notifications** for upcoming trips
- **Multiple language support**
- **App Store release**

---

## Tech Stack

- **Flutter** — Cross-platform UI
- **Drift / SQLite** — Local persistent storage with migrations
- **flutter_map + OpenStreetMap** — Offline-capable maps
- **Nominatim API** — City search with autocomplete
- **Geolocator** — Live GPS positioning
- **file_picker + open_filex** — Document upload and viewing
- **local_auth** — Face ID / biometric authentication

---

## Getting Started

```bash
git clone https://github.com/Zmooth-Operator/trippack.git
cd trippack
flutter pub get
flutter run
```

Requires Flutter 3.x and iOS Simulator or physical device.

---

## Philosophy

TripPack is built on one principle: **your data belongs to you.**

No server receives your documents. No account is required. No analytics run in the background. The app works fully offline because travel is unpredictable — your tools should not be.

---

## About

Built by [Z Systems](https://github.com/Zmooth-Operator) — software with purpose.
