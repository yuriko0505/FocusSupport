import AppKit
import UserNotifications
import UniformTypeIdentifiers

final class FocusSupportApp: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var menuCheckinItem: NSMenuItem!
    private var menuFocusItem: NSMenuItem!
    private var timer: Timer?
    private let notificationsEnabled: Bool

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
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        scheduleNextCheckin()
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

        let feedback: String
        if isWandering {
            feedback = "ぼんやりしてたみたいだね。今から集中モードに切り替えよう！"
        } else {
            feedback = "いい感じ！その調子で進めていこう。"
        }

        showAlert(title: "フィードバック", message: feedback)
    }

    @objc private func showLogs() {
        guard !todayLogs.isEmpty else {
            showAlert(title: "まだログがありません", message: "チェックインをしてみましょう！")
            return
        }

        var logText = "【今日の思考ログ】\n\n"
        for entry in todayLogs {
            let emoji = entry.type == "wandering" ? "😴" : "✨"
            logText += "\(emoji) \(entry.time) - \(entry.question)\n"
            logText += "   → \(entry.response)\n\n"
        }

        let logURL = logFileURL()
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try logText.write(to: logURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(logURL)
        } catch {
            showAlert(title: "保存に失敗", message: "ログの保存に失敗しました。")
        }
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
        var target = randomTimeInHour(from: now)
        if target <= now {
            if let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: now) {
                target = randomTimeInHour(from: nextHour)
            }
        }

        let waitSeconds = max(1, target.timeIntervalSince(now))
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: waitSeconds, repeats: false) { [weak self] _ in
            self?.triggerCheckin()
        }
    }

    private func triggerCheckin() {
        sendNotification()
        manualCheckin()
        scheduleNextCheckin()
    }

    private func randomTimeInHour(from date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = Int.random(in: 0...59)
        components.second = Int.random(in: 0...59)
        return Calendar.current.date(from: components) ?? date
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
        
        // レイアウトを強制的に実行
        alert.layout()
        
        // アイコンビューを見つけて非表示にする
        if let window = alert.window as NSWindow? {
            for subview in window.contentView?.subviews ?? [] {
                if subview is NSImageView && subview.frame.width < 100 {
                    subview.isHidden = true
                    subview.frame = .zero
                    subview.setFrameSize(.zero)
                    subview.removeFromSuperview()
                }
            }
        }

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

    private func saveImageSettings() {
        let defaults = UserDefaults.standard
        defaults.set(imageFiles, forKey: "imageFiles")
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

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private func logFileURL() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport", isDirectory: true)
        return dir!.appendingPathComponent("focus_support_log.txt")
    }
}

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let getStats: () -> (String, String, String)
    private let getQuestions: () -> [String]
    private let setQuestions: ([String]) -> Void
    private let getImages: () -> [String]
    private let addImage: (URL) -> Void
    private let removeImageAt: (Int) -> Void

    private var questions: [String] = []
    private var images: [String] = []
    private let questionsTableView = NSTableView()
    private let imagesTableView = NSTableView()
    private let inputField = NSTextField(string: "")
    private let cellVerticalPadding: CGFloat = 4
    private let rowHeight: CGFloat = 26

    init(getStats: @escaping () -> (String, String, String),
         getQuestions: @escaping () -> [String],
         setQuestions: @escaping ([String]) -> Void,
         getImages: @escaping () -> [String],
         addImage: @escaping (URL) -> Void,
         removeImageAt: @escaping (Int) -> Void) {
        self.getStats = getStats
        self.getQuestions = getQuestions
        self.setQuestions = setQuestions
        self.getImages = getImages
        self.addImage = addImage
        self.removeImageAt = removeImageAt

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "設定"
        window.contentMinSize = NSSize(width: 480, height: 400)
        window.isReleasedWhenClosed = false
        super.init(window: window)

        self.questions = getQuestions()
        self.images = getImages()
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        let statsItem = NSTabViewItem(identifier: "stats")
        statsItem.label = "統計"
        statsItem.view = buildStatsView()
        tabView.addTabViewItem(statsItem)

        let settingsItem = NSTabViewItem(identifier: "settings")
        settingsItem.label = "各種設定"
        settingsItem.view = buildSettingsView()
        tabView.addTabViewItem(settingsItem)
    }

    func refreshData() {
        questions = getQuestions()
        images = getImages()
        questionsTableView.reloadData()
        imagesTableView.reloadData()
    }

    private func buildStatsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 520))
        view.autoresizingMask = [.width, .height]

        let (checkins, focused, wandering) = getStats()
        let label = NSTextField(labelWithString:
            "総チェックイン: \(checkins)\n集中: \(focused)\nぼんやり: \(wandering)"
        )
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])

        return view
    }

    private func buildSettingsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 520))
        view.autoresizingMask = [.width, .height]

        let description = NSTextField(labelWithString: "通知時のコメント")
        description.translatesAutoresizingMaskIntoConstraints = false

        let descriptionSpacer = NSView()
        descriptionSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        let descriptionRow = NSStackView(views: [description, descriptionSpacer])
        descriptionRow.orientation = .horizontal
        descriptionRow.alignment = .centerY
        descriptionRow.distribution = .fill
        descriptionRow.translatesAutoresizingMaskIntoConstraints = false

        let questionsScroll = NSScrollView()
        questionsScroll.hasVerticalScroller = true
        questionsScroll.autohidesScrollers = true
        questionsScroll.translatesAutoresizingMaskIntoConstraints = false

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("question"))
        column.title = "コメント"
        column.resizingMask = .autoresizingMask
        questionsTableView.addTableColumn(column)
        questionsTableView.headerView = nil
        questionsTableView.delegate = self
        questionsTableView.dataSource = self
        questionsTableView.usesAlternatingRowBackgroundColors = true
        questionsTableView.rowHeight = rowHeight
        questionsTableView.frame = questionsScroll.bounds
        questionsTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        questionsScroll.documentView = questionsTableView

        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputField.placeholderString = "新しいコメントを入力"
        inputField.delegate = self
        let addButton = NSButton(title: "追加", target: self, action: #selector(addQuestion))
        addButton.setButtonType(.momentaryPushIn)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let removeButton = NSButton(title: "削除", target: self, action: #selector(removeQuestion))
        removeButton.setButtonType(.momentaryPushIn)
        removeButton.attributedTitle = NSAttributedString(
            string: "削除",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        let inputRow = NSStackView(views: [inputField, addButton, removeButton])
        inputRow.orientation = .horizontal
        inputRow.spacing = 8
        inputRow.alignment = .centerY
        inputRow.distribution = .fill
        inputRow.translatesAutoresizingMaskIntoConstraints = false

        let imageDescription = NSTextField(labelWithString: "画像")
        imageDescription.translatesAutoresizingMaskIntoConstraints = false

        let imagesScroll = NSScrollView()
        imagesScroll.hasVerticalScroller = true
        imagesScroll.autohidesScrollers = true
        imagesScroll.translatesAutoresizingMaskIntoConstraints = false

        let imgColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("image"))
        imgColumn.title = "画像"
        imgColumn.resizingMask = .autoresizingMask
        imagesTableView.addTableColumn(imgColumn)
        imagesTableView.headerView = nil
        imagesTableView.delegate = self
        imagesTableView.dataSource = self
        imagesTableView.usesAlternatingRowBackgroundColors = true
        imagesTableView.rowHeight = rowHeight
        imagesTableView.frame = imagesScroll.bounds
        imagesTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        imagesScroll.documentView = imagesTableView

        let addImageButton = NSButton(title: "画像追加", target: self, action: #selector(addImageFromPicker))
        addImageButton.setButtonType(.momentaryPushIn)
        addImageButton.translatesAutoresizingMaskIntoConstraints = false

        let imageSpacer = NSView()
        imageSpacer.translatesAutoresizingMaskIntoConstraints = false
        imageSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let removeImageButton = NSButton(title: "削除", target: self, action: #selector(removeImage))
        removeImageButton.setButtonType(.momentaryPushIn)
        removeImageButton.attributedTitle = NSAttributedString(
            string: "削除",
            attributes: [.foregroundColor: NSColor.systemRed]
        )
        removeImageButton.translatesAutoresizingMaskIntoConstraints = false

        let imageButtons = NSStackView(views: [addImageButton, imageSpacer, removeImageButton])
        imageButtons.orientation = .horizontal
        imageButtons.spacing = 8
        imageButtons.alignment = .centerY
        imageButtons.distribution = .fill
        imageButtons.translatesAutoresizingMaskIntoConstraints = false

        let imageDescriptionSpacer = NSView()
        imageDescriptionSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let imageDescriptionRow = NSStackView(views: [imageDescription, imageDescriptionSpacer])
        imageDescriptionRow.orientation = .horizontal
        imageDescriptionRow.alignment = .centerY
        imageDescriptionRow.distribution = .fill
        imageDescriptionRow.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = NSStackView(views: [
            descriptionRow,
            questionsScroll,
            inputRow,
            imageDescriptionRow,
            imagesScroll,
            imageButtons
        ])
        contentStack.orientation = .vertical
        contentStack.spacing = 10
        contentStack.alignment = .trailing
        contentStack.distribution = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(contentStack)

        questionsScroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        questionsScroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imagesScroll.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imagesScroll.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        inputRow.setContentHuggingPriority(.defaultLow, for: .horizontal)
        inputRow.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageButtons.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),

            questionsScroll.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            questionsScroll.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            imagesScroll.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            imagesScroll.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),

            inputRow.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            inputRow.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
            imageButtons.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            imageButtons.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),

            inputField.heightAnchor.constraint(equalToConstant: 24),
            addButton.widthAnchor.constraint(equalToConstant: 60),
            removeButton.widthAnchor.constraint(equalToConstant: 60),
            addImageButton.widthAnchor.constraint(equalToConstant: 80),
            removeImageButton.widthAnchor.constraint(equalToConstant: 60),

            questionsScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            imagesScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            questionsScroll.heightAnchor.constraint(equalTo: imagesScroll.heightAnchor)
        ])

        return view
    }

    @objc private func addQuestion() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        questions.append(text)
        setQuestions(questions)
        inputField.stringValue = ""
        questionsTableView.reloadData()
    }

    @objc private func removeQuestion() {
        let row = questionsTableView.selectedRow
        guard row >= 0 && row < questions.count else { return }
        questions.remove(at: row)
        setQuestions(questions)
        questionsTableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView == questionsTableView {
            return questions.count
        }
        return images.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView == questionsTableView {
            return makeTextCell(
                tableView: tableView,
                identifier: "questionCell",
                text: questions[row],
                isEditable: true
            )
        }
        return makeTextCell(
            tableView: tableView,
            identifier: "imageCell",
            text: images[row],
            isEditable: false
        )
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }
        if textField == inputField {
            return
        }
        let row = questionsTableView.row(for: textField)
        guard row >= 0 && row < questions.count else { return }
        questions[row] = textField.stringValue
        setQuestions(questions)
    }

    @objc private func addImageFromPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.addImage(url)
            self?.images = self?.getImages() ?? []
            self?.imagesTableView.reloadData()
        }
    }

    @objc private func removeImage() {
        let row = imagesTableView.selectedRow
        guard row >= 0 && row < images.count else { return }
        removeImageAt(row)
        images = getImages()
        imagesTableView.reloadData()
    }

    private func makeTextCell(tableView: NSTableView,
                              identifier: String,
                              text: String,
                              isEditable: Bool) -> NSTableCellView {
        let cellId = NSUserInterfaceItemIdentifier(identifier)
        let cell: NSTableCellView
        if let existing = tableView.makeView(withIdentifier: cellId, owner: self) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = cellId

            let textField = NSTextField()
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.isEditable = isEditable
            textField.usesSingleLineMode = true
            textField.lineBreakMode = .byTruncatingTail
            textField.translatesAutoresizingMaskIntoConstraints = false
            if isEditable {
                textField.delegate = self
            }

            cell.textField = textField
            cell.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
                textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: cellVerticalPadding),
                textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -cellVerticalPadding)
            ])
        }
        cell.textField?.isEditable = isEditable
        cell.textField?.stringValue = text
        return cell
    }
}

let app = NSApplication.shared
let delegate = FocusSupportApp()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
