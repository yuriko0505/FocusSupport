import AppKit

extension SettingsWindowController {
    func buildStatsView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 520))
        view.autoresizingMask = [.width, .height]

        let (checkins, focused, wandering) = getStats()
        let label = NSTextField(labelWithString:
            "総チェックイン: \(checkins)\n集中: \(focused)\nぼんやり: \(wandering)"
        )
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false

        let versionLabel = NSTextField(labelWithString: "バージョン: \(appVersionDisplayText())")
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .right
        versionLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        view.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            versionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])

        return view
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
