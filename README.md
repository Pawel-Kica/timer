# Timer

A Mac menu bar timer for your work hours.

It does one thing: start, stop and save. It's omakase style, so if you'd like something changed, fork it or open an issue.

## How to use it

Click the stopwatch in the menu bar to start. Click again to stop. While it runs, the time shows next to the icon.

Right-click it for the menu:

- **Today** shows how long you worked today.
- **End and save** adds the session to a CSV file and resets the timer.
- **Remind me at** sends a notification if the timer is still running at that time (default 17:00).
- **Notify after** tells you when today reaches that many hours (default 8).
- **Open log** opens the CSV, one line per session: `date,start,end,duration`.

The timer keeps counting through sleep and while the app is closed, and picks up where it was when you open it again.

## Install

You need macOS 14 or newer and the Xcode Command Line Tools (`xcode-select --install`). No Xcode project, it's a Swift package.

```sh
git clone https://github.com/Pawel-Kica/timer.git
cd timer
./build.sh
open /Applications/Timer.app
```

It adds itself as a login item, so it starts with your Mac. You can turn that off in System Settings > General > Login Items.

`build.sh` signs with your Apple Development certificate when you have one, ad hoc otherwise. macOS ties the notification and login item permissions to the signature, so with ad hoc signing it may ask again after a rebuild. If macOS blocks the app the first time, go to System Settings > Privacy & Security and click Open Anyway.

After a rebuild, restart the running copy with `pkill -x WorkTimer; open /Applications/Timer.app`.

Tests: `swift test` (needs Xcode for XCTest). The icon comes from `make-icon.swift`, run `swift make-icon.swift` to regenerate `AppIcon.icns`.

The log lives in `~/Library/Application Support/Timer/log.csv`.

## License

MIT
