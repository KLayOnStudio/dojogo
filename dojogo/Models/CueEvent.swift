// CueEvent.swift
// DojoGo - Model for guided session cue events
//
// Stores timestamps for visual/sound cues aligned to the session timebase
// (ms since session start). Used for post-session analysis and chart overlays.

import Foundation

struct CueEvent: Codable, Identifiable {
    let cueId: UUID
    var imuSessionId: Int64?
    let cueIndex: Int
    let cueType: CueType
    let scheduledAtMs: Int
    var visualAtMs: Int?
    var soundAtMs: Int?
    var userActionAtMs: Int?
    var reactionTimeMs: Int?
    var meta: [String: String]?

    var id: UUID { cueId }

    enum CueType: String, Codable {
        case countdownTick = "countdown_tick"
        case countdownGo = "countdown_go"
        case zanshinFill = "zanshin_fill"
        case postZanshinCue = "post_zanshin_cue"
        case falseStart = "false_start"          // swing before Men! cue
    }
}
