import Foundation

struct StoredSessionReport: Codable {
    let sessionId: UUID
    let session: Session
    let imuSamples: [IMUSample]
    let cueEvents: [CueEvent]
    let swingSegments: [StoredSwingSegment]
    let stats: StoredSessionStats?
}

struct StoredSwingSegment: Codable {
    let startIndex: Int
    let endIndex: Int
}
