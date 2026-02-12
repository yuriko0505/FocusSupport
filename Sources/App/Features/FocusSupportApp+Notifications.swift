import AppKit
import UserNotifications

extension FocusSupportApp {
    func sendNotification() {
        guard notificationsEnabled else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Focus Support"
        content.subtitle = "今何考えてる？"
        content.body = "クリックして思考を共有してください 🤔"
        content.sound = .default
        if let attachment = currentNotificationAttachment() {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func ensureNotificationAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted {
                        DispatchQueue.main.async {
                            // 許可直後に一度通知を出す
                            self.sendNotification()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.showAlert(title: "通知が許可されていません",
                                           message: "システム設定の通知からFocusSupportを許可してください。")
                        }
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    self.showAlert(title: "通知が許可されていません",
                                   message: "システム設定の通知からFocusSupportを許可してください。")
                }
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                break
            }
        }
    }

    // バナー表示中にアプリが前面でも通知を表示させる
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // バナークリックでチェックイン画面を表示
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            DispatchQueue.main.async { [weak self] in
                self?.manualCheckin()
            }
        }
        completionHandler()
    }
}
