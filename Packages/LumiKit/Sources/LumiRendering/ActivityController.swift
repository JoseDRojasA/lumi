import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

/// Drives Lumi's "activities" (jump, dance, random idles) as a procedural motion
/// source, mirroring `SecondaryMotionController`: fully deterministic from
/// elapsed time and a seeded RNG (no `SKAction`, no wall clock, no system RNG),
/// so it is testable headless. Activities layer additively on top of breathing
/// and secondary motion through the shared `PetMotionComposer`.
///
/// An internal `ActivityDirector` schedules weighted-random idle activities
/// during rest. Explicit `play(_:)` (e.g. from a minigame) interrupts and takes
/// precedence over the director.
///
/// - Important: `advance(by:)` never calls `composer.apply()`; the scene applies
///   the composer once per frame after breathing's actions.
@MainActor
public final class ActivityController {
    /// The composer source key under which activities contribute offsets.
    public static let source: PetMotionSource = "activity"

    /// Channels an activity may write. On each frame every channel NOT touched by
    /// the current activity is explicitly cleared to `.identity` for this source,
    /// so no stale offset can linger (matching the composer's no-drift contract).
    private static let drivableChannels: [PetMotionChannel] = [
        .root, .abdomen, .chest, .head, .paws, .leftEar, .rightEar, .tail
    ]

    private let composer: PetMotionComposer

    /// Whether activities are permitted at all (disabled on low tiers, e.g. watch).
    private let isEnabled: Bool

    /// Amplitude scale applied to all activity motion (Reduce Motion → reduced).
    private var amplitudeScale: Double

    public private(set) var elapsed: TimeInterval = 0
    public private(set) var current: PetActivity?

    private enum State {
        case idle
        case playing(activity: PetActivity, startElapsed: Double, explicit: Bool)
    }
    private var state: State = .idle

    private var director: ActivityDirector

    public init(
        composer: PetMotionComposer,
        configuration: PetConfiguration,
        reduceMotion: Bool,
        isEnabled: Bool
    ) {
        self.composer = composer
        self.isEnabled = isEnabled
        self.amplitudeScale = reduceMotion ? 0.25 : 1.0
        // Distinct seed constant from SecondaryMotionController's 0xA11CE_5EED so
        // activity scheduling doesn't correlate with secondary motion.
        self.director = ActivityDirector(rng: SplitMix64(seed: configuration.seed ^ 0xAC71_71D0))
        if isEnabled {
            director.scheduleFirst(now: 0)
        }
    }

    // MARK: - Public API

    /// Advances schedules by `dt` (clamped to `0...0.1`) and writes the current
    /// activity's offsets into the composer under ``source``. Does NOT call
    /// `composer.apply()`.
    public func advance(by dt: TimeInterval) {
        guard isEnabled else { return }
        let clamped = min(0.1, max(0, dt))
        elapsed += clamped

        switch state {
        case .idle:
            // Ask the director whether it's time to start an idle activity.
            if let next = director.activityToStart(now: elapsed) {
                begin(next, explicit: false)
            } else {
                writeIdentity()
            }
        case let .playing(activity, startElapsed, explicit):
            let raw = (elapsed - startElapsed) / activity.duration
            if activity.loops {
                let p = raw - floor(raw)
                writeActivity(activity, progress: p)
            } else if raw >= 1 {
                // Finished: clear, return to idle, reschedule the next idle.
                finish()
            } else {
                writeActivity(activity, progress: max(0, raw))
                _ = explicit  // explicit vs scheduled only matters for director gating
            }
        }
    }

    /// Interrupts any current activity and plays `activity` immediately. Explicit
    /// play overrides the director; the director will not auto-schedule while a
    /// non-looping explicit activity is mid-play.
    public func play(_ activity: PetActivity) {
        guard isEnabled else { return }
        begin(activity, explicit: true)
    }

    /// Ends the current activity, clears offsets, returns to idle, and reschedules.
    public func stopActivity() {
        finish()
    }

    /// Clears this controller's composer source across all channels, returns to
    /// idle. Called by the scene on `stopAnimation()`.
    public func reset() {
        state = .idle
        current = nil
        // clear(source:) removes this source's contribution from every channel.
        composer.clear(source: Self.source)
    }

    /// Updates the amplitude scale live; applies from the next `advance`.
    public func setReduceMotion(_ enabled: Bool) {
        amplitudeScale = enabled ? 0.25 : 1.0
    }

    // MARK: - Private

    private func begin(_ activity: PetActivity, explicit: Bool) {
        state = .playing(activity: activity, startElapsed: elapsed, explicit: explicit)
        current = activity
        writeActivity(activity, progress: 0)
    }

    private func finish() {
        state = .idle
        current = nil
        writeIdentity()
        director.scheduleNext(now: elapsed)
    }

    /// Writes the activity's per-channel offsets, clearing every untouched
    /// drivable channel to `.identity` so nothing lingers.
    private func writeActivity(_ activity: PetActivity, progress: Double) {
        let offsets = activity.sample(atProgress: progress, amplitudeScale: amplitudeScale)
        for channel in Self.drivableChannels {
            composer.set(offsets[channel] ?? .identity, for: channel, from: Self.source)
        }
    }

    /// Neutral contribution on every drivable channel (idle).
    private func writeIdentity() {
        for channel in Self.drivableChannels {
            composer.set(.identity, for: channel, from: Self.source)
        }
    }
}

/// Deterministic scheduler for random idle activities. Draws inter-activity
/// intervals and picks weighted-random idles from `PetActivity.idleActivities`,
/// avoiding immediate repeats. Pure w.r.t. its RNG so tests are reproducible.
struct ActivityDirector {
    /// Seconds between idle activities.
    private static let interval: ClosedRange<Double> = 6.0...16.0

    private var rng: SplitMix64
    private var nextTime: Double = .greatestFiniteMagnitude
    private var lastIndex: Int = -1

    init(rng: SplitMix64) {
        self.rng = rng
    }

    /// Schedules the first idle relative to `now`.
    mutating func scheduleFirst(now: Double) {
        nextTime = now + drawInterval()
    }

    /// Schedules the next idle relative to `now` (after one finishes).
    mutating func scheduleNext(now: Double) {
        nextTime = now + drawInterval()
    }

    /// Returns an activity to start if `now` has reached the scheduled time, and
    /// arms nothing further (the controller reschedules when the activity ends).
    mutating func activityToStart(now: Double) -> PetActivity? {
        guard now >= nextTime else { return nil }
        // Prevent re-triggering every frame until the controller reschedules.
        nextTime = .greatestFiniteMagnitude
        return pickIdle()
    }

    private mutating func pickIdle() -> PetActivity {
        let activities = PetActivity.idleActivities
        guard !activities.isEmpty else { return .stretch }
        if activities.count == 1 { return activities[0] }
        var index = Int(next() % UInt64(activities.count))
        if index == lastIndex {
            index = (index + 1) % activities.count  // avoid immediate repeat
        }
        lastIndex = index
        return activities[index]
    }

    private mutating func drawInterval() -> Double {
        Self.interval.lowerBound + unit() * (Self.interval.upperBound - Self.interval.lowerBound)
    }

    private mutating func next() -> UInt64 { rng.next() }

    private mutating func unit() -> Double {
        Double(rng.next() >> 11) / 9_007_199_254_740_992
    }
}
