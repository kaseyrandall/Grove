import SwiftData
import Foundation
import Observation

/// The player's Battlegrounds team — the persisted heart of the "Send to the
/// Arena" ritual.
///
/// Three things live here:
///  • **progress** — a friend's earned level & XP (and rest timer), kept per
///    friend forever (until released). Benching never wipes it.
///  • **team** — the up-to-three friends who are active right now.
///  • **pending** — a friend currently *away at a match* (dispatched): the
///    result is computed and held until the away window resolves, then it lands.
///
/// Keyed by a stable value derived from each catch's immutable fields, not by
/// `PersistentIdentifier` (which doesn't survive a JSON round-trip). Stored in
/// UserDefaults, so the SwiftData store is never touched or migrated.
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

    /// A friend dispatched to a match: the fight is already resolved (deterministic)
    /// but held until `resolvesAt`, standing in for async pairing. Everything
    /// needed to reproduce the exact replay is stored, so no live `BattleResult`
    /// has to be persisted.
    struct PendingMatch: Codable, Hashable {
        var seed: UInt64
        var level: Int
        var plan: StoredPlan
        var oppName: String
        var oppType: BattleType
        var oppArchetype: Archetype
        var hpFraction: Double     // fighter's end HP fraction → rest length
        var won: Bool
        var resolvesAt: Date
        var settled: Bool          // XP + rest applied?
        var watched: Bool          // replay seen?
    }

    /// A finished match, kept for the History tab. Stores everything needed to
    /// reproduce the exact replay from the seed — no live BattleResult persisted.
    struct MatchRecord: Codable, Hashable, Identifiable {
        var id: UUID
        var date: Date
        var fighterKey: String
        var fighterName: String
        var fighterType: BattleType
        var fighterArchetype: Archetype
        var level: Int
        var plan: StoredPlan
        var oppName: String
        var oppType: BattleType
        var oppArchetype: Archetype
        var seed: UInt64
        var won: Bool

        func replay() -> BattleResult {
            let f = BattleCard(name: fighterName, type: fighterType, archetype: fighterArchetype, level: level)
            let o = BattleCard(name: oppName, type: oppType, archetype: oppArchetype, level: level)
            return simulate(f, plan.battlePlan, vs: o, .defaultPlan(for: oppArchetype), seed: seed)
        }
    }

    /// Active-team size. Starts at three; grows later with trainer level.
    let maxSlots = 3
    /// How long a friend is "away" before the result is ready. Dev-scaled — a
    /// short beat standing in for real async pairing.
    let awaySeconds: TimeInterval = 20

    private(set) var progress: [String: Progress] = [:]
    private(set) var team: [String] = []
    private(set) var plans: [String: StoredPlan] = [:]
    private(set) var pending: [String: PendingMatch] = [:]
    private(set) var history: [MatchRecord] = []

    private let storeKey = "bg.roster.v1"
    private init() { load() }

    private func key(for c: Catch) -> String {
        let t = c.caughtAt.timeIntervalSinceReferenceDate.bitPattern
        let la = (c.latitude ?? 0).bitPattern
        let lo = (c.longitude ?? 0).bitPattern
        return "\(t)-\(la)-\(lo)"
    }
    private func notifID(_ k: String) -> String { "grove.bg.\(k)" }

    // MARK: - Queries

    func teamContains(_ c: Catch) -> Bool { team.contains(key(for: c)) }
    func progress(for c: Catch) -> Progress? { progress[key(for: c)] }
    func hasEverPromoted(_ c: Catch) -> Bool { progress[key(for: c)] != nil }
    var hasFreeSlot: Bool { team.count < maxSlots }
    var isFull: Bool { team.count >= maxSlots }

    func teamCatches(from all: [Catch]) -> [(friend: Catch, progress: Progress)] {
        let byKey = Dictionary(all.map { (key(for: $0), $0) }, uniquingKeysWith: { a, _ in a })
        return team.compactMap { k in
            guard let friend = byKey[k], let p = progress[k] else { return nil }
            return (friend, p)
        }
    }

    // MARK: - Rest

    func isResting(_ c: Catch) -> Bool {
        guard let u = progress(for: c)?.restingUntil else { return false }
        return u > Date()
    }
    func restRemaining(_ c: Catch) -> TimeInterval {
        guard let u = progress(for: c)?.restingUntil else { return 0 }
        return max(0, u.timeIntervalSinceNow)
    }
    /// Put a friend down for a nap — longer the more worn out they finished.
    /// (Dev-scaled to seconds; the real game paces this at ~20–40 minutes.)
    func beginRest(_ c: Catch, hpFraction: Double) {
        let k = key(for: c)
        guard var p = progress[k] else { return }
        let worn = 1 - max(0, min(1, hpFraction))
        p.restingUntil = Date().addingTimeInterval(30.0 + worn * 90.0)
        progress[k] = p
        save()
    }

    // MARK: - Away matches (dispatch → resolve)

    /// True while a friend is off at a match (dispatched, not yet resolved).
    func isAway(_ c: Catch) -> Bool {
        if let pm = pending[key(for: c)] { return !pm.settled }
        return false
    }
    /// Seconds until the away match resolves.
    func awayRemaining(_ c: Catch) -> TimeInterval {
        guard let pm = pending[key(for: c)], !pm.settled else { return 0 }
        return max(0, pm.resolvesAt.timeIntervalSinceNow)
    }
    /// A resolved match whose replay hasn't been watched yet.
    func hasUnwatchedResult(_ c: Catch) -> Bool {
        if let pm = pending[key(for: c)] { return pm.settled && !pm.watched }
        return false
    }
    /// The stored outcome (win/loss) of the pending/last match, if any.
    func pendingWon(_ c: Catch) -> Bool? { pending[key(for: c)]?.won }

    /// Available to send: not already away, and not napping.
    func canSend(_ c: Catch) -> Bool { !isAway(c) && !isResting(c) }

    /// Dispatch a friend to a match. The fight is resolved now (deterministic)
    /// but held; XP and rest land when it resolves.
    func send(_ c: Catch, opponent: Contender, level: Int, plan: StoredPlan,
              seed: UInt64, result: BattleResult) {
        let k = key(for: c)
        let won: Bool = { if case .win(let n) = result.outcome { return n == c.displayName } else { return false } }()
        let maxHP = Double(max(1, result.fighters[0].maxHP))
        let endHP = Double(max(0, result.events.last?.hpAfter.first ?? result.fighters[0].maxHP))
        let resolvesAt = Date().addingTimeInterval(awaySeconds)
        pending[k] = PendingMatch(seed: seed, level: level, plan: plan,
                                  oppName: opponent.name, oppType: opponent.type,
                                  oppArchetype: opponent.archetype,
                                  hpFraction: endHP / maxHP, won: won,
                                  resolvesAt: resolvesAt, settled: false, watched: false)
        save()
        NotificationManager.scheduleMatchResult(id: notifID(k), friendName: c.displayName, at: resolvesAt)
    }

    /// Land any away matches whose window has passed: apply XP, start the nap.
    /// Called lazily whenever the home is on screen (no background process).
    func settleDueMatches(from all: [Catch]) {
        let now = Date()
        var changed = false
        for c in all {
            let k = key(for: c)
            guard var pm = pending[k], !pm.settled, pm.resolvesAt <= now else { continue }
            _ = award(to: c, won: pm.won)
            beginRest(c, hpFraction: pm.hpFraction)
            pm.settled = true
            pending[k] = pm
            let cont = Contender.from(c)
            history.insert(MatchRecord(id: UUID(), date: Date(), fighterKey: k,
                                       fighterName: c.displayName, fighterType: cont.type,
                                       fighterArchetype: cont.archetype, level: pm.level, plan: pm.plan,
                                       oppName: pm.oppName, oppType: pm.oppType,
                                       oppArchetype: pm.oppArchetype, seed: pm.seed, won: pm.won), at: 0)
            if history.count > 40 { history.removeLast(history.count - 40) }
            changed = true
        }
        if changed { save() }
    }

    /// Mark the resolved match's replay as watched (clears the "result ready" badge).
    func markWatched(_ c: Catch) {
        let k = key(for: c)
        guard var pm = pending[k], pm.settled, !pm.watched else { return }
        pm.watched = true
        pending[k] = pm
        save()
        NotificationManager.cancelMatchResult(id: notifID(k))
    }

    /// Reproduce the exact replay of a friend's pending/last match.
    func replayResult(for c: Catch) -> BattleResult? {
        guard let pm = pending[key(for: c)] else { return nil }
        let fighter = Contender.from(c).card(level: pm.level)
        let opp = BattleCard(name: pm.oppName, type: pm.oppType, archetype: pm.oppArchetype, level: pm.level)
        return simulate(fighter, pm.plan.battlePlan, vs: opp, .defaultPlan(for: pm.oppArchetype), seed: pm.seed)
    }

    #if DEBUG
    /// Dev: collapse an away friend's window so it resolves on the next tick.
    func devResolveNow(_ c: Catch) {
        let k = key(for: c)
        guard var pm = pending[k], !pm.settled else { return }
        pm.resolvesAt = Date()
        pending[k] = pm
        save()
    }
    #endif

    /// Most-recent-first log of finished matches.
    func matchHistory() -> [MatchRecord] { history }

    /// The fighter's current photo for a record, if the friend still exists.
    func friendPhoto(for record: MatchRecord, in all: [Catch]) -> Data? {
        all.first { key(for: $0) == record.fighterKey }?.photoData
    }

    // MARK: - Mutations

    @discardableResult
    func promote(_ c: Catch) -> Bool {
        let k = key(for: c)
        guard !team.contains(k), hasFreeSlot else { return false }
        if progress[k] == nil { progress[k] = Progress(level: 1, xp: 0, promotedAt: .now) }
        team.append(k)
        save()
        return true
    }

    func bench(_ c: Catch) {
        team.removeAll { $0 == key(for: c) }
        save()
    }

    func swap(out: Catch, incoming: Catch) {
        let outK = key(for: out), inK = key(for: incoming)
        guard let idx = team.firstIndex(of: outK) else { promote(incoming); return }
        if progress[inK] == nil { progress[inK] = Progress(level: 1, xp: 0, promotedAt: .now) }
        team.remove(at: idx)
        team.removeAll { $0 == inK }
        team.insert(inK, at: min(idx, team.count))
        save()
    }

    // MARK: - XP & leveling

    static func xpNeeded(for level: Int) -> Int { 60 + (level - 1) * 40 }

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

    // MARK: - Battle plans

    func storedPlan(for c: Catch, archetype: Archetype) -> StoredPlan {
        plans[key(for: c)] ?? StoredPlan(.defaultPlan(for: archetype))
    }
    func hasCustomPlan(_ c: Catch) -> Bool { plans[key(for: c)] != nil }
    func setPlan(_ plan: StoredPlan, for c: Catch) {
        plans[key(for: c)] = plan
        save()
    }
    func battlePlan(for c: Catch, archetype: Archetype) -> BattlePlan {
        storedPlan(for: c, archetype: archetype).battlePlan
    }

    // MARK: - Housekeeping

    func prune(against all: [Catch]) {
        let live = Set(all.map { key(for: $0) })
        let before = (team.count, progress.count, pending.count)
        team.removeAll { !live.contains($0) }
        progress = progress.filter { live.contains($0.key) }
        plans = plans.filter { live.contains($0.key) }
        pending = pending.filter { live.contains($0.key) }
        if (team.count, progress.count, pending.count) != before { save() }
    }

    // MARK: - Persistence

    private struct Blob: Codable {
        var team: [String]
        var progress: [String: Progress]
        var plans: [String: StoredPlan]?
        var pending: [String: PendingMatch]?
        var history: [MatchRecord]?
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let blob = try? JSONDecoder().decode(Blob.self, from: data) else { return }
        team = blob.team
        progress = blob.progress
        plans = blob.plans ?? [:]
        pending = blob.pending ?? [:]
        history = blob.history ?? []
    }

    private func save() {
        let blob = Blob(team: team, progress: progress, plans: plans, pending: pending, history: history)
        if let data = try? JSONEncoder().encode(blob) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
