import AppKit
import UniformTypeIdentifiers

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let getStats: () -> (String, String, String)
    private let getQuestions: () -> [String]
    private let setQuestions: ([String]) -> Void
    private let getImages: () -> [String]
    private let addImage: (URL) -> Void
    private let removeImageAt: (Int) -> Void
    private let getNotificationHours: () -> (Int, Int)
    private let setNotificationHours: (Int, Int) -> Void

    private var questions: [String] = []
    private var images: [String] = []
    private let questionsTableView = NSTableView()
    private let imagesTableView = NSTableView()
    private let inputField = NSTextField(string: "")
    private let cellVerticalPadding: CGFloat = 4
    private let rowHeight: CGFloat = 26
    private let startHourPopup = NSPopUpButton()
    private let endHourPopup = NSPopUpButton()

    init(getStats: @escaping () -> (String, String, String),
         getQuestions: @escaping () -> [String],
         setQuestions: @escaping ([String]) -> Void,
         getImages: @escaping () -> [String],
         addImage: @escaping (URL) -> Void,
         removeImageAt: @escaping (Int) -> Void,
         getNotificationHours: @escaping () -> (Int, Int),
         setNotificationHours: @escaping (Int, Int) -> Void) {
        self.getStats = getStats
        self.getQuestions = getQuestions
        self.setQuestions = setQuestions
        self.getImages = getImages
        self.addImage = addImage
        self.removeImageAt = removeImageAt
        self.getNotificationHours = getNotificationHours
        self.setNotificationHours = setNotificationHours

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
        refreshNotificationHours()
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

        let notificationRow = buildNotificationTimeRow()

        let contentStack = NSStackView(views: [
            notificationRow,
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

    private func buildNotificationTimeRow() -> NSView {
        let title = NSTextField(labelWithString: "通知時間帯")
        title.translatesAutoresizingMaskIntoConstraints = false

        let startLabel = NSTextField(labelWithString: "開始")
        startLabel.translatesAutoresizingMaskIntoConstraints = false
        let endLabel = NSTextField(labelWithString: "終了")
        endLabel.translatesAutoresizingMaskIntoConstraints = false

        configureHourPopup(startHourPopup)
        configureHourPopup(endHourPopup)

        startHourPopup.target = self
        startHourPopup.action = #selector(updateNotificationHours)
        endHourPopup.target = self
        endHourPopup.action = #selector(updateNotificationHours)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [title, spacer, startLabel, startHourPopup, endLabel, endHourPopup])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            startHourPopup.widthAnchor.constraint(equalToConstant: 70),
            endHourPopup.widthAnchor.constraint(equalToConstant: 70)
        ])

        refreshNotificationHours()
        return row
    }

    private func configureHourPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for hour in 0...23 {
            popup.addItem(withTitle: String(format: "%02d:00", hour))
            popup.item(at: hour)?.tag = hour
        }
    }

    private func refreshNotificationHours() {
        let (start, end) = getNotificationHours()
        selectHour(start, in: startHourPopup)
        selectHour(end, in: endHourPopup)
    }

    private func selectHour(_ hour: Int, in popup: NSPopUpButton) {
        if let item = popup.item(at: hour) {
            popup.select(item)
        } else {
            popup.selectItem(at: 0)
        }
    }

    @objc private func updateNotificationHours() {
        let start = max(0, startHourPopup.selectedTag())
        let end = max(0, endHourPopup.selectedTag())
        setNotificationHours(start, end)
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
