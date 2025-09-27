import Foundation

struct Session: Codable, Identifiable {
    let id: UUID
    let userId: String
    let date: Date
    let tapCount: Int
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date

    init(userId: String, tapCount: Int, startTime: Date, endTime: Date) {
        self.id = UUID()
        self.userId = userId
        self.date = startTime
        self.tapCount = tapCount
        self.duration = endTime.timeIntervalSince(startTime)
        self.startTime = startTime
        self.endTime = endTime
    }
}