import AppKit
import UniformTypeIdentifiers

extension SettingsWindowController {
    @objc func addQuestion() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        questions.append(text)
        setQuestions(questions)
        inputField.stringValue = ""
        questionsTableView.reloadData()
    }

    @objc func removeQuestion() {
        let row = questionsTableView.selectedRow
        guard row >= 0 && row < questions.count else { return }
        questions.remove(at: row)
        setQuestions(questions)
        questionsTableView.reloadData()
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

    @objc func addImageFromPicker() {
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

    @objc func removeImage() {
        let row = imagesTableView.selectedRow
        guard row >= 0 && row < images.count else { return }
        removeImageAt(row)
        images = getImages()
        imagesTableView.reloadData()
    }

    func refreshAppIconName() {
        appIconNameLabel.stringValue = appIconFileName ?? "未設定"
    }

    @objc func addAppIconFromPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.setAppIcon(url)
            self?.appIconFileName = self?.getAppIconFileName()
            self?.refreshAppIconName()
        }
    }

    @objc func resetAppIconToDefault() {
        resetAppIcon()
        appIconFileName = getAppIconFileName()
        refreshAppIconName()
    }
}
