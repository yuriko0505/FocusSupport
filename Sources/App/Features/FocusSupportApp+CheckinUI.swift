import AppKit
import UserNotifications

extension FocusSupportApp {
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
        let response = promptForResponse(question: question)
        guard let responseText = response?.trimmingCharacters(in: .whitespacesAndNewlines), !responseText.isEmpty else {
            return
        }

        processResponse(question: question, userInput: responseText)
    }

    func processResponse(question: String, userInput: String) {
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

    @objc func showLogs() {
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

    @objc func showSettings() {
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

    func promptForResponse(question: String) -> String? {
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

    func currentPromptImage() -> NSImage? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageFiles.count else {
            return nil
        }
        return loadImage(named: imageFiles[index])
    }

    func currentNotificationAttachment() -> UNNotificationAttachment? {
        guard let index = currentImageIndex,
              index >= 0,
              index < imageFiles.count else {
            return nil
        }
        let url = imagesDirectory().appendingPathComponent(imageFiles[index])
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
        menuFocusItem.title = "集中: \(focusedCount)回 / ぼんやり: \(wanderingCount)回"
    }

    func randomizePromptImageIfNeeded() {
        guard !imageFiles.isEmpty else { return }
        currentImageIndex = Int.random(in: 0..<imageFiles.count)
    }
}
