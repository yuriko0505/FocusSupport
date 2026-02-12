import AppKit

extension FocusSupportApp {
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
        imageFiles = defaults.stringArray(forKey: "imageFiles") ?? []
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
