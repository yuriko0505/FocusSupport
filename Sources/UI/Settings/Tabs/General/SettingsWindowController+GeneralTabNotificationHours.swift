import AppKit

extension SettingsWindowController {
    func configureHourPopup(_ popup: NSPopUpButton) {
        popup.removeAllItems()
        for hour in 0...23 {
            popup.addItem(withTitle: String(format: "%02d:00", hour))
            popup.item(at: hour)?.tag = hour
        }
    }

    func refreshNotificationHours() {
        let (start, end) = getNotificationHours()
        selectHour(start, in: startHourPopup)
        selectHour(end, in: endHourPopup)
    }

    func selectHour(_ hour: Int, in popup: NSPopUpButton) {
        if let item = popup.item(at: hour) {
            popup.select(item)
        } else {
            popup.selectItem(at: 0)
        }
    }

    @objc func updateNotificationHours() {
        let start = max(0, startHourPopup.selectedTag())
        let end = max(0, endHourPopup.selectedTag())
        setNotificationHours(start, end)
    }
}
