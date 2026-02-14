import AppKit
import UserNotifications

final class FocusSupportApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var menuCheckinItem: NSMenuItem!
    var menuFocusItem: NSMenuItem!
    var timer: Timer?
    var schedulingObserversRegistered = false
    let notificationsEnabled: Bool
    var notificationStartHour: Int = 9
    var notificationEndHour: Int = 20

    var checkinCount = 0
    var focusedCount = 0
    var wanderingCount = 0
    var todayLogs: [LogEntry] = []
    var questions: [String] = [
        "今何してる？",
        "今の作業、計画的？それとも逃避？",
        "集中できてる？",
        "今やってることを10秒で説明してみて",
        "ぼーっとしてない？",
        "今の作業、本当に優先度高い？"
    ]
    var imageFiles: [String] = []
    var appIconFileName: String?
    var currentImageIndex: Int?

    var settingsWindowController: SettingsWindowController?
    var logWindowController: LogWindowController?
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    struct LogEntry {
        let time: String
        let response: String
        let type: String
    }

    override init() {
        // SwiftPMの`swift run`は.appバンドルではないため通知APIが落ちる。
        // .appバンドル実行時のみ通知を有効化する。
        let bundlePath = Bundle.main.bundlePath
        self.notificationsEnabled = bundlePath.hasSuffix(".app")
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if notificationsEnabled {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            ensureNotificationAuthorization()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyStatusItemIcon()

        let menu = NSMenu()
        menuCheckinItem = NSMenuItem(title: "今日のチェックイン: 0回", action: nil, keyEquivalent: "")
        menuFocusItem = NSMenuItem(title: "集中: 0回 / ぼんやり: 0回", action: nil, keyEquivalent: "")
        menu.addItem(menuCheckinItem)
        menu.addItem(menuFocusItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "今すぐ壁打ち", action: #selector(manualCheckin), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "今日のログを見る", action: #selector(showLogsMenuTapped), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "設定", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        loadQuestionSettings()
        loadImageSettings()
        loadAppIconSettings()
        applyStatusItemIcon()
        loadNotificationTimeSettings()
        registerSchedulingObserversIfNeeded()
        scheduleNextCheckin()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        unregisterSchedulingObservers()
    }
}
