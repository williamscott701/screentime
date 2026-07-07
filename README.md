# Screen Drift

An iOS app that turns Apple's Screen Time data into a simple daily budget: set a target number of hours/minutes per day, and Screen Drift tracks how much you've used, how much is left, and whether you're on a streak of staying under your limit.

The app itself is called **Screen Drift** in code (`ScreenDriftApp`, `ScreenDriftStore`) even though the Xcode project and repo are named `screentime`.

## Tech stack

- **Swift / SwiftUI** — single-window `TabView` app, no external dependencies (no SPM/CocoaPods/Carthage packages)
- **FamilyControls** — requests Screen Time authorization (`AuthorizationCenter`) so the app can read real device activity
- **DeviceActivity / DeviceActivityReport** — a separate app extension (`ScreenDriftReport`) that reads per-day usage segments from iOS and computes daily minutes
- **WidgetKit** — a widget extension (`ScreenDriftWidgetExtension`) showing progress rings and countdowns on the home screen
- **App Groups** (`group.com.screendrift.shared`) via `UserDefaults(suiteName:)` — the mechanism the report extension, widget, and main app use to share data across processes
- **Swift's `@Observable` macro** for state management (`ScreenDriftStore`), no third-party state library

## Features (from the code)

- Set a daily screen-time target (hours/minutes picker)
- Automatic tracking: once Family Controls access is granted, a `DeviceActivityReport` extension reads real usage and writes it to the shared App Group, which the app and widget read from
- Manual time logging as a fallback/override when auto-tracking isn't authorized (`LogTimeView`)
- "Today" dashboard: progress ring, remaining time, over/under-limit status message, and contextual tips (e.g. suggestions to enable Focus mode when over the limit)
- Smart target suggestion: computes a 7-day (or 3-day fallback) average and suggests a target 20% lower ("realistic daily goal")
- Daily streak counter for consecutive days spent under target
- History tab with a chart of past daily usage (`HistoryView`)
- Settings tab (`SettingsView`)
- Two home-screen widget styles ("Ring" and "Minimal"), each in small/medium/large sizes, showing a live countdown timer, used/target stats, and a draining progress bar
- Local persistence only — logs and target are stored in `UserDefaults` under the shared App Group; there's no backend/network layer

## Project structure

```
screentime.xcodeproj/           Xcode project

screentime/                     Main app target
  screentimeApp.swift           @main entry point (ScreenDriftApp), requests authorization on launch
  ContentView.swift             Root TabView (Today / History / Settings)
  DashboardView.swift           "Today" tab: target setting, progress ring, suggestions, streak
  HistoryView.swift             Usage history / chart
  SettingsView.swift            App settings
  LogTimeView.swift             Manual time-entry sheet
  ScreenTimeStore.swift         ScreenDriftStore — the @Observable app state, App Group sync, streak/average logic
  screentime.entitlements       Family Controls + App Groups entitlements

ScreenDriftReport/               DeviceActivityReportExtension target
  ScreenDriftReport.swift        @main extension entry point
  TotalActivityReport.swift      Aggregates DeviceActivity data into daily minutes, writes to shared UserDefaults
  TotalActivityView.swift        SwiftUI view rendered by the report extension

ScreenDriftWidgetExtension/      WidgetKit extension target
  ScreenDriftWidgetExtension.swift        Widget entry point/bundle
  ScreenDriftWidgetExtensionBundle.swift

ScreenTimeReportExtension.swift  Legacy/reference copy of the report-extension code + setup instructions
                                 (not part of the ScreenDriftReport target; superseded by
                                 ScreenDriftReport/ScreenDriftReport.swift + TotalActivityReport.swift)
ScreenTimeWidget.swift           Legacy/reference copy of the widget code + setup instructions
                                 (superseded by ScreenDriftWidgetExtension/ScreenDriftWidgetExtension.swift)
```

## Setup

Requires Xcode (SwiftUI + WidgetKit + FamilyControls, so a recent iOS SDK) and a physical device or simulator that supports Screen Time APIs.

1. Open `screentime.xcodeproj` in Xcode.
2. Make sure the following capabilities/entitlements are set on the relevant targets (they're already present in the checked-in entitlements files, but need matching App IDs/provisioning in your own Apple Developer account to build and run):
   - Main app (`screentime`): **Family Controls**, **App Groups** → `group.com.screendrift.shared`
   - `ScreenDriftReport` extension: **App Groups** → `group.com.screendrift.shared`
   - `ScreenDriftWidgetExtension`: **App Groups** → `group.com.screendrift.shared`
3. Build and run the `screentime` scheme on a device/simulator.
4. On first launch the app requests Family Controls authorization; grant it to enable automatic tracking, or use "Log Time" manually if you skip/deny it.

There is no `package.json`, `Podfile`, or `requirements.txt` — this is a plain Xcode project with no external package dependencies.

## Usage

- Open the app, set a daily target on the "Today" tab.
- If authorized, usage populates automatically each time the app (or its DeviceActivity report view) runs; otherwise use the pencil icon to log time manually.
- Check the "History" tab for past days, and add the home-screen widget for an at-a-glance countdown.

## Notes / Status

This is a personal/experimental project, not a published app:

- `ScreenTimeReportExtension.swift` and `ScreenTimeWidget.swift` at the repo root are earlier/reference versions of the extension and widget code, kept alongside the real `ScreenDriftReport/` and `ScreenDriftWidgetExtension/` targets with inline comments explaining how to wire them up in Xcode. They appear to be leftover scaffolding rather than active build targets.
- The Xcode project, folders, and some file headers still say "screentime" / "ScreenDash" in places even though the app was renamed to "Screen Drift" — naming isn't fully consistent throughout.
- No automated tests, CI, or App Store metadata are present in the repo.
