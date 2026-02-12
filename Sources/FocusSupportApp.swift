import AppKit
import UserNotifications
import UniformTypeIdentifiers

final class FocusSupportApp: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var menuCheckinItem: NSMenuItem!
    private var menuFocusItem: NSMenuItem!
    private var timer: Timer?
    private var schedulingObserversRegistered = false
    private let notificationsEnabled: Bool
    private var notificationStartHour: Int = 9
    private var notificationEndHour: Int = 20

    private var checkinCount = 0
    private var focusedCount = 0
    private var wanderingCount = 0
    private var todayLogs: [LogEntry] = []
    private var questions: [String] = [
        "今何してる？",
        "今の作業、計画的？それとも逃避？",
        "集中できてる？",
        "今やってることを10秒で説明してみて",
        "ぼーっとしてない？",
        "今の作業、本当に優先度高い？"
    ]
    private var imageFiles: [String] = []
    private var currentImageIndex: Int?

    private var settingsWindowController: SettingsWindowController?
    private var logWindowController: LogWindowController?

    private struct LogEntry {
        let time: String
        let question: String
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
        if let button = statusItem.button {
            button.title = "🧠"
        }

        let menu = NSMenu()
        menuCheckinItem = NSMenuItem(title: "今日のチェックイン: 0回", action: nil, keyEquivalent: "")
        menuFocusItem = NSMenuItem(title: "集中: 0回 / ぼんやり: 0回", action: nil, keyEquivalent: "")
        menu.addItem(menuCheckinItem)
        menu.addItem(menuFocusItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "今すぐ壁打ち", action: #selector(manualCheckin), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "今日のログを見る", action: #selector(showLogs), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "設定", action: #selector(showSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quitApp), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu

        loadImageSettings()
        loadNotificationTimeSettings()
        registerSchedulingObserversIfNeeded()
        scheduleNextCheckin()
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        unregisterSchedulingObservers()
    }

    @objc private func manualCheckin() {
        randomizePromptImageIfNeeded()
        checkinCount += 1
        updateMenuStats()
        let question = questions.randomElement() ?? "今何してる？"
        let response = promptForResponse(question: question)
        guard let responseText = response?.trimmingCharacters(in: .whitespacesAndNewlines), !responseText.isEmpty else {
            return
        }

        processResponse(question: question, userInput: responseText)
    }

    private func processResponse(question: String, userInput: String) {
        let wanderingKeywords = ["ぼーっと", "特に", "わからない", "なんとなく", "暇"]
        let isWandering = wanderingKeywords.contains { userInput.contains($0) }

        if isWandering {
            wanderingCount += 1
        } else {
            focusedCount += 1
        }
        updateMenuStats()

        let timeText = timeFormatter.string(from: Date())
        let entry = LogEntry(time: timeText, question: question, response: userInput, type: isWandering ? "wandering" : "focused")
        todayLogs.append(entry)
        appendLogEntry(entry)

        let feedback: String
        if isWandering {
            feedback = "ぼんやりしてたみたいだね。今から集中モードに切り替えよう！"
        } else {
            feedback = "いい感じ！その調子で進めていこう。"
        }

        showAlert(title: "フィードバック", message: feedback)
    }

    @objc private func showLogs() {
        let logURL = logFileURL(for: Date())
        guard let logText = readLogText(from: logURL) else {
            showAlert(title: "まだログがありません", message: "チェックインをしてみましょう！")
            return
        }

        let decoratedText = "【今日の思考ログ】\n\n" + logText
        if logWindowController == nil {
            logWindowController = LogWindowController()
        }
        logWindowController?.setLogText(decoratedText)
        logWindowController?.showWindow(nil)
        logWindowController?.window?.center()
        logWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                getStats: { [weak self] in
                    guard let self else { return ("0回", "0回", "0回") }
                    return ("\(self.checkinCount)回", "\(self.focusedCount)回", "\(self.wanderingCount)回")
                },
                getQuestions: { [weak self] in
                    return self?.questions ?? []
                },
                setQuestions: { [weak self] newQuestions in
                    self?.questions = newQuestions
                },
                getImages: { [weak self] in
                    return self?.imageFiles ?? []
                },
                addImage: { [weak self] url in
                    self?.importImage(url: url)
                },
                removeImageAt: { [weak self] index in
                    self?.removeImage(at: index)
                },
                getNotificationHours: { [weak self] in
                    guard let self else { return (9, 20) }
                    return (self.notificationStartHour, self.notificationEndHour)
                },
                setNotificationHours: { [weak self] startHour, endHour in
                    self?.notificationStartHour = startHour
                    self?.notificationEndHour = endHour
                    self?.saveNotificationTimeSettings()
                    self?.scheduleNextCheckin()
                }
            )
        }

        settingsWindowController?.refreshData()
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func scheduleNextCheckin() {
        let now = Date()
        let target = nextAllowedCheckinTime(from: now)

        let waitSeconds = max(1, target.timeIntervalSince(now))
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: waitSeconds, repeats: false) { [weak self] _ in
            self?.triggerCheckin()
        }
    }

    private func registerSchedulingObserversIfNeeded() {
        guard schedulingObserversRegistered == false else { return }
        schedulingObserversRegistered = true

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSCalendarDayChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSSystemClockDidChange,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSSystemTimeZoneDidChange,
                           object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(handleSchedulingContextChanged(_:)),
                                                          name: NSWorkspace.didWakeNotification,
                                                          object: nil)
    }

    private func unregisterSchedulingObservers() {
        guard schedulingObserversRegistered else { return }
        schedulingObserversRegistered = false
        NotificationCenter.default.removeObserver(self, name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSSystemClockDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSSystemTimeZoneDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc private func handleSchedulingContextChanged(_ notification: Notification) {
        scheduleNextCheckin()
    }

    private func triggerCheckin() {
        sendNotification()
        scheduleNextCheckin()
    }

    private func randomTimeInHour(from date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = Int.random(in: 0...59)
        components.second = Int.random(in: 0...59)
        return Calendar.current.date(from: components) ?? date
    }

    private func nextAllowedCheckinTime(from now: Date) -> Date {
        let calendar = Calendar.current
        guard let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start else {
            return now.addingTimeInterval(60)
        }

        for offset in 0...48 {
            guard let hourDate = calendar.date(byAdding: .hour, value: offset, to: startOfHour) else { continue }
            let hour = calendar.component(.hour, from: hourDate)
            guard isHourAllowed(hour) else { continue }
            let target = randomTimeInHour(from: hourDate)
            if target > now {
                return target
            }
        }

        return now.addingTimeInterval(3600)
    }

    private func isHourAllowed(_ hour: Int) -> Bool {
        if notificationStartHour == notificationEndHour {
            return true
        }
        if notificationStartHour < notificationEndHour {
            return hour >= notificationStartHour && hour < notificationEndHour
        }
        return hour >= notificationStartHour || hour < notificationEndHour
    }

    private func sendNotification() {
        guard notificationsEnabled else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Focus Support"
        content.subtitle = "今何考えてる？"
        content.body = "クリックして思考を共有してください 🤔"
        content.sound = .default
        if let attachment = currentNotificationAttachment() {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func ensureNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            // 許可直後に一度通知を出す
                            self.sendNotification()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert(title: "通知が許可されていません",
                                           message: "システム設定の通知からFocusSupportを許可してください。")
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self.showAlert(title: "通知が許可されていません",
                                   message: "システム設定の通知からFocusSupportを許可してください。")
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    // バナー表示中にアプリが前面でも通知を表示させる
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // バナークリックでチェックイン画面を表示
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                self?.manualCheckin()
            }
        }
        completionHandler()
    }

    private func promptForResponse(question: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = question
        alert.alertStyle = .informational
        
        // 透明な画像を作成してアイコンを非表示にする
        let transparentImage = NSImage(size: NSSize(width: 1, height: 1))
        transparentImage.lockFocus()
        NSColor.clear.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 1, height: 1))
        transparentImage.unlockFocus()
        alert.icon = transparentImage

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 240))
        
        var yPosition: CGFloat = 240
        
        if let image = currentPromptImage() {
            let imageView = NSImageView(frame: NSRect(x: 0, y: yPosition - 196, width: 320, height: 196))
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            containerView.addSubview(imageView)
            yPosition -= 196
        }
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: yPosition - 40, width: 320, height: 24))
        inputField.placeholderString = "今の思考を一言で書いてください"
        containerView.addSubview(inputField)
        
        alert.accessoryView = containerView

        alert.addButton(withTitle: "送信")
        alert.addButton(withTitle: "スキップ")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return inputField.stringValue
        }
        return nil
    }

    private func currentPromptImage() -> NSImage? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageFiles.count else {
            return nil
        }
        return loadImage(named: imageFiles[index])
    }

    private func currentNotificationAttachment() -> UNNotificationAttachment? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageFiles.count else {
            return nil
        }
        let url = imagesDirectory().appendingPathComponent(imageFiles[index])
        return try? UNNotificationAttachment(identifier: "promptImage", url: url, options: nil)
    }

    private func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func updateMenuStats() {
        menuCheckinItem.title = "今日のチェックイン: \(checkinCount)回"
        menuFocusItem.title = "集中: \(focusedCount)回 / ぼんやり: \(wanderingCount)回"
    }

    private func loadImage(named fileName: String) -> NSImage? {
        let url = imagesDirectory().appendingPathComponent(fileName)
        guard let originalImage = NSImage(contentsOf: url) else { return nil }
        
        let maxSize: CGFloat = 196
        let originalSize = originalImage.size
        let aspectRatio = originalSize.width / originalSize.height
        
        let newSize: NSSize
        if aspectRatio > 1 {
            // 横長
            newSize = NSSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            // 縦長または正方形
            newSize = NSSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        let resizedImage = NSImage(size: newSize)
        resizedImage.lockFocus()
        originalImage.draw(in: NSRect(origin: .zero, size: newSize))
        resizedImage.unlockFocus()
        
        return resizedImage
    }

    private func loadImageSettings() {
        let defaults = UserDefaults.standard
        imageFiles = defaults.stringArray(forKey: "imageFiles") ?? []
    }

    private func loadNotificationTimeSettings() {
        let defaults = UserDefaults.standard
        let start = defaults.integer(forKey: "notificationStartHour")
        let end = defaults.integer(forKey: "notificationEndHour")
        notificationStartHour = start == 0 && defaults.object(forKey: "notificationStartHour") == nil ? 9 : start
        notificationEndHour = end == 0 && defaults.object(forKey: "notificationEndHour") == nil ? 20 : end
    }

    private func saveImageSettings() {
        let defaults = UserDefaults.standard
        defaults.set(imageFiles, forKey: "imageFiles")
    }

    private func saveNotificationTimeSettings() {
        let defaults = UserDefaults.standard
        defaults.set(notificationStartHour, forKey: "notificationStartHour")
        defaults.set(notificationEndHour, forKey: "notificationEndHour")
    }

    private func imagesDirectory() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport/Images", isDirectory: true)
        return dir!
    }

    private func importImage(url: URL) {
        do {
            let dir = imagesDirectory()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileName = url.lastPathComponent
            let target = dir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: target.path) == false {
                try FileManager.default.copyItem(at: url, to: target)
            }
            if imageFiles.contains(fileName) == false {
                imageFiles.append(fileName)
            }
            saveImageSettings()
        } catch {
            showAlert(title: "画像の追加に失敗", message: "画像の追加に失敗しました。別の画像で試してください。")
        }
    }

    private func removeImage(at index: Int) {
        guard index >= 0 && index < imageFiles.count else { return }
        let fileName = imageFiles[index]
        let url = imagesDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        imageFiles.remove(at: index)
        saveImageSettings()
    }

    private func randomizePromptImageIfNeeded() {
        guard !imageFiles.isEmpty else { return }
        currentImageIndex = Int.random(in: 0..<imageFiles.count)
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func logsDirectory() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport/Logs", isDirectory: true)
        return dir!
    }

    private func logFileURL(for date: Date) -> URL {
        let dateText = dateFormatter.string(from: date)
        return logsDirectory().appendingPathComponent("log_\(dateText).log")
    }

    private func appendLogEntry(_ entry: LogEntry) {
        let emoji = entry.type == "wandering" ? "😴" : "✨"
        let line = "\(emoji) \(entry.time) - \(entry.question)\n   → \(entry.response)\n\n"
        let data = Data(line.utf8)
        let url = logFileURL(for: Date())
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            showAlert(title: "保存に失敗", message: "ログの保存に失敗しました。")
        }
    }

    private func readLogText(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

}
