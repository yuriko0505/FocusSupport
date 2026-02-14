import AppKit

final class LogWindowController: NSWindowController {
    struct LogItem {
        let time: String
        let response: String
    }

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let backgroundColor = NSColor(calibratedRed: 0.09, green: 0.1, blue: 0.12, alpha: 1.0)
    private let panelColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)
    private let cardColor = NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.21, alpha: 1.0)
    private let cardBorderColor = NSColor(calibratedRed: 0.23, green: 0.27, blue: 0.33, alpha: 1.0)
    private let timelineColor = NSColor(calibratedRed: 0.38, green: 0.74, blue: 0.98, alpha: 1.0)
    private let connectorColor = NSColor(calibratedRed: 0.24, green: 0.35, blue: 0.46, alpha: 1.0)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "今日のログ"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = panelColor.cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = panelColor
        scrollView.scrollerStyle = .overlay
        contentView.addSubview(scrollView)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = documentView

        stackView.orientation = .vertical
        stackView.spacing = 10
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            stackView.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -30),
            stackView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -20)
        ])
    }

    func setLogEntries(_ entries: [LogItem]) {
        stackView.arrangedSubviews.forEach { view in
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if entries.isEmpty {
            stackView.addArrangedSubview(emptyStateLabel())
            return
        }

        for (index, entry) in entries.enumerated() {
            let row = timelineRow(for: entry, showsConnector: index < entries.count - 1)
            stackView.addArrangedSubview(row)
        }
    }

    private func emptyStateLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "まだログがありません")
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = NSColor(calibratedWhite: 0.78, alpha: 1.0)
        return label
    }

    private func timelineRow(for entry: LogItem, showsConnector: Bool) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .top
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false
        row.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        let timeColumn = NSView()
        timeColumn.translatesAutoresizingMaskIntoConstraints = false
        timeColumn.widthAnchor.constraint(equalToConstant: 54).isActive = true
        timeColumn.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true

        let timeLabel = NSTextField(labelWithString: entry.time)
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        timeLabel.textColor = timelineColor
        timeLabel.alignment = .right
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeColumn.addSubview(timeLabel)
        NSLayoutConstraint.activate([
            timeLabel.trailingAnchor.constraint(equalTo: timeColumn.trailingAnchor),
            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: timeColumn.leadingAnchor),
            // dotの中心Y(= top 8 + radius 7) に合わせる
            timeLabel.centerYAnchor.constraint(equalTo: timeColumn.topAnchor, constant: 15)
        ])

        let markerColumn = NSView()
        markerColumn.translatesAutoresizingMaskIntoConstraints = false
        markerColumn.wantsLayer = true
        markerColumn.layer?.backgroundColor = NSColor.clear.cgColor
        markerColumn.widthAnchor.constraint(equalToConstant: 28).isActive = true
        markerColumn.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true

        let dot = NSView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.wantsLayer = true
        dot.layer?.backgroundColor = timelineColor.cgColor
        dot.layer?.cornerRadius = 7
        dot.layer?.borderWidth = 2
        dot.layer?.borderColor = NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.26, alpha: 1.0).cgColor
        dot.layer?.shadowColor = timelineColor.withAlphaComponent(0.4).cgColor
        dot.layer?.shadowRadius = 3
        dot.layer?.shadowOpacity = 1
        dot.layer?.shadowOffset = NSSize(width: 0, height: 1)
        markerColumn.addSubview(dot)

        NSLayoutConstraint.activate([
            dot.topAnchor.constraint(equalTo: markerColumn.topAnchor, constant: 8),
            dot.centerXAnchor.constraint(equalTo: markerColumn.centerXAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14)
        ])

        if showsConnector {
            let line = NSView()
            line.translatesAutoresizingMaskIntoConstraints = false
            line.wantsLayer = true
            line.layer?.backgroundColor = connectorColor.cgColor
            markerColumn.addSubview(line)
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: dot.bottomAnchor, constant: 4),
                line.bottomAnchor.constraint(equalTo: markerColumn.bottomAnchor, constant: -4),
                line.centerXAnchor.constraint(equalTo: markerColumn.centerXAnchor),
                line.widthAnchor.constraint(equalToConstant: 2)
            ])
        }

        let cardContainer = NSView()
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true

        let card = NSView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.backgroundColor = cardColor.cgColor
        card.layer?.cornerRadius = 14
        card.layer?.borderColor = cardBorderColor.cgColor
        card.layer?.borderWidth = 1
        card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        card.layer?.shadowRadius = 8
        card.layer?.shadowOpacity = 1
        card.layer?.shadowOffset = NSSize(width: 0, height: -2)
        cardContainer.addSubview(card)

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let responseLabel = NSTextField(wrappingLabelWithString: entry.response)
        responseLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        responseLabel.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        responseLabel.lineBreakMode = .byWordWrapping
        responseLabel.maximumNumberOfLines = 0
        responseLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        cardStack.addArrangedSubview(responseLabel)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 7),
            card.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        row.addArrangedSubview(timeColumn)
        row.addArrangedSubview(markerColumn)
        row.addArrangedSubview(cardContainer)

        timeColumn.setContentHuggingPriority(.required, for: .horizontal)
        timeColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        markerColumn.setContentHuggingPriority(.required, for: .horizontal)
        markerColumn.setContentCompressionResistancePriority(.required, for: .horizontal)
        cardContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cardContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        cardContainer.widthAnchor.constraint(equalTo: row.widthAnchor, constant: -104).isActive = true

        return row
    }
}
