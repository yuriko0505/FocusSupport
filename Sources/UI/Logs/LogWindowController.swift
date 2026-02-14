import AppKit

final class LogWindowController: NSWindowController {
    private struct TimelineStyle {
        let accentColor: NSColor
        let connectorColor: NSColor
        let cardColor: NSColor
        let cardBorderColor: NSColor
    }

    struct LogItem {
        let time: String
        let response: String
        let state: CheckinState
    }

    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let backgroundColor = NSColor(calibratedRed: 0.09, green: 0.1, blue: 0.12, alpha: 1.0)
    private let panelColor = NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)

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
        let style = style(for: entry.state)

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
        timeLabel.textColor = style.accentColor
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
        dot.layer?.backgroundColor = style.accentColor.cgColor
        dot.layer?.cornerRadius = 7
        dot.layer?.borderWidth = 2
        dot.layer?.borderColor = NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.26, alpha: 1.0).cgColor
        dot.layer?.shadowColor = style.accentColor.withAlphaComponent(0.45).cgColor
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
            line.layer?.backgroundColor = style.connectorColor.cgColor
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
        card.layer?.backgroundColor = style.cardColor.cgColor
        card.layer?.cornerRadius = 14
        card.layer?.borderColor = style.cardBorderColor.cgColor
        card.layer?.borderWidth = 1
        card.layer?.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
        card.layer?.shadowRadius = 8
        card.layer?.shadowOpacity = 1
        card.layer?.shadowOffset = NSSize(width: 0, height: -2)
        cardContainer.addSubview(card)

        let cardStack = NSStackView()
        cardStack.orientation = .vertical
        cardStack.spacing = 6
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)

        let stateLabel = NSTextField(labelWithString: entry.state.label)
        stateLabel.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        stateLabel.textColor = style.accentColor
        let stateSpacer = NSView()
        stateSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stateSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stateRow = NSStackView(views: [stateLabel, stateSpacer])
        stateRow.orientation = .horizontal
        stateRow.alignment = .firstBaseline
        stateRow.spacing = 0

        let responseLabel = NSTextField(wrappingLabelWithString: entry.response)
        responseLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        responseLabel.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        responseLabel.lineBreakMode = .byWordWrapping
        responseLabel.maximumNumberOfLines = 0
        responseLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        cardStack.addArrangedSubview(stateRow)
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

    private func style(for state: CheckinState) -> TimelineStyle {
        switch state {
        case .focused:
            return TimelineStyle(
                accentColor: NSColor(calibratedRed: 0.28, green: 0.81, blue: 0.95, alpha: 1.0),
                connectorColor: NSColor(calibratedRed: 0.23, green: 0.47, blue: 0.58, alpha: 1.0),
                cardColor: NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.27, alpha: 1.0),
                cardBorderColor: NSColor(calibratedRed: 0.25, green: 0.50, blue: 0.62, alpha: 1.0)
            )
        case .wandering:
            return TimelineStyle(
                accentColor: NSColor(calibratedRed: 0.97, green: 0.73, blue: 0.36, alpha: 1.0),
                connectorColor: NSColor(calibratedRed: 0.57, green: 0.43, blue: 0.20, alpha: 1.0),
                cardColor: NSColor(calibratedRed: 0.27, green: 0.21, blue: 0.13, alpha: 1.0),
                cardBorderColor: NSColor(calibratedRed: 0.58, green: 0.43, blue: 0.24, alpha: 1.0)
            )
        case .resting:
            return TimelineStyle(
                accentColor: NSColor(calibratedRed: 0.49, green: 0.84, blue: 0.62, alpha: 1.0),
                connectorColor: NSColor(calibratedRed: 0.27, green: 0.53, blue: 0.38, alpha: 1.0),
                cardColor: NSColor(calibratedRed: 0.13, green: 0.24, blue: 0.19, alpha: 1.0),
                cardBorderColor: NSColor(calibratedRed: 0.29, green: 0.57, blue: 0.42, alpha: 1.0)
            )
        }
    }
}
