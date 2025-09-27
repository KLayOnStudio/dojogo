import Foundation

struct User: Codable, Identifiable {
    let id: String // Auth0 ID
    let name: String
    let email: String
    var streak: Int
    var totalCount: Int
    var createdAt: Date
    var lastSessionDate: Date?

    init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
        self.streak = 0
        self.totalCount = 0
        self.createdAt = Date()
        self.lastSessionDate = nil
    }
}