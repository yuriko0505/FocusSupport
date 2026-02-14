import AppKit

extension SettingsWindowController {
    func buildStatsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 520))
        view.autoresizingMask = [.width, .height]

        statsSummaryLabel.lineBreakMode = .byWordWrapping
        statsSummaryLabel.translatesAutoresizingMaskIntoConstraints = false

        let weeklyTitleLabel = NSTextField(labelWithString: "直近7日間のログ件数")
        weeklyTitleLabel.font = .boldSystemFont(ofSize: 13)
        weeklyTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        weeklyOverviewLabel.textColor = .secondaryLabelColor
        weeklyOverviewLabel.translatesAutoresizingMaskIntoConstraints = false

        weeklyLineChartView.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "バージョン: \(appVersionDisplayText())")
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .right
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(statsSummaryLabel)
        view.addSubview(weeklyTitleLabel)
        view.addSubview(weeklyOverviewLabel)
        view.addSubview(weeklyLineChartView)
        view.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            statsSummaryLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            statsSummaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statsSummaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            weeklyTitleLabel.topAnchor.constraint(equalTo: statsSummaryLabel.bottomAnchor, constant: 24),
            weeklyTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weeklyTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            weeklyOverviewLabel.topAnchor.constraint(equalTo: weeklyTitleLabel.bottomAnchor, constant: 6),
            weeklyOverviewLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weeklyOverviewLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            weeklyLineChartView.topAnchor.constraint(equalTo: weeklyOverviewLabel.bottomAnchor, constant: 12),
            weeklyLineChartView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            weeklyLineChartView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            weeklyLineChartView.heightAnchor.constraint(equalToConstant: 220),

            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            versionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        refreshStatsView()

        return view
    }

    func refreshStatsView() {
        let (checkins, focused, wandering, resting) = getStats()
        statsSummaryLabel.stringValue = "今日のチェックイン: \(checkins)\n集中: \(focused)\nぼんやり: \(wandering)\n休憩中: \(resting)"

        let weeklyBreakdowns = getRecentDailyLogBreakdowns(7)
        let weeklyTotal = weeklyBreakdowns.reduce(0) { $0 + $1.total }
        weeklyOverviewLabel.stringValue = "合計 \(weeklyTotal) 件 (集中/ぼんやり/休憩中)"
        weeklyLineChartView.items = weeklyBreakdowns
    }

    func appVersionDisplayText() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (shortVersion, buildVersion) {
        case let (short?, build?) where short != build:
            return "\(short) (\(build))"
        case let (short?, _):
            return short
        case let (_, build?):
            return build
        default:
            return "開発版"
        }
    }
}

final class WeeklyLineChartView: NSView {
    var items: [SettingsWindowController.DailyLogBreakdown] = [] {
        didSet { needsDisplay = true }
    }

