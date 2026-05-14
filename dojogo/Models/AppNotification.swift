import Foundation

struct AppNotification: Codable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: Date?
    let senderAvatar: String?
}

struct NotificationsResponse: Codable {
    let notifications: [AppNotification]
    let unreadCount: Int
}
