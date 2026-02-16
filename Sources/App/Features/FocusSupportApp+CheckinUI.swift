import AppKit
import UserNotifications

private final class CheckinInputTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if modifiers == .command, key == "v" {
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

extension FocusSupportApp {
    private struct CheckinInputResult {
        let responseText: String
        let state: CheckinState
    }

    func alertIconImage() -> NSImage? {
        guard let image = appIconImage() else { return nil }
        let targetSize = NSSize(width: 64, height: 64)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()
        return resized
    }

    @objc func manualCheckin() {
        randomizePromptImageIfNeeded()
        checkinCount += 1
        updateMenuStats()
        let question = questions.randomElement() ?? "今何してる？"
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let response = self.promptForResponse(question: question)
            guard let result = response else {
                return
            }

            self.processResponse(question: question, userInput: result.responseText, state: result.state)
        }
    }

    func processResponse(question: String, userInput: String, state: CheckinState) {
        switch state {
        case .focused:
            focusedCount += 1
        case .wandering:
            wanderingCount += 1
        case .resting:
            restingCount += 1
        }
        updateMenuStats()

        let timeText = timeFormatter.string(from: Date())
        let entry = LogEntry(time: timeText, response: userInput, type: state.rawValue)
        todayLogs.append(entry)
        appendLogEntry(entry)

        showAlert(title: "フィードバック", message: state.feedbackMessage)
    }

    @objc func showLogsMenuTapped() {
        DispatchQueue.main.async { [weak self] in
            self?.showLogsWindow()
        }
    }

    func showLogsWindow() {
        let logURL = logFileURL(for: Date())
        let logEntries = readLogEntries(from: logURL) ?? []

        if logWindowController == nil {
            logWindowController = LogWindowController()
        }
        guard let logWindowController else {
            showAlert(title: "表示に失敗", message: "ログウィンドウを開けませんでした。")
            return
        }

        logWindowController.setLogEntries(logEntries)
        logWindowController.showWindow(nil)
        guard let window = logWindowController.window else {
            showAlert(title: "表示に失敗", message: "ログウィンドウの初期化に失敗しました。")
            return
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(
                getStats: { [weak self] in
                    guard let self else { return ("0回", "0回", "0回", "0回") }
                    return ("\(self.checkinCount)回", "\(self.focusedCount)回", "\(self.wanderingCount)回", "\(self.restingCount)回")
                },
                getRecentDailyLogBreakdowns: { [weak self] days in
                    guard let self else { return [] }
                    return self.recentDailyLogBreakdowns(days: days).map {
                        SettingsWindowController.DailyLogBreakdown(
                            date: $0.date,
                            focused: $0.focused,
                            wandering: $0.wandering,
                            resting: $0.resting
                        )
                    }
                },
                getQuestions: { [weak self] in
                    return self?.questions ?? []
                },
                setQuestions: { [weak self] newQuestions in
                    self?.questions = newQuestions
                    self?.saveQuestionSettings()
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
                getAppIconFileName: { [weak self] in
                    return self?.appIconFileName
                },
                setAppIcon: { [weak self] url in
                    self?.importAppIcon(url: url)
                },
                resetAppIcon: { [weak self] in
                    self?.removeAppIcon()
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

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func promptForResponse(question: String) -> CheckinInputResult? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = question
        alert.alertStyle = .informational
        if let icon = alertIconImage() {
            alert.icon = icon
        } else {
            // Keep previous look when no custom icon is configured.
            let transparentImage = NSImage(size: NSSize(width: 1, height: 1))
            transparentImage.lockFocus()
            NSColor.clear.set()
            NSBezierPath.fill(NSRect(x: 0, y: 0, width: 1, height: 1))
            transparentImage.unlockFocus()
            alert.icon = transparentImage
        }

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 280))

        var yPosition: CGFloat = 280

        if let image = currentPromptImage() {
            let imageView = NSImageView(frame: NSRect(x: 0, y: yPosition - 196, width: 320, height: 196))
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            containerView.addSubview(imageView)
            yPosition -= 196
        }

        let stateLabel = NSTextField(labelWithString: "今の状態")
        stateLabel.frame = NSRect(x: 0, y: yPosition - 40, width: 90, height: 20)
        containerView.addSubview(stateLabel)

        let stateSelector = NSSegmentedControl(
            labels: [
                CheckinState.focused.label,
                CheckinState.wandering.label,
                CheckinState.resting.label
            ],
            trackingMode: .selectOne,
            target: nil,
            action: nil
        )
        stateSelector.frame = NSRect(x: 96, y: yPosition - 42, width: 224, height: 24)
        stateSelector.selectedSegment = 0
        containerView.addSubview(stateSelector)

        let inputField = CheckinInputTextField(frame: NSRect(x: 0, y: yPosition - 74, width: 320, height: 24))
        inputField.placeholderString = "今の思考を一言で書いてください"
        containerView.addSubview(inputField)

        alert.accessoryView = containerView

        alert.addButton(withTitle: "送信")
        alert.addButton(withTitle: "スキップ")

        let alertWindow = alert.window
        alertWindow.initialFirstResponder = inputField
        alertWindow.makeFirstResponder(inputField)

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else {
                return nil
            }
            let selectedState: CheckinState
            switch stateSelector.selectedSegment {
            case 1:
                selectedState = .wandering
            case 2:
                selectedState = .resting
            default:
                selectedState = .focused
            }
            return CheckinInputResult(responseText: text, state: selectedState)
        }
        return nil
    }

    func currentPromptImage() -> NSImage? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageStorageFiles.count else {
            return nil
        }
        return loadImage(named: imageStorageFiles[index])
    }

    func currentNotificationAttachment() -> UNNotificationAttachment? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageStorageFiles.count else {
            return nil
        }
        guard let url = safeImageFileURL(fileName: imageStorageFiles[index]) else {
            return nil
        }
        return try? UNNotificationAttachment(identifier: "promptImage", url: url, options: nil)
    }

    func showAlert(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        if let icon = alertIconImage() {
            alert.icon = icon
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func updateMenuStats() {
        menuCheckinItem.title = "今日のチェックイン: \(checkinCount)回"
        menuFocusItem.title = "集中: \(focusedCount)回 / ぼんやり: \(wanderingCount)回 / 休憩中: \(restingCount)回"
    }

    func randomizePromptImageIfNeeded() {
        guard !imageStorageFiles.isEmpty else { return }
        currentImageIndex = Int.random(in: 0..<imageStorageFiles.count)
    }
}
