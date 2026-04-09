// CueEventLogger.swift
// DojoGo - Collects cue events during a guided session
//
// Events are stored in memory during the session and flushed
// to the backend at session end.

import Foundation

final class CueEventLogger {
    private let clock: SessionClock
    private(set) var events: [CueEvent] = []
    private var nextIndex: Int = 0

    init(clock: SessionClock) {
        self.clock = clock
    }

    /// Log a cue event with timestamps captured at the moment of firing.
    @discardableResult
    func log(
        type: CueEvent.CueType,
        scheduledAtMs: Int,
        visualAtMs: Int? = nil,
        soundAtMs: Int? = nil,
        userActionAtMs: Int? = nil,
        meta: [String: String]? = nil
    ) -> CueEvent {
        let reactionMs: Int?
        if let action = userActionAtMs {
            let cueDeliveryMs = [visualAtMs, soundAtMs].compactMap { $0 }.max()
            reactionMs = cueDeliveryMs.map { action - $0 }
        } else {
            reactionMs = nil
        }

        let event = CueEvent(
            cueId: UUID(),
            imuSessionId: nil,
            cueIndex: nextIndex,
            cueType: type,
            scheduledAtMs: scheduledAtMs,
            visualAtMs: visualAtMs,
            soundAtMs: soundAtMs,
            userActionAtMs: userActionAtMs,
            reactionTimeMs: reactionMs,
            meta: meta
        )
        events.append(event)
        nextIndex += 1
        return event
    }

    /// Update reaction data for a previously logged cue.
    func recordUserAction(for cueId: UUID, actionAtMs: Int) {
        guard let idx = events.firstIndex(where: { $0.cueId == cueId }) else { return }
        events[idx].userActionAtMs = actionAtMs
        let cueDeliveryMs = [events[idx].visualAtMs, events[idx].soundAtMs].compactMap { $0 }.max()
        if let delivery = cueDeliveryMs {
            events[idx].reactionTimeMs = actionAtMs - delivery
        }
    }

    /// Current time from session clock (convenience).
    var nowMs: Int { clock.nowMs }
}
