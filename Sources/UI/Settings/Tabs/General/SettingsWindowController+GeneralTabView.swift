import AppKit

extension SettingsWindowController {
    func buildSettingsView() -> NSView {
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

        let appIconDescription = NSTextField(labelWithString: "アプリアイコン")
        appIconDescription.translatesAutoresizingMaskIntoConstraints = false

        appIconNameLabel.translatesAutoresizingMaskIntoConstraints = false
        appIconNameLabel.lineBreakMode = .byTruncatingMiddle
        refreshAppIconName()

        let addAppIconButton = NSButton(title: "画像を選択", target: self, action: #selector(addAppIconFromPicker))
        addAppIconButton.setButtonType(.momentaryPushIn)
        addAppIconButton.translatesAutoresizingMaskIntoConstraints = false

        let resetAppIconButton = NSButton(title: "デフォルトに戻す", target: self, action: #selector(resetAppIconToDefault))
        resetAppIconButton.setButtonType(.momentaryPushIn)
        resetAppIconButton.translatesAutoresizingMaskIntoConstraints = false

        let appIconSpacer = NSView()
        appIconSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let appIconRow = NSStackView(views: [appIconDescription, appIconNameLabel, appIconSpacer, addAppIconButton, resetAppIconButton])
        appIconRow.orientation = .horizontal
        appIconRow.alignment = .centerY
        appIconRow.distribution = .fill
        appIconRow.spacing = 8
        appIconRow.translatesAutoresizingMaskIntoConstraints = false

        let imageDescriptionSpacer = NSView()
        imageDescriptionSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let imageDescriptionRow = NSStackView(views: [imageDescription, imageDescriptionSpacer])
        imageDescriptionRow.orientation = .horizontal
        imageDescriptionRow.alignment = .centerY
        imageDescriptionRow.distribution = .fill
        imageDescriptionRow.translatesAutoresizingMaskIntoConstraints = false

        let notificationRow = buildNotificationTimeRow()
        let aiSettingsView = buildAISettingsView()

        let contentStack = NSStackView(views: [
            notificationRow,
            aiSettingsView,
            descriptionRow,
            questionsScroll,
            inputRow,
            imageDescriptionRow,
            imagesScroll,
            imageButtons,
            appIconRow
        ])
        contentStack.orientation = .vertical
        contentStack.spacing = 10
        contentStack.alignment = .leading
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
            addAppIconButton.widthAnchor.constraint(equalToConstant: 100),
            resetAppIconButton.widthAnchor.constraint(equalToConstant: 130),
            appIconNameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),

            questionsScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            imagesScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),
            questionsScroll.heightAnchor.constraint(equalTo: imagesScroll.heightAnchor)
        ])

        return view
    }

    func buildAISettingsView() -> NSView {
        let container = NSStackView()
        container.orientation = .vertical
        container.spacing = 8
        container.alignment = .leading
        container.translatesAutoresizingMaskIntoConstraints = false

        aiEnabledCheckbox.target = self
        aiEnabledCheckbox.action = #selector(toggleAISettingsEnabled)
        aiEnabledCheckbox.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(aiEnabledCheckbox)

        let baseURLLabel = NSTextField(labelWithString: "Base URL")
        baseURLLabel.alignment = .right
        baseURLLabel.translatesAutoresizingMaskIntoConstraints = false
        aiBaseURLField.placeholderString = "http://localhost:11434"
        aiBaseURLField.delegate = self
        aiBaseURLField.translatesAutoresizingMaskIntoConstraints = false

        let tokenLabel = NSTextField(labelWithString: "Token")
        tokenLabel.alignment = .right
        tokenLabel.translatesAutoresizingMaskIntoConstraints = false
        aiTokenField.placeholderString = "Bearer token"
        aiTokenField.delegate = self
        aiTokenField.translatesAutoresizingMaskIntoConstraints = false

        let modelLabel = NSTextField(labelWithString: "Model")
        modelLabel.alignment = .right
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        aiModelField.placeholderString = "nvidia-nemotron-nano-9b-v2-japanese"
        aiModelField.delegate = self
        aiModelField.translatesAutoresizingMaskIntoConstraints = false

        let form = NSGridView(views: [
            [baseURLLabel, aiBaseURLField],
            [tokenLabel, aiTokenField],
            [modelLabel, aiModelField]
        ])
        form.translatesAutoresizingMaskIntoConstraints = false
        form.xPlacement = .fill
        form.yPlacement = .center
        form.rowSpacing = 6
        form.columnSpacing = 8
        form.column(at: 0).width = 80
        form.column(at: 1).xPlacement = .fill

        container.addArrangedSubview(form)

        NSLayoutConstraint.activate([
            form.widthAnchor.constraint(equalToConstant: 420)
        ])

        refreshAISettings()
        return container
    }

    func buildNotificationTimeRow() -> NSView {
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
}
