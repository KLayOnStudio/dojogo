import Foundation

enum SessionMode: String, Codable {
    case guided = "guided"
    case free = "free"
}

enum SensorMode: String, Codable, CaseIterable {
    case mount = "mount"   // Phone physically mounted on shinai
    case phone = "phone"   // Holding phone alone, swinging shinai separately
    case other = "other"   // Something creative

    var displayName: String {
        switch self {
        case .mount: return "On Shinai"
        case .phone: return "Phone Only"
        case .other: return "Other"
        }
    }

    var detail: String {
        switch self {
        case .mount: return "Phone mounted on shinai"
        case .phone: return "Phone only, no shinai — shadow swinging"
        case .other: return "Something creative"
        }
    }

    var icon: String {
        switch self {
        case .mount: return "iphone.and.arrow.forward"
        case .phone: return "iphone"
        case .other: return "questionmark.circle"
        }
    }
}

struct Session: Codable, Identifiable {
    let id: UUID
    let userId: String
    let date: Date
    let swingCount: Int
    let duration: TimeInterval
    let startTime: Date
    let endTime: Date
    let mode: SessionMode
    let stageId: Int?
    let sensorMode: SensorMode
    let deviceModel: String?

    init(userId: String, swingCount: Int, startTime: Date, endTime: Date, mode: SessionMode = .guided, stageId: Int? = nil, sensorMode: SensorMode = .phone, deviceModel: String? = nil) {
        self.id = UUID()
        self.userId = userId
        self.date = startTime
        self.swingCount = swingCount
        self.duration = endTime.timeIntervalSince(startTime)
        self.startTime = startTime
        self.endTime = endTime
        self.mode = mode
        self.stageId = stageId
        self.sensorMode = sensorMode
        self.deviceModel = deviceModel
    }

    /// Init for server-fetched sessions (known id, date + duration only)
    init(id: UUID, userId: String, date: Date, swingCount: Int, duration: TimeInterval, mode: SessionMode = .guided, stageId: Int? = nil, sensorMode: SensorMode = .phone, deviceModel: String? = nil) {
        self.id = id
        self.userId = userId
        self.date = date
        self.swingCount = swingCount
        self.duration = duration
        self.startTime = date
        self.endTime = date.addingTimeInterval(duration)
        self.mode = mode
        self.stageId = stageId
        self.sensorMode = sensorMode
        self.deviceModel = deviceModel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        date = try container.decode(Date.self, forKey: .date)
        // Support legacy "tapCount" key from before rename to swingCount
        if let count = try? container.decode(Int.self, forKey: .swingCount) {
            swingCount = count
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            swingCount = (try? legacy.decode(Int.self, forKey: .tapCount)) ?? 0
        }
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        mode = (try? container.decode(SessionMode.self, forKey: .mode)) ?? .guided
        stageId = try container.decodeIfPresent(Int.self, forKey: .stageId)
        sensorMode = (try? container.decode(SensorMode.self, forKey: .sensorMode)) ?? .phone
        deviceModel = try container.decodeIfPresent(String.self, forKey: .deviceModel)
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case tapCount
    }

    enum CodingKeys: String, CodingKey {
        case id, userId, date, swingCount, duration, startTime, endTime, mode, stageId, sensorMode, deviceModel
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(date, forKey: .date)
        try container.encode(swingCount, forKey: .swingCount)
        try container.encode(duration, forKey: .duration)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(stageId, forKey: .stageId)
        try container.encode(sensorMode, forKey: .sensorMode)
        try container.encodeIfPresent(deviceModel, forKey: .deviceModel)
    }
}