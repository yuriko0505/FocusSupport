import AppKit

extension FocusSupportApp {
    func existingImageFileNames() -> [String] {
        let dir = imagesDirectory()
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return []
        }
        return items
            .filter { $0.hasDirectoryPath == false }
            .map(\.lastPathComponent)
            .sorted()
    }

    func loadImage(named fileName: String) -> NSImage? {
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

    func loadImageSettings() {
        let defaults = UserDefaults.standard
        let configuredFiles = defaults.stringArray(forKey: "imageFiles") ?? []
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
        let url = imagesDirectory().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
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

    func readLogText(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
