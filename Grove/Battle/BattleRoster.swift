import SwiftData
import Foundation
import Observation

/// The player's Battlegrounds team — the persisted heart of the "Send to the
/// Arena" ritual.
///
/// Two things live here, on purpose:
///  • **progress** — a friend's earned level & XP, kept *per friend forever*
///    (until they're released). Benching a friend never wipes what they earned.
///  • **team** — the up-to-three friends who are *active* right now.
///
/// Stored in UserDefaults keyed by each friend's `persistentModelID`, so the
/// SwiftData store (and everyone's shipped Grove) is never touched or migrated.
@Observable
final class BattleRoster {
    static let shared = BattleRoster()

    struct Progress: Codable, Hashable {
        var level: Int
        var xp: Int
        var promotedAt: Date
    }

    /// Active-team size. Starts at three; grows later with trainer level.
    let maxSlots = 3

    private(set) var progress: [PersistentIdentifier: Progress] = [:]
    private(set) var team: [PersistentIdentifier] = []   // ordered active slots

    private let key = "bg.roster.v1"
    private init() { load() }

    // MARK: - Queries

    func teamContains(_ c: Catch) -> Bool { team.contains(c.persistentModelID) }
    func progress(for c: Catch) -> Progress? { progress[c.persistentModelID] }
    func hasEverPromoted(_ c: Catch) -> Bool { progress[c.persistentModelID] != nil }
    var hasFreeSlot: Bool { team.count < maxSlots }
    var isFull: Bool { team.count >= maxSlots }

    /// The active team, resolved to real friends and in slot order. Silently
    /// drops any whose friend was released.
    func teamCatches(from all: [Catch]) -> [(friend: Catch, progress: Progress)] {
        team.compactMap { id in
            guard let friend = all.first(where: { $0.persistentModelID == id }),
                  let p = progress[id] else { return nil }
            return (friend, p)
        }
    }

    // MARK: - Mutations

    /// Add a friend to an open slot, minting Level 1 progress the first time and
    /// otherwise keeping whatever they earned before. No-op if already active or full.
    @discardableResult
    func promote(_ c: Catch) -> Bool {
        let id = c.persistentModelID
        guard !team.contains(id), hasFreeSlot else { return false }
        if progress[id] == nil {
            progress[id] = Progress(level: 1, xp: 0, promotedAt: .now)
        }
        team.append(id)
        save()
        return true
    }

    /// Take a friend off the active team — their level & XP are kept.
    func bench(_ c: Catch) {
        team.removeAll { $0 == c.persistentModelID }
        save()
    }

    /// Bench `out` and bring `incoming` on in the same move (for a full team).
    func swap(out: Catch, incoming: Catch) {
        guard let idx = team.firstIndex(of: out.persistentModelID) else {
            promote(incoming); return
        }
        let inID = incoming.persistentModelID
        if progress[inID] == nil {
            progress[inID] = Progress(level: 1, xp: 0, promotedAt: .now)
        }
        team.remove(at: idx)
        team.removeAll { $0 == inID }        // in case it was elsewhere on the team
        team.insert(inID, at: min(idx, team.count))
        save()
    }

    // MARK: - XP & leveling

    /// XP required to advance *from* `level` to the next. A gentle early curve.
    static func xpNeeded(for level: Int) -> Int { 60 + (level - 1) * 40 }

    /// Award XP for a finished match (winners earn more). Returns levels gained.
    @discardableResult
    func award(to c: Catch, won: Bool) -> Int {
        let id = c.persistentModelID
        guard var p = progress[id] else { return 0 }
        p.xp += won ? 100 : 45
        var gained = 0
        while p.level < 30 && p.xp >= Self.xpNeeded(for: p.level) {
            p.xp -= Self.xpNeeded(for: p.level)
            p.level += 1
            gained += 1
        }
        progress[id] = p
        save()
        return gained
    }

    // MARK: - Housekeeping

    /// Drop team slots & progress for friends that no longer exist (released).
    func prune(against all: [Catch]) {
        let live = Set(all.map { $0.persistentModelID })
        let before = (team.count, progress.count)
        team.removeAll { !live.contains($0) }
        progress = progress.filter { live.contains($0.key) }
        if (team.count, progress.count) != before { save() }
    }

    // MARK: - Persistence

    private struct Blob: Codable {
        var team: [PersistentIdentifier]
        var progress: [PersistentIdentifier: Progress]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let blob = try? JSONDecoder().decode(Blob.self, from: data) else { return }
        team = blob.team
        progress = blob.progress
    }

    private func save() {
        let blob = Blob(team: team, progress: progress)
        if let data = try? JSONEncoder().encode(blob) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
