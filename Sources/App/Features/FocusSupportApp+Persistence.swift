import AppKit

extension FocusSupportApp {
    private struct PersistedLogEntry: Codable {
        let time: String
        let response: String
    }

    func isValidImageFileName(_ fileName: String) -> Bool {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if trimmed == "." || trimmed == ".." { return false }
        if trimmed.contains("/") || trimmed.contains(":") { return false }
        return true
    }

    func safeImageFileURL(fileName: String) -> URL? {
        guard isValidImageFileName(fileName) else { return nil }
        let dir = imagesDirectory().resolvingSymlinksInPath()
        let fileURL = dir.appendingPathComponent(fileName).resolvingSymlinksInPath()
        let dirPrefix = dir.path.hasSuffix("/") ? dir.path : dir.path + "/"
        guard fileURL.path.hasPrefix(dirPrefix) else { return nil }
        return fileURL
    }

    func existingImageFileNames() -> [String] {
        let dir = imagesDirectory()
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return items
            .filter { $0.hasDirectoryPath == false }
            .map(\.lastPathComponent)
            .filter(isValidImageFileName)
            .sorted()
    }

    func loadImage(named fileName: String) -> NSImage? {
        guard let url = safeImageFileURL(fileName: fileName) else { return nil }
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

    func loadImageSettings() {
        let defaults = UserDefaults.standard
        let configuredFiles = (defaults.stringArray(forKey: "imageFiles") ?? []).filter(isValidImageFileName)
        let existingFiles = existingImageFileNames()

        if configuredFiles.isEmpty {
            // Recover from missing UserDefaults by rebuilding the list from local files.
            imageFiles = existingFiles
            if existingFiles.isEmpty == false {
                saveImageSettings()
            }
            return
        }

        let existingSet = Set(existingFiles)
        var reconciled = configuredFiles.filter { existingSet.contains($0) }

        // Include files that exist on disk but are not in defaults yet.
        for fileName in existingFiles where reconciled.contains(fileName) == false {
            reconciled.append(fileName)
        }

        imageFiles = reconciled
        if imageFiles != configuredFiles {
            saveImageSettings()
        }
    }

    func loadQuestionSettings() {
        let defaults = UserDefaults.standard
        guard let savedQuestions = defaults.stringArray(forKey: "questions") else {
            return
        }
        questions = savedQuestions
    }

    func loadAppIconSettings() {
        let defaults = UserDefaults.standard
        appIconFileName = defaults.string(forKey: "appIconFileName")
    }

    func loadNotificationTimeSettings() {
        let defaults = UserDefaults.standard
        let start = defaults.integer(forKey: "notificationStartHour")
        let end = defaults.integer(forKey: "notificationEndHour")
        notificationStartHour = start == 0 && defaults.object(forKey: "notificationStartHour") == nil ? 9 : start
        notificationEndHour = end == 0 && defaults.object(forKey: "notificationEndHour") == nil ? 20 : end
    }

    func saveImageSettings() {
        let defaults = UserDefaults.standard
        defaults.set(imageFiles, forKey: "imageFiles")
    }

    func saveQuestionSettings() {
        let defaults = UserDefaults.standard
        defaults.set(questions, forKey: "questions")
    }

    func saveAppIconSettings() {
        let defaults = UserDefaults.standard
        defaults.set(appIconFileName, forKey: "appIconFileName")
    }

    func saveNotificationTimeSettings() {
        let defaults = UserDefaults.standard
        defaults.set(notificationStartHour, forKey: "notificationStartHour")
        defaults.set(notificationEndHour, forKey: "notificationEndHour")
    }

    func imagesDirectory() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport/Images", isDirectory: true)
        return dir!
    }

