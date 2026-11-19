# Hearth

Chores, home upkeep and kid chores, in one SwiftUI app for iPhone, iPad and Mac. Data syncs through iCloud (SwiftData + CloudKit).

- **Today**: overdue and due-today chores, a progress row per kid, and what's coming in the next 7 days. Tap the circle to mark a chore done (tap again to undo). Swipe a row to snooze it to tomorrow.
- **Rooms**: chores grouped by room.
- **Upkeep**: long-interval maintenance on a month-by-month timeline, with notes for parts and providers.
- **Family**: people, stars, Kid Mode, a daily reminder and the starter set.

Run with `-demo` to use a throwaway in-memory store filled with sample data. In Debug builds, `-kidmode` opens Kid Mode at launch.

## Build it

Xcode 16 or later; runs on iOS/iPadOS 18 and macOS 15 or later. Open `Hearth.xcodeproj`, then under Signing & Capabilities set your own Team, change the bundle identifier (`com.antass.hearth`) and the iCloud container (`iCloud.com.antass.hearth`) to ones in your Apple account, and run.

## License

MIT. See `LICENSE`.
