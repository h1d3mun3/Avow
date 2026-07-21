# Avow

> **avow** — to declare openly and publicly.

Picking a task from the menu bar is a declaration: *"This is what I'm doing right now."*

Avow is a macOS time tracker built around that single moment of intention. No manual timers, no friction — just choose a task and the clock starts.

## Features

- **Menu bar first** — start and stop tracking from anywhere without opening the full app; the current task and elapsed time are shown in the menu bar
- **Projects & tasks** — organize work into projects with task lists; drag to reorder projects in the sidebar
- **Dashboard** — overview of total, weekly, and daily tracked time with per-project breakdown and a Quick Start section to begin tracking without leaving the main window
- **Calendar** — browse tracked time by date; select any day to see a timeline of entries grouped by task with per-project breakdown
- **Time entry editing** — edit start/end times or delete individual records from both the project detail view and the calendar timeline
- **Archive** — archive completed projects to keep the sidebar tidy without losing data

## Requirements

- macOS 14 Sonoma or later
- Xcode 16 or later

## Getting Started

1. Clone the repository
2. Open `Avow.xcodeproj` in Xcode
3. Build and run (`⌘R`)

The app appears in the menu bar and Dock. Open the Dashboard from the menu bar popover to create your first project and tasks, then pick a task to start the clock.

## Releasing

Bump `MARKETING_VERSION` in the Xcode project, merge that change to `main`, then push a matching tag (e.g. `v0.5.0`) to `main`. The [Release DMG](.github/workflows/release.yml) workflow archives the app, signs it with the Developer ID identity, notarizes and staples it, builds the DMG via `scripts/package-dmg.sh`, and publishes a GitHub release with the DMG attached.

The workflow needs these repository secrets configured once (Settings → Secrets and variables → Actions):

| Secret | How to get it |
| --- | --- |
| `MACOS_CERTIFICATE_P12_BASE64` | Export the "Developer ID Application" certificate + private key from Keychain Access as a `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERTIFICATE_PASSWORD` | The password you set when exporting the `.p12` |
| `APPSTORECONNECT_KEY_ID` | Key ID of an App Store Connect API key ([Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api)) |
| `APPSTORECONNECT_ISSUER_ID` | Issuer ID shown on the same API keys page |
| `APPSTORECONNECT_API_KEY_P8_BASE64` | `base64 -i AuthKey_<KEY_ID>.p8 \| pbcopy` for the downloaded key file |

To test the workflow without cutting a real release, trigger it manually from the Actions tab (`workflow_dispatch`) against an existing tag.

## License

MIT
