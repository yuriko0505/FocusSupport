import AppKit

final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    struct DailyLogCount {
        let date: Date
        let count: Int
    }

    let getStats: () -> (String, String, String)
    let getRecentDailyLogCounts: (Int) -> [DailyLogCount]
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
    let statsSummaryLabel = NSTextField(labelWithString: "")
    let weeklyOverviewLabel = NSTextField(labelWithString: "")
    let weeklyLineChartView = WeeklyLineChartView()

    init(getStats: @escaping () -> (String, String, String),
         getRecentDailyLogCounts: @escaping (Int) -> [DailyLogCount],
         getQuestions: @escaping () -> [String],
         setQuestions: @escaping ([String]) -> Void,
         getImages: @escaping () -> [String],
         addImage: @escaping (URL) -> Void,
         removeImageAt: @escaping (Int) -> Void,
         getAppIconFileName: @escaping () -> String?,
         setAppIcon: @escaping (URL) -> Void,
         resetAppIcon: @escaping () -> Void,
         getNotificationHours: @escaping () -> (Int, Int),
         setNotificationHours: @escaping (Int, Int) -> Void) {
        self.getStats = getStats
        self.getRecentDailyLogCounts = getRecentDailyLogCounts
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
        buildUI()
    }

    required init?(coder: NSCoder) {
        return nil
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
    }
}
