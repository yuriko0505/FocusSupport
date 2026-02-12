import AppKit

extension FocusSupportApp {
    func scheduleNextCheckin() {
        let now = Date()
        let target = nextAllowedCheckinTime(from: now)

        let waitSeconds = max(1, target.timeIntervalSince(now))
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: waitSeconds, repeats: false) { [weak self] _ in
            self?.triggerCheckin()
        }
    }

    func registerSchedulingObserversIfNeeded() {
        guard schedulingObserversRegistered == false else { return }
        schedulingObserversRegistered = true

        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSCalendarDayChanged,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSSystemClockDidChange,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(handleSchedulingContextChanged(_:)),
                           name: .NSSystemTimeZoneDidChange,
                           object: nil)

        NSWorkspace.shared.notificationCenter.addObserver(self,
                                                          selector: #selector(handleSchedulingContextChanged(_:)),
                                                          name: NSWorkspace.didWakeNotification,
                                                          object: nil)
    }

    func unregisterSchedulingObservers() {
        guard schedulingObserversRegistered else { return }
        schedulingObserversRegistered = false
        NotificationCenter.default.removeObserver(self, name: .NSCalendarDayChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSSystemClockDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .NSSystemTimeZoneDidChange, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didWakeNotification, object: nil)
    }

    @objc func handleSchedulingContextChanged(_ notification: Notification) {
        scheduleNextCheckin()
    }

    func triggerCheckin() {
        sendNotification()
        scheduleNextCheckin()
    }

    func randomTimeInHour(from date: Date) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
        components.minute = Int.random(in: 0...59)
        components.second = Int.random(in: 0...59)
        return Calendar.current.date(from: components) ?? date
    }

    func nextAllowedCheckinTime(from now: Date) -> Date {
        let calendar = Calendar.current
        guard let startOfHour = calendar.dateInterval(of: .hour, for: now)?.start else {
            return now.addingTimeInterval(60)
        }

        for offset in 0...48 {
            guard let hourDate = calendar.date(byAdding: .hour, value: offset, to: startOfHour) else { continue }
            let hour = calendar.component(.hour, from: hourDate)
            guard isHourAllowed(hour) else { continue }
            let target = randomTimeInHour(from: hourDate)
            if target > now {
                return target
            }
        }

        return now.addingTimeInterval(3600)
    }

    func isHourAllowed(_ hour: Int) -> Bool {
        if notificationStartHour == notificationEndHour {
            return true
        }
        if notificationStartHour < notificationEndHour {
            return hour >= notificationStartHour && hour < notificationEndHour
        }
        return hour >= notificationStartHour || hour < notificationEndHour
    }
}
