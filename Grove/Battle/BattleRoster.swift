import SwiftData
import Foundation
import Observation

/// The player's Battlegrounds team — the persisted heart of the "Send to the
/// Arena" ritual.
///
/// Two things live here, on purpose:
///  • **progress** — a friend's earned level & XP (and current rest timer), kept
///    *per friend forever* (until they're released). Benching never wipes it.
///  • **team** — the up-to-three friends who are *active* right now.
///
/// Keyed by a stable value derived from each catch's immutable fields (when it
/// was met + where), not by `PersistentIdentifier` — which does not survive a
/// JSON round-trip across app launches. Stored in UserDefaults, so the SwiftData
/// store (and everyone's shipped Grove) is never touched or migrated.
@Observable
final class BattleRoster {
    static let shared = BattleRoster()

    struct Progress: Codable, Hashable {
        var level: Int
        var xp: Int
        var promotedAt: Date
        /// When set and in the future, this friend is napping and can't be sent.
        var restingUntil: Date? = nil
    }

    /// Active-team size. Starts at three; grows later with trainer level.
    let maxSlots = 3

    private(set) var progress: [String: Progress] = [:]
    private(set) var team: [String] = []   // ordered active slots, holds friend keys

    private let storeKey = "bg.roster.v1"
    private init() { load() }

    /// A stable, launch-surviving id for a catch, from fields that never change
    /// after it's met (re-identifying only touches species/nickname/zone).
    private func key(for c: Catch) -> String {
        let t = c.caughtAt.timeIntervalSinceReferenceDate.bitPattern
        let la = (c.latitude ?? 0).bitPattern
        let lo = (c.longitude ?? 0).bitPattern
        return "\(t)-\(la)-\(lo)"
    }

    // MARK: - Queries

    func teamContains(_ c: Catch) -> Bool { team.contains(key(for: c)) }
    func progress(for c: Catch) -> Progress? { progress[key(for: c)] }
    func hasEverPromoted(_ c: Catch) -> Bool { progress[key(for: c)] != nil }
    var hasFreeSlot: Bool { team.count < maxSlots }
    var isFull: Bool { team.count >= maxSlots }

    /// The active team, resolved to real friends and in slot order. Silently
    /// drops any whose friend was released.
    func teamCatches(from all: [Catch]) -> [(friend: Catch, progress: Progress)] {
        let byKey = Dictionary(all.map { (key(for: $0), $0) }, uniquingKeysWith: { a, _ in a })
        return team.compactMap { k in
            guard let friend = byKey[k], let p = progress[k] else { return nil }
            return (friend, p)
        }
    }

    // MARK: - Rest (the mandatory post-match nap)

    func isResting(_ c: Catch) -> Bool {
        guard let u = progress(for: c)?.restingUntil else { return false }
        return u > Date()
    }
    /// Seconds left on the nap, or 0 if ready.
    func restRemaining(_ c: Catch) -> TimeInterval {
        guard let u = progress(for: c)?.restingUntil else { return 0 }
        return max(0, u.timeIntervalSinceNow)
    }
    /// Put a friend down for a nap after a match — longer the more worn out they
    /// are. (Dev-scaled to seconds; the real game paces this at ~20–40 minutes.)
    func beginRest(_ c: Catch, hpFraction: Double) {
        let k = key(for: c)
        guard var p = progress[k] else { return }
        let worn = 1 - max(0, min(1, hpFraction))
        let seconds = 30.0 + worn * 90.0
        p.restingUntil = Date().addingTimeInterval(seconds)
        progress[k] = p
        save()
    }

    // MARK: - Mutations

    /// Add a friend to an open slot, minting Level 1 progress the first time and
    /// otherwise keeping whatever they earned before. No-op if already active or full.
    @discardableResult
    func promote(_ c: Catch) -> Bool {
        let k = key(for: c)
        guard !team.contains(k), hasFreeSlot else { return false }
        if progress[k] == nil {
            progress[k] = Progress(level: 1, xp: 0, promotedAt: .now)
        }
        team.append(k)
        save()
        return true
    }

    /// Take a friend off the active team — their level & XP are kept.
    func bench(_ c: Catch) {
        team.removeAll { $0 == key(for: c) }
        save()
    }

    /// Bench `out` and bring `incoming` on in the same move (for a full team).
    func swap(out: Catch, incoming: Catch) {
        let outK = key(for: out), inK = key(for: incoming)
        guard let idx = team.firstIndex(of: outK) else { promote(incoming); return }
        if progress[inK] == nil {
            progress[inK] = Progress(level: 1, xp: 0, promotedAt: .now)
        }
        team.remove(at: idx)
        team.removeAll { $0 == inK }          // in case it was elsewhere on the team
        team.insert(inK, at: min(idx, team.count))
        save()
    }

    // MARK: - XP & leveling

    /// XP required to advance *from* `level` to the next. A gentle early curve.
    static func xpNeeded(for level: Int) -> Int { 60 + (level - 1) * 40 }

    /// Award XP for a finished match (winners earn more). Returns levels gained.
    @discardableResult
    func award(to c: Catch, won: Bool) -> Int {
        let k = key(for: c)
        guard var p = progress[k] else { return 0 }
        p.xp += won ? 100 : 45
        var gained = 0
        while p.level < 30 && p.xp >= Self.xpNeeded(for: p.level) {
            p.xp -= Self.xpNeeded(for: p.level)
            p.level += 1
            gained += 1
        }
        progress[k] = p
        save()
        return gained
    }

    // MARK: - Housekeeping

    /// Drop team slots & progress for friends that no longer exist (released).
    func prune(against all: [Catch]) {
        let live = Set(all.map { key(for: $0) })
        let before = (team.count, progress.count)
        team.removeAll { !live.contains($0) }
        progress = progress.filter { live.contains($0.key) }
        if (team.count, progress.count) != before { save() }
    }

    // MARK: - Persistence

    private struct Blob: Codable {
        var team: [String]
        var progress: [String: Progress]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let blob = try? JSONDecoder().decode(Blob.self, from: data) else { return }
        team = blob.team
        progress = blob.progress
    }

    private func save() {
        let blob = Blob(team: team, progress: progress)
        if let data = try? JSONEncoder().encode(blob) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
