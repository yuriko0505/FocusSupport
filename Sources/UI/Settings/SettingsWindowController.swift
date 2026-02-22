import AppKit

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    struct AISettings {
        let isEnabled: Bool
        let baseURL: String
        let token: String
        let model: String
    }

    struct DailyLogCount {
        let date: Date
        let count: Int
    }
    struct DailyLogBreakdown {
        let date: Date
        let focused: Int
        let wandering: Int
        let resting: Int

        var total: Int {
            focused + wandering + resting
        }
    }

    let getStats: () -> (String, String, String, String)
    let getRecentDailyLogBreakdowns: (Int) -> [DailyLogBreakdown]
    let getQuestions: () -> [String]
    let setQuestions: ([String]) -> Void
    let getImages: () -> [String]
    let addImage: (URL) -> Void
    let removeImageAt: (Int) -> Void
    let getAppIconFileName: () -> String?
    let setAppIcon: (URL) -> Void
    let resetAppIcon: () -> Void
    let getNotificationHours: () -> (Int, Int)
    let setNotificationHours: (Int, Int) -> Void
    let getAISettings: () -> AISettings
    let setAISettings: (AISettings) -> Void

    var questions: [String] = []
    var images: [String] = []
    var appIconFileName: String?
    let questionsTableView = NSTableView()
    let imagesTableView = NSTableView()
    let inputField = NSTextField(string: "")
    let appIconNameLabel = NSTextField(labelWithString: "未設定")
    let cellVerticalPadding: CGFloat = 4
    let rowHeight: CGFloat = 26
    let startHourPopup = NSPopUpButton()
    let endHourPopup = NSPopUpButton()
    let aiEnabledCheckbox = NSButton(checkboxWithTitle: "フィードバックにAIを使う", target: nil, action: nil)
    let aiBaseURLField = ShortcutTextField(string: "")
    let aiTokenField = ShortcutSecureTextField(string: "")
    let aiTokenRevealField = ShortcutTextField(string: "")
    let aiTokenRevealButton = NSButton()
    let aiModelField = ShortcutTextField(string: "")
    var isRefreshingAISettings = false
    var aiSettings = AISettings(isEnabled: false, baseURL: "", token: "", model: "")
    let statsSummaryLabel = NSTextField(labelWithString: "")
    let weeklyOverviewLabel = NSTextField(labelWithString: "")
    let weeklyLineChartView = WeeklyLineChartView()
    var clickMonitor: Any?

    init(getStats: @escaping () -> (String, String, String, String),
         getRecentDailyLogBreakdowns: @escaping (Int) -> [DailyLogBreakdown],
         getQuestions: @escaping () -> [String],
         setQuestions: @escaping ([String]) -> Void,
         getImages: @escaping () -> [String],
         addImage: @escaping (URL) -> Void,
         removeImageAt: @escaping (Int) -> Void,
         getAppIconFileName: @escaping () -> String?,
         setAppIcon: @escaping (URL) -> Void,
         resetAppIcon: @escaping () -> Void,
         getNotificationHours: @escaping () -> (Int, Int),
         setNotificationHours: @escaping (Int, Int) -> Void,
         getAISettings: @escaping () -> AISettings,
         setAISettings: @escaping (AISettings) -> Void) {
        self.getStats = getStats
        self.getRecentDailyLogBreakdowns = getRecentDailyLogBreakdowns
        self.getQuestions = getQuestions
        self.setQuestions = setQuestions
        self.getImages = getImages
        self.addImage = addImage
        self.removeImageAt = removeImageAt
        self.getAppIconFileName = getAppIconFileName
        self.setAppIcon = setAppIcon
        self.resetAppIcon = resetAppIcon
        self.getNotificationHours = getNotificationHours
        self.setNotificationHours = setNotificationHours
        self.getAISettings = getAISettings
        self.setAISettings = setAISettings

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
        self.appIconFileName = getAppIconFileName()
        self.aiSettings = getAISettings()
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
    }

    func buildUI() {
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

        installClickToUnfocusIfNeeded()
    }

    func refreshData() {
        questions = getQuestions()
        images = getImages()
        appIconFileName = getAppIconFileName()
        refreshStatsView()
        questionsTableView.reloadData()
        imagesTableView.reloadData()
        refreshAppIconName()
        refreshNotificationHours()
        refreshAISettings()
    }

    func installClickToUnfocusIfNeeded() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window === window,
                  self.shouldUnfocusTextInput(window: window, event: event) else {
                return event
            }
            window.makeFirstResponder(nil)
            return event
        }
    }

    func shouldUnfocusTextInput(window: NSWindow, event: NSEvent) -> Bool {
        guard let contentView = window.contentView else { return false }
        let pointInContent = contentView.convert(event.locationInWindow, from: nil)
        guard let hitView = contentView.hitTest(pointInContent) else { return false }
        if hitView is NSTextField || hitView is NSTextView {
            return false
        }
        return true
    }
}