    // Keep the original blue-themed design while visualizing 3 layers.
    private let restingColor = NSColor(calibratedRed: 0.61, green: 1.0, blue: 0.0, alpha: 0.34)
    private let wanderingColor = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.18, alpha: 0.34)
    private let focusedColor = NSColor(calibratedRed: 0.29, green: 0.76, blue: 1.0, alpha: 0.34)
    private let totalLineColor = NSColor(calibratedRed: 0.32, green: 0.82, blue: 1.0, alpha: 1.0)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return formatter
    }()

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        let topColor = NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.24, alpha: 0.95)
        let bottomColor = NSColor(calibratedRed: 0.03, green: 0.07, blue: 0.16, alpha: 0.95)
        NSGradient(starting: topColor, ending: bottomColor)?.draw(in: backgroundPath, angle: -90)

        let plotRect = bounds.insetBy(dx: 18, dy: 18).insetBy(dx: 24, dy: 14)
        guard plotRect.width > 0, plotRect.height > 0 else { return }

        if items.isEmpty {
            drawEmptyMessage(in: plotRect)
            return
        }

        drawGrid(in: plotRect)

        let maxCount = max(items.map(\.total).max() ?? 0, 1)
        let xPositions = makeXPositions(in: plotRect)
        guard xPositions.isEmpty == false else { return }

        let restingTop = makeStackPoints(in: plotRect, xPositions: xPositions, maxCount: maxCount) { $0.resting }
        let wanderingTop = makeStackPoints(in: plotRect, xPositions: xPositions, maxCount: maxCount) { $0.resting + $0.wandering }
        let focusedTop = makeStackPoints(in: plotRect, xPositions: xPositions, maxCount: maxCount) { $0.total }
        let baseline = xPositions.map { CGPoint(x: $0, y: plotRect.minY) }

        // Requested order: lower resting, middle wandering, upper focused.
        drawStackLayer(lower: baseline, upper: restingTop, color: restingColor)
        drawStackLayer(lower: restingTop, upper: wanderingTop, color: wanderingColor)
        drawStackLayer(lower: wanderingTop, upper: focusedTop, color: focusedColor)
        drawLine(points: focusedTop)
        drawPoints(points: focusedTop)
        drawLabels(in: plotRect, maxCount: maxCount)
    }

    private func drawEmptyMessage(in rect: CGRect) {
        let message = "ログがまだありません"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let size = message.size(withAttributes: attributes)
        let point = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        message.draw(at: point, withAttributes: attributes)
    }

    private func drawGrid(in rect: CGRect) {
        let gridPath = NSBezierPath()
        gridPath.lineWidth = 1
        let divisions = 4
        for index in 0...divisions {
            let y = rect.minY + (rect.height * CGFloat(index) / CGFloat(divisions))
            gridPath.move(to: CGPoint(x: rect.minX, y: y))
            gridPath.line(to: CGPoint(x: rect.maxX, y: y))
        }
        NSColor.white.withAlphaComponent(0.15).setStroke()
        gridPath.stroke()
    }

    private func makeXPositions(in rect: CGRect) -> [CGFloat] {
        guard items.isEmpty == false else { return [] }

        return items.enumerated().map { index, _ in
            if items.count == 1 {
                return rect.midX
            }
            return rect.minX + rect.width * CGFloat(index) / CGFloat(items.count - 1)
        }
    }

    private func makeStackPoints(in rect: CGRect,
                                 xPositions: [CGFloat],
                                 maxCount: Int,
                                 value: (SettingsWindowController.DailyLogBreakdown) -> Int) -> [CGPoint] {
        zip(xPositions, items).map { x, item in
            let yRatio = CGFloat(value(item)) / CGFloat(maxCount)
            return CGPoint(x: x, y: rect.minY + rect.height * yRatio)
        }
    }

    private func drawStackLayer(lower: [CGPoint], upper: [CGPoint], color: NSColor) {
        guard lower.count == upper.count, lower.isEmpty == false else { return }
        let path = NSBezierPath()
        path.move(to: lower[0])
        for point in upper {
            path.line(to: point)
        }
        for point in lower.reversed() {
            path.line(to: point)
        }
        path.close()
        color.setFill()
        path.fill()
    }

    private func drawLine(points: [CGPoint]) {
        let linePath = NSBezierPath()
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round
        linePath.lineWidth = 1.8
        if let first = points.first {
            linePath.move(to: first)
            points.dropFirst().forEach { linePath.line(to: $0) }
        }
        totalLineColor.setStroke()
        linePath.stroke()
    }

    private func drawPoints(points: [CGPoint]) {
        for point in points {
            let outerRect = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
            let innerRect = CGRect(x: point.x - 2.2, y: point.y - 2.2, width: 4.4, height: 4.4)

            totalLineColor.setFill()
            NSBezierPath(ovalIn: outerRect).fill()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: innerRect).fill()
        }
    }

    private func drawLabels(in rect: CGRect, maxCount: Int) {
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.75)
        ]
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]

        let maxLabel = "\(maxCount)"
        maxLabel.draw(at: CGPoint(x: rect.minX - 18, y: rect.maxY - 6), withAttributes: numberAttributes)
        "0".draw(at: CGPoint(x: rect.minX - 12, y: rect.minY - 6), withAttributes: numberAttributes)

        for (index, item) in items.enumerated() {
            let x: CGFloat
            if items.count == 1 {
                x = rect.midX
            } else {
                x = rect.minX + rect.width * CGFloat(index) / CGFloat(items.count - 1)
            }
            let text = dateFormatter.string(from: item.date)
            let size = text.size(withAttributes: dateAttributes)
            let point = CGPoint(x: x - size.width / 2, y: rect.minY - 18)
            text.draw(at: point, withAttributes: dateAttributes)
        }
    }

}