    func appIconDirectory() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport/AppIcon", isDirectory: true)
        return dir!
    }

    func importImage(url: URL) {
        do {
            let dir = imagesDirectory()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileName = url.lastPathComponent
            guard isValidImageFileName(fileName) else {
                showAlert(title: "画像の追加に失敗", message: "画像ファイル名が不正です。別の画像で試してください。")
                return
            }
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

    func removeImage(at index: Int) {
        guard index >= 0 && index < imageFiles.count else { return }
        let fileName = imageFiles[index]
        if let fileURL = safeImageFileURL(fileName: fileName) {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        imageFiles.remove(at: index)
        saveImageSettings()
    }

    func appIconImage() -> NSImage? {
        guard let fileName = appIconFileName else { return nil }
        let url = appIconDirectory().appendingPathComponent(fileName)
        return NSImage(contentsOf: url)
    }

    func resizedStatusIcon(from image: NSImage) -> NSImage {
        // Menu bar icon should fit the status bar height with a small margin.
        let iconSize = max(14, NSStatusBar.system.thickness - 6)
        let targetSize = NSSize(width: iconSize, height: iconSize)

        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        resized.unlockFocus()
        resized.size = targetSize
        return resized
    }

    func applyStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        if let image = appIconImage() {
            let icon = resizedStatusIcon(from: image)
            button.image = icon
            button.imageScaling = .scaleNone
            button.title = ""
        } else {
            button.image = nil
            button.title = "🧠"
        }
    }

    func importAppIcon(url: URL) {
        do {
            let dir = appIconDirectory()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension.lowercased()
            let fileName = "status_icon.\(ext)"
            let target = dir.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: url, to: target)

            appIconFileName = fileName
            saveAppIconSettings()
            applyStatusItemIcon()
        } catch {
            showAlert(title: "アイコン設定に失敗", message: "アプリアイコンの設定に失敗しました。別の画像で試してください。")
        }
    }

    func removeAppIcon() {
        if let fileName = appIconFileName {
            let url = appIconDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        appIconFileName = nil
        saveAppIconSettings()
        applyStatusItemIcon()
    }

    func logsDirectory() -> URL {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = baseDir?.appendingPathComponent("FocusSupport/Logs", isDirectory: true)
        return dir!
    }

    func logFileURL(for date: Date) -> URL {
        let dateText = dateFormatter.string(from: date)
        return logsDirectory().appendingPathComponent("log_\(dateText).log")
    }

    func appendLogEntry(_ entry: LogEntry) {
        let persisted = PersistedLogEntry(time: entry.time, response: entry.response)
        guard let encoded = try? JSONEncoder().encode(persisted) else {
            showAlert(title: "保存に失敗", message: "ログの保存に失敗しました。")
            return
        }
        let data = encoded + Data("\n".utf8)
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

    func readLogText(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    func readLogEntries(from url: URL) -> [LogWindowController.LogItem]? {
        guard let text = readLogText(from: url), text.isEmpty == false else {
            return nil
        }

        let decoded = parseJSONLineEntries(text)
        if decoded.isEmpty == false {
            return decoded
        }

        return parseLegacyPlainEntries(text)
    }

    private func parseJSONLineEntries(_ text: String) -> [LogWindowController.LogItem] {
        let decoder = JSONDecoder()
        let lines = text.split(whereSeparator: \.isNewline)
        var items: [LogWindowController.LogItem] = []
        items.reserveCapacity(lines.count)

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(PersistedLogEntry.self, from: data) else {
                continue
            }
            items.append(LogWindowController.LogItem(time: entry.time, response: entry.response))
        }

        return items
    }

    private func parseLegacyPlainEntries(_ text: String) -> [LogWindowController.LogItem] {
        let pattern = #"^[^\d]*(\d{2}:\d{2})\s*-\s*.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }

        let lines = text.split(whereSeparator: \.isNewline)
        var items: [LogWindowController.LogItem] = []
        var i = 0

        while i < lines.count {
            let headerLine = String(lines[i])
            let range = NSRange(location: 0, length: headerLine.utf16.count)
            if let match = regex.firstMatch(in: headerLine, options: [], range: range),
               let timeRange = Range(match.range(at: 1), in: headerLine),
               i + 1 < lines.count {
                var responseLine = String(lines[i + 1]).trimmingCharacters(in: .whitespaces)
                if responseLine.hasPrefix("→") {
                    responseLine.removeFirst()
                    responseLine = responseLine.trimmingCharacters(in: .whitespaces)
                }
                if responseLine.isEmpty == false {
                    let time = String(headerLine[timeRange])
                    items.append(LogWindowController.LogItem(time: time, response: responseLine))
                }
                i += 2
                continue
            }
            i += 1
        }

        return items
    }
}
