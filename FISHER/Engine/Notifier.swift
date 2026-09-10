import Foundation
import UserNotifications

enum Notifier {

    static func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// The app is allowed to speak seldom, so when it does it talks about the
    /// thing, not about itself.
    static func announce(_ edition: Edition) {
        guard Defaults.notifyStyle != .silent, !edition.isQuiet else { return }

        switch Defaults.notifyStyle {
        case .everyItem:
            let items = ([edition.lead].compactMap { $0 } + edition.seconds)
            for item in items { post(title: item.headline, body: item.dek, id: item.id) }
        case .summary, .silent:
            let title: String
            let body: String
            if let lead = edition.lead {
                title = lead.headline
                body = edition.newCount > 1
                    ? "\(lead.dek) Plus \(edition.newCount - 1) more in today's edition."
                    : lead.dek
            } else {
                title = "\(edition.newCount) new in today's edition"
                body = edition.seconds.first?.headline ?? edition.brief.first?.text ?? ""
            }
            post(title: title, body: body, id: "edition-\(edition.id)")
        }
    }

    private static func post(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
