# Pomodoro 🍅

A lightweight macOS Pomodoro timer built with SwiftUI, featuring menu bar controls, Apple Reminders task selection, and focus records you can add to Calendar.

## User Guide

Read the [User Guide](docs/USER_GUIDE.md) for setup, a first-session walkthrough, timer controls, Reminders and Calendar integration, saved-state behavior, and troubleshooting.

## Features

- 25-minute focus sessions, 5-minute short breaks, and a 15-minute long break after every four completed focus sessions.
- Start, pause, resume, and end a session early. Paused time is excluded from focus records.
- Optional automatic breaks. Start the next focus session manually.
- A shared timer across the app window and menu bar.
- Timer state and focus records saved locally, with deadline-based recovery when reopening the app.
- Choose a Reminders list (or All Lists), then select an incomplete reminder as your task without modifying or completing it. The list selection is remembered.
- Automatically sync new focus records when you pause, end, or complete a session. Failed records stay queued for retry; existing events are checked to avoid duplicates.
- View the latest 500 actions and sync results in **Activity Log**, delete individual entries, or clear all activity logs.

Pausing creates a focus segment, so a session may produce multiple records. Breaks do not create focus records. The countdown continues during sleep or while the app is closed. On recovery, an expired phase finishes and an automatic break starts from the recovery time; the app does not generate missed sessions.

## Requirements

- macOS 14 or later.
- Xcode 15 or later, or a command-line toolchain with Swift 5.9+ and the macOS SDK.

## Build and Run

From the repository root:

```sh
./scripts/build-app.sh
open build/Pomodoro.app
```

The script builds a release executable using Swift Package Manager, generates the app icon, packages the application, and applies a local ad-hoc signature. The output is `build/Pomodoro.app`.

Use the packaged `.app` for Calendar and Reminders integration so macOS can read the permission descriptions in `Info.plist`. Click **Load Tasks** to read incomplete reminders, or **Connect Calendar** to request Calendar access. Task loading does not require Calendar access. The timer works without these permissions. To change permissions later, open **System Settings → Privacy & Security** and find Calendar or Reminders.

This build is intended for local development. Public distribution requires Developer ID signing and notarization. No installer is provided yet.

## Tests

```sh
swift test
```

GitHub Actions runs the tests and verifies app packaging on pushes and pull requests.

Tests cover pause/resume, excluded pause time, deadline clipping, automatic breaks, fourth-session long breaks, early termination, JSON state recovery, repeated starts, premature completion protection, and preservation of record metadata.

`Tests/PomodoroCoreTests/` is the XCTest entry point. The root-level `TimerTests.swift` retains the original assertion-based tests for reference, depends on the `PomodoroCore` module, and is not included in `swift test`.

## Project Structure

```text
Sources/
  PomodoroCore/           # Independently testable timer state and record models
  Pomodoro/               # SwiftUI interface, persistence, and EventKit integration
Tests/PomodoroCoreTests/  # Timer logic tests
Resources/Info.plist      # App metadata and permission descriptions
Tomato.iconset/           # macOS app icon sources
scripts/build-app.sh     # Build and package the macOS app
Package.swift            # Swift Package Manager configuration
docs/USER_GUIDE.md        # End-user instructions and troubleshooting
```

## Data and Permissions

Timer state, focus records, activity logs, and sync status are stored locally using `UserDefaults`. The project has no network service or account system. Reminders provides task titles. **Automatically sync focus records** is enabled by default; select a calendar to sync new focus records. You can disable it and use **Add to Calendar** manually. Missing Calendar access triggers an authorization request; after access is granted, queued records are retried. Full Calendar access is used to select writable calendars and check for duplicate records.

Records contain task titles and timestamps. Do not commit private tasks, calendar data, or access credentials.

## Known Limitations

- Custom durations, charts, Notification Center notifications, and cross-device sync are not available yet.
- Phase completion plays a system sound. The app cannot notify you while closed.
- Refresh reminders manually using **Load Tasks**; loading, empty-list, and permission states appear below the button.
- Focus records cannot yet be deleted or exported as files from the interface. Activity logs can be deleted in **Activity Log**.
- Calendar and Reminders permissions and menu bar interactions require testing in the macOS GUI; core unit tests do not cover these integrations.

## Contributing and License

Issues and pull requests are welcome. Include your macOS version, reproduction steps, and expected and actual behavior when reporting a problem.

Licensed under the [MIT License](LICENSE).
