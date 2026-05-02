import Foundation

struct Announcement: Codable, Identifiable {
    let id: Int
    let title: String
    let body: String
    let imageUrl: String?
    let createdAt: Date?
}
