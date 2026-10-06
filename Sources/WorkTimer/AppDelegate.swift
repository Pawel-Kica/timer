import AppKit
import ServiceManagement
import UserNotifications
import WorkTimerCore

/// The whole app: a menu bar item and its menu. Left click starts or stops the timer, right click opens the menu.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let defaults = UserDefaults.standard
    private let logURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Timer/log.csv")
    private var item: NSStatusItem!
    private var stopwatch = Stopwatch()
    private var tick: Timer?
    /// Today's ended sessions from the log, read once per day and again after End or when the menu opens.
    private var saved: (day: String, total: TimeInterval)?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_: Notification) {
        // New status items go left of the others, which on a full MacBook menu bar is under the notch. 300 pt from
        // the right edge keeps it in view. ⌘-dragging it saves the new place over this.
        defaults.register(defaults: ["NSStatusItem Preferred Position Item-0": 300, "remindAt": 17 * 60, "goalHours": 8.0])
        if let data = defaults.data(forKey: "stopwatch"), let stored = try? JSONDecoder().decode(Stopwatch.self, from: data) {
            stopwatch = stored
        }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "stopwatch", accessibilityDescription: "Timer")
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        if SMAppService.mainApp.status == .notRegistered {
            do { try SMAppService.mainApp.register() } catch { NSLog("Timer: login item registration failed: \(error)") }
        }
        refresh()
    }

    // MARK: Timer

    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            // A status item with a menu set opens it on every click, so the menu is attached only for this one.
            item.menu = menu()
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        stopwatch.toggle(at: Date())
        save()
    }

    /// Appends the session to the log and resets to zero.
    @objc private func end() {
        if let session = stopwatch.end(at: Date()) {
            let text = (try? String(contentsOf: existingLog(), encoding: .utf8)) ?? ""
            do { try (text + Log.line(session) + "\n").write(to: logURL, atomically: true, encoding: .utf8) } catch {
                NSLog("Timer: writing the log failed: \(error)")
            }
            saved = nil
        }
        save()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(stopwatch), forKey: "stopwatch")
        refresh()
    }

    /// Redraws the menu bar item, keeps the 1 s tick alive only while running and sends the notifications that are due.
    @objc private func refresh() {
        let now = Date(), elapsed = stopwatch.elapsed(at: now)
        item.button?.title = stopwatch.running || elapsed > 0 ? " " + clock(elapsed) : ""
        item.button?.appearsDisabled = !stopwatch.running && elapsed > 0

        if !stopwatch.running {
            tick?.invalidate()
            tick = nil
            return
        }
        if tick == nil {
            let timer = Timer(timeInterval: 1, target: self, selector: #selector(refresh), userInfo: nil, repeats: true)
            RunLoop.main.add(timer, forMode: .common)
            tick = timer
        }

        let today = Log.day(now)
        if defaults.string(forKey: "remindedOn") != today,
           stopwatch.reminderDue(minutes: defaults.integer(forKey: "remindAt"), at: now) {
            defaults.set(today, forKey: "remindedOn")
            notify("Still running, \(clock(elapsed)) so far.")
        }
        let goal = defaults.double(forKey: "goalHours")
        if defaults.string(forKey: "goalHitOn") != today, savedToday(now) + elapsed >= goal * 3600 {
            defaults.set(today, forKey: "goalHitOn")
            notify("\(hours(goal)) worked today.")
        }
    }

    // MARK: Log

    /// The log file, created with its header when missing.
    private func existingLog() -> URL {
        if !FileManager.default.fileExists(atPath: logURL.path) {
            try? FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? (Log.header + "\n").write(to: logURL, atomically: true, encoding: .utf8)
        }
        return logURL
    }

    private func savedToday(_ now: Date) -> TimeInterval {
        let day = Log.day(now)
        if saved?.day != day {
            saved = (day, Log.total(on: day, in: (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""))
        }
        return saved?.total ?? 0
    }

    @objc private func openLog() {
        NSWorkspace.shared.open(existingLog())
    }

    // MARK: Notifications

    private func notify(_ text: String) {
        let content = UNMutableNotificationContent()
        content.body = text
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Shows the banner even when the app is the active one, which it is while its menu is open.
    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter, willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Changing either setting re-arms today's notification only when the new mark is still ahead. One already passed
    // would fire on every pick.

    @objc private func reminderChanged(_ choice: NSMenuItem) {
        let now = Date(), parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        defaults.set(choice.tag, forKey: "remindAt")
        defaults.set(choice.tag > parts.hour! * 60 + parts.minute! ? nil : Log.day(now), forKey: "remindedOn")
    }

    @objc private func goalChanged(_ choice: NSMenuItem) {
        let now = Date(), goal = Double(choice.tag) / 2
        defaults.set(goal, forKey: "goalHours")
        defaults.set(goal * 3600 > savedToday(now) + stopwatch.elapsed(at: now) ? nil : Log.day(now), forKey: "goalHitOn")
    }

    /// 8 -> "8h", 7.5 -> "7.5h".
    private func hours(_ value: Double) -> String {
        String(format: "%gh", value)
    }

    // MARK: Menu

    private func menu() -> NSMenu {
        saved = nil
        let now = Date(), elapsed = stopwatch.elapsed(at: now)
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(withTitle: "Today  " + hoursAndMinutes(savedToday(now) + elapsed), action: nil, keyEquivalent: "")
            .isEnabled = false
        menu.addItem(.separator())
        let title = stopwatch.running ? "Stop" : elapsed > 0 ? "Resume" : "Start"
        menu.addItem(withTitle: title, action: #selector(toggle), keyEquivalent: "").target = self
        let end = menu.addItem(withTitle: "End and save", action: #selector(end), keyEquivalent: "")
        end.target = self
        end.isEnabled = elapsed > 0
        menu.addItem(.separator())

        // Tags carry the values: minutes after midnight for the reminder, half hours for the goal.
        let time = { (minutes: Int) in String(format: "%02d:%02d", minutes / 60, minutes % 60) }
        let remindAt = defaults.integer(forKey: "remindAt"), goal = defaults.double(forKey: "goalHours")
        let times = stride(from: 12 * 60, to: 24 * 60, by: 30).map { (time($0), $0) }
        let goals = (1...24).map { (hours(Double($0) / 2), $0) }
        menu.addItem(dropdown("Remind me at " + time(remindAt), times, selected: remindAt, action: #selector(reminderChanged)))
        menu.addItem(dropdown("Notify after " + hours(goal), goals, selected: Int(goal * 2), action: #selector(goalChanged)))

        menu.addItem(withTitle: "Open log", action: #selector(openLog), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Timer", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        return menu
    }

    /// A menu item that opens a submenu of (title, tag) choices, with a checkmark on the one tagged `selected`.
    /// A submenu because an `NSPopUpButton` in a menu item view doesn't open.
    private func dropdown(_ title: String, _ choices: [(String, Int)], selected: Int, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (title, tag) in choices {
            let choice = submenu.addItem(withTitle: title, action: action, keyEquivalent: "")
            choice.target = self
            choice.tag = tag
            choice.state = tag == selected ? .on : .off
        }
        item.submenu = submenu
        return item
    }
}
