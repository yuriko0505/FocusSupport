import AppKit

extension FocusSupportApp {
    private struct PersistedLogEntry: Codable {
        let time: String
        let response: String
        let type: String?
    }

    private struct PersistedImageEntry: Codable {
        let displayName: String
        let storageName: String
    }

    func isValidImageFileName(_ fileName: String) -> Bool {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if trimmed == "." || trimmed == ".." { return false }
        if trimmed.contains("/") || trimmed.contains(":") { return false }
        return true
    }

    func imageEntriesDefaultsKey() -> String {
        "imageEntriesV2"
    }

    func sanitizeImageDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "image" : trimmed
    }

    func fileExistsAsRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    func makeManagedImageFileName(originalURL: URL) -> String {
        let rawExt = originalURL.pathExtension.lowercased()
        let ext = isValidImageFileName(rawExt) ? rawExt : "png"
        return "img_\(UUID().uuidString).\(ext)"
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
        try? FileManager.default.createDirectory(at: imagesDirectory(), withIntermediateDirectories: true)

        if let data = defaults.data(forKey: imageEntriesDefaultsKey()),
           let decoded = try? JSONDecoder().decode([PersistedImageEntry].self, from: data) {
            var displayNames: [String] = []
            var storageNames: [String] = []
            var seenStorageNames = Set<String>()
            for entry in decoded {
                guard isValidImageFileName(entry.storageName),
                      seenStorageNames.contains(entry.storageName) == false,
                      let fileURL = safeImageFileURL(fileName: entry.storageName),
                      fileExistsAsRegularFile(fileURL) else {
                    continue
                }
                seenStorageNames.insert(entry.storageName)
                displayNames.append(sanitizeImageDisplayName(entry.displayName))
                storageNames.append(entry.storageName)
            }
            imageFiles = displayNames
            imageStorageFiles = storageNames
            if displayNames.count != decoded.count {
                saveImageSettings()
            }
            return
        }

        // Migration from legacy "imageFiles" and on-disk files.
        let legacyFiles = (defaults.stringArray(forKey: "imageFiles") ?? []).filter(isValidImageFileName)
        let existingSet = Set(existingImageFileNames())

        var displayNames: [String] = []
        var storageNames: [String] = []
        var seenStorageNames = Set<String>()
        for fileName in legacyFiles where existingSet.contains(fileName) {
            guard seenStorageNames.contains(fileName) == false else { continue }
            displayNames.append(fileName)
            storageNames.append(fileName)
            seenStorageNames.insert(fileName)
        }
        for fileName in existingImageFileNames() where storageNames.contains(fileName) == false {
            displayNames.append(fileName)
            storageNames.append(fileName)
        }

        imageFiles = displayNames
        imageStorageFiles = storageNames
        if displayNames.isEmpty == false {
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

    func loadAISettings() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "aiFeedbackEnabled") != nil {
            aiFeedbackEnabled = defaults.bool(forKey: "aiFeedbackEnabled")
        } else {
            aiFeedbackEnabled = false
        }

        if let savedBaseURL = defaults.string(forKey: "aiAPIBaseURLString"),
           savedBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            aiAPIBaseURLString = savedBaseURL
        }

        if let savedToken = defaults.string(forKey: "aiBearerToken"),
           savedToken.isEmpty == false {
            aiBearerToken = savedToken
        }

        if let savedModel = defaults.string(forKey: "aiModel"),
           savedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            aiModel = savedModel
        }

        if defaults.object(forKey: "aiUsePreviousResponseID") != nil {
            aiUsePreviousResponseID = defaults.bool(forKey: "aiUsePreviousResponseID")
        } else {
            aiUsePreviousResponseID = true
        }

        if defaults.object(forKey: "aiTimeoutSeconds") != nil {
            aiTimeoutSeconds = max(0.1, defaults.double(forKey: "aiTimeoutSeconds"))
        } else {
            aiTimeoutSeconds = 30
        }

        aiPreviousResponseID = defaults.string(forKey: "aiPreviousResponseID")
    }

    func saveImageSettings() {
        let defaults = UserDefaults.standard
        let pairCount = min(imageFiles.count, imageStorageFiles.count)
        if imageFiles.count != pairCount {
            imageFiles = Array(imageFiles.prefix(pairCount))
        }
        if imageStorageFiles.count != pairCount {
            imageStorageFiles = Array(imageStorageFiles.prefix(pairCount))
        }

        let entries = zip(imageFiles, imageStorageFiles).map { pair in
            PersistedImageEntry(displayName: sanitizeImageDisplayName(pair.0), storageName: pair.1)
        }
        let encoded = try? JSONEncoder().encode(entries)
        defaults.set(encoded, forKey: imageEntriesDefaultsKey())

        // Keep legacy key for easier rollback/debug visibility.
        defaults.set(imageStorageFiles, forKey: "imageFiles")
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

    func saveAISettings() {
        let defaults = UserDefaults.standard
        defaults.set(aiFeedbackEnabled, forKey: "aiFeedbackEnabled")
        defaults.set(aiAPIBaseURLString, forKey: "aiAPIBaseURLString")
        defaults.set(aiBearerToken, forKey: "aiBearerToken")
        defaults.set(aiModel, forKey: "aiModel")
        defaults.set(aiUsePreviousResponseID, forKey: "aiUsePreviousResponseID")
        defaults.set(max(0.1, aiTimeoutSeconds), forKey: "aiTimeoutSeconds")
        defaults.set(aiPreviousResponseID, forKey: "aiPreviousResponseID")
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
            let storageName = makeManagedImageFileName(originalURL: url)
            guard let target = safeImageFileURL(fileName: storageName) else {
                showAlert(title: "画像の追加に失敗", message: "画像保存先の作成に失敗しました。")
                return
            }
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: url, to: target)

            let displayName = sanitizeImageDisplayName(url.lastPathComponent)
            imageFiles.append(displayName)
            imageStorageFiles.append(storageName)
            saveImageSettings()
        } catch {
            showAlert(title: "画像の追加に失敗", message: "画像の追加に失敗しました。別の画像で試してください。")
        }
    }

    func removeImage(at index: Int) {
        guard index >= 0 && index < imageStorageFiles.count else { return }
        let storageName = imageStorageFiles[index]
        if let fileURL = safeImageFileURL(fileName: storageName) {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values?.isRegularFile == true {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        imageFiles.remove(at: index)
        imageStorageFiles.remove(at: index)
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
        let persisted = PersistedLogEntry(time: entry.time, response: entry.response, type: entry.type)
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
        return decoded.isEmpty ? nil : decoded
    }

    private func decodePersistedLogEntries(_ text: String) -> [PersistedLogEntry] {
        let decoder = JSONDecoder()
        let lines = text.split(whereSeparator: \.isNewline)
        var entries: [PersistedLogEntry] = []
        entries.reserveCapacity(lines.count)

        for line in lines {
            guard let data = line.data(using: .utf8),
                  let entry = try? decoder.decode(PersistedLogEntry.self, from: data) else {
                continue
            }
            entries.append(entry)
        }

        return entries
    }

    private func parseJSONLineEntries(_ text: String) -> [LogWindowController.LogItem] {
        var items: [LogWindowController.LogItem] = []
        let entries = decodePersistedLogEntries(text)
        items.reserveCapacity(entries.count)

        for entry in entries {
            let state = CheckinState.from(rawValue: entry.type)
            items.append(LogWindowController.LogItem(time: entry.time, response: entry.response, state: state))
        }

        return items
    }

    func recentDailyLogCounts(days: Int) -> [(date: Date, count: Int)] {
        guard days > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [(date: Date, count: Int)] = []
        results.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let url = logFileURL(for: date)
            let count: Int
            if let text = readLogText(from: url), text.isEmpty == false {
                count = text.split(whereSeparator: \.isNewline).count
            } else {
                count = 0
            }
            results.append((date: date, count: count))
        }

        return results
    }

    func recentDailyLogBreakdowns(days: Int) -> [(date: Date, focused: Int, wandering: Int, resting: Int)] {
        guard days > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var results: [(date: Date, focused: Int, wandering: Int, resting: Int)] = []
        results.reserveCapacity(days)

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let url = logFileURL(for: date)
            guard let text = readLogText(from: url), text.isEmpty == false else {
                results.append((date: date, focused: 0, wandering: 0, resting: 0))
                continue
            }

            var focused = 0
            var wandering = 0
            var resting = 0

            for entry in decodePersistedLogEntries(text) {
                switch CheckinState.from(rawValue: entry.type) {
                case .focused:
                    focused += 1
                case .wandering:
                    wandering += 1
                case .resting:
                    resting += 1
                }
            }

            results.append((date: date, focused: focused, wandering: wandering, resting: resting))
        }

        return results
    }

}
