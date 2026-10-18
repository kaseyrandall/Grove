import SwiftData
import Foundation
import Observation

/// The player's Battlegrounds team: the heart of the "Send to the Arena" ritual.
///
/// Where things live, so they sync and can't be lost by accident:
///  • **Per friend** (level, XP, rest, battle plan, a match in progress) is
///    stored on the friend itself (`Catch.battleData`), so it syncs through
///    iCloud with them and goes when they're released. Nothing ever has to be
///    pruned, so a device still syncing can't wipe anyone's progress.
///  • **The team** (who's active) and **match history** live in a small
///    synced settings store (UserDefaults, mirrored to iCloud by
///    `ProfileSync`), keyed by each friend's stable `battleID`.
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

    enum MatchOutcome: String, Codable, Hashable {
        case win, loss, draw

        /// XP for taking part; a draw is worth more than a loss.
        var xp: Int {
            switch self {
            case .win:  return 100
            case .draw: return 70
            case .loss: return 45
            }
        }

        init(_ result: BattleResult) {
            switch result.winner {
            case 0:  self = .win
            case 1:  self = .loss
            default: self = .draw
            }
        }
    }

    /// The friend as they were when sent. A match is locked to this, so
    /// renaming a friend or changing their species or zone mid-match can't
    /// change how the replay plays out.
    struct FighterSnapshot: Codable, Hashable {
        var name: String
        var type: BattleType
        var archetype: Archetype
    }

    /// A friend away at a match: the fight is already resolved (deterministic
    /// from the seed) but held until `resolvesAt`, standing in for async
    /// pairing. Everything needed to reproduce the exact replay is stored.
    struct PendingMatch: Codable, Hashable {
        var seed: UInt64
        var level: Int
        var plan: StoredPlan
        var fighter: FighterSnapshot
        var oppName: String
        var oppType: BattleType
        var oppArchetype: Archetype
        /// The rival's level (older matches: same as the fighter's) and animal.
        var oppLevel: Int? = nil
        var oppSpeciesID: String? = nil
        var hpFraction: Double     // the fighter's end HP fraction → nap length
        var outcome: MatchOutcome
        var resolvesAt: Date
        var settled: Bool          // XP and nap applied?
        var watched: Bool          // replay seen?

        func replay() -> BattleResult {
            let f = BattleCard(name: fighter.name, type: fighter.type, archetype: fighter.archetype, level: level)
            let o = BattleCard(name: oppName, type: oppType, archetype: oppArchetype, level: oppLevel ?? level)
            return simulate(f, plan.battlePlan, vs: o, .defaultPlan(for: oppArchetype), seed: seed)
        }

        var rivalPortrait: BattlePortrait {
            BattlePortrait(species: oppSpeciesID.flatMap(CreatureCatalog.species(for:)))
        }
    }

    /// A finished match, kept for the History tab.
    struct MatchRecord: Codable, Hashable, Identifiable {
        var id: UUID
        var date: Date
        var fighterKey: String     // the friend's battleID
        var fighterName: String
        var fighterType: BattleType
        var fighterArchetype: Archetype
        var level: Int
        var plan: StoredPlan
        var oppName: String
        var oppType: BattleType
        var oppArchetype: Archetype
        var seed: UInt64
        var outcome: MatchOutcome
        var oppLevel: Int? = nil
        var oppSpeciesID: String? = nil

        var won: Bool { outcome == .win }

        func replay() -> BattleResult {
            let f = BattleCard(name: fighterName, type: fighterType, archetype: fighterArchetype, level: level)
            let o = BattleCard(name: oppName, type: oppType, archetype: oppArchetype, level: oppLevel ?? level)
            return simulate(f, plan.battlePlan, vs: o, .defaultPlan(for: oppArchetype), seed: seed)
        }

        var rivalPortrait: BattlePortrait {
            BattlePortrait(species: oppSpeciesID.flatMap(CreatureCatalog.species(for:)))
        }
    }

    /// Everything Battlegrounds knows about one friend, stored on the friend.
    struct FriendState: Codable, Hashable {
        var progress: Progress?
        var plan: StoredPlan?
        var pending: PendingMatch?
    }

    /// Active-team size. Starts at three; grows later with trainer level.
    let maxSlots = 3
    /// Developer builds can run the clock fast (`-GroveFastArena`): seconds
    /// instead of minutes, for testing.
    static var fastPace: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-GroveFastArena")
        #else
        return false
        #endif
    }
    /// How long a friend is away at a match before the result is ready.
    var awaySeconds: TimeInterval { Self.fastPace ? 20 : 20 * 60 }
    /// How many finished matches History keeps.
    static let historyLimit = 40

    private(set) var team: [String] = []
    private(set) var history: [MatchRecord] = []
    private(set) var trophies = TrophyLedger()

    /// Synced keys (mirrored to iCloud by `ProfileSync`).
    static let teamKey = "bg.team"
    static let historyKey = "bg.history"
    static let trophiesKey = "bg.trophies"
    /// First-run: the intro was seen; the Get set up checklist was finished
    /// (or dismissed); the quick first match was used.
    static let introSeenKey = "bg.introSeen"
    static let setupDoneKey = "bg.setupDone"
    static let firstMatchKey = "bg.firstMatchSent"
    /// The pre-sync blob, moved onto friends by `prepare(with:)`.
    private let legacyKey = "bg.roster.v1"

    private let defaults = UserDefaults.standard
    /// True while writing our own changes, so the change notification they
    /// trigger doesn't reload half-written state over them.
    private var isSaving = false

    private init() {
        loadShared()
        // iCloud can update the team or history from another device.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification,
                                               object: defaults, queue: .main) { [weak self] _ in
            self?.loadShared()
        }
    }

    private func notifID(_ k: String) -> String { "grove.bg.\(k)" }

    // MARK: - Per-friend state

    private func state(_ c: Catch) -> FriendState {
        guard let data = c.battleData,
              let s = try? JSONDecoder().decode(FriendState.self, from: data) else { return FriendState() }
        return s
    }

    private func setState(_ s: FriendState, for c: Catch) {
        _ = ensureID(c)
        c.battleData = try? JSONEncoder().encode(s)
        try? c.modelContext?.save()
    }

    private func update(_ c: Catch, _ change: (inout FriendState) -> Void) {
        var s = state(c)
        change(&s)
        setState(s, for: c)
    }

    /// The friend's stable id, given the first time it's needed.
    private func ensureID(_ c: Catch) -> String {
        if let id = c.battleID { return id }
        let id = UUID().uuidString
        c.battleID = id
        return id
    }

    // MARK: - Queries

    func teamContains(_ c: Catch) -> Bool { c.battleID.map(team.contains) ?? false }
    func progress(for c: Catch) -> Progress? { state(c).progress }
    func hasEverPromoted(_ c: Catch) -> Bool { progress(for: c) != nil }
    var hasFreeSlot: Bool { team.count < maxSlots }
    var isFull: Bool { team.count >= maxSlots }

    /// Room on the team, counting only members still in the Grove. (A saved
    /// team can outlive its friends, e.g. after reinstalling without iCloud
    /// backup, since the team syncs separately from the friends.)
    func hasFreeSlot(among all: [Catch]) -> Bool { teamCatches(from: all).count < maxSlots }

    /// Forget team members whose friend is gone, making room. Only done when
    /// the player adds someone, so a team that's still syncing isn't lost.
    private func dropMissingMembers(using c: Catch) {
        guard let all = try? c.modelContext?.fetch(FetchDescriptor<Catch>()) else { return }
        let ids = Set(all.compactMap(\.battleID))
        let kept = team.filter(ids.contains)
        if kept != team { team = kept; saveShared() }
    }

    func teamCatches(from all: [Catch]) -> [(friend: Catch, progress: Progress)] {
        let byID = Dictionary(all.compactMap { c in c.battleID.map { ($0, c) } }, uniquingKeysWith: { a, _ in a })
        return team.compactMap { id in
            guard let friend = byID[id], let p = progress(for: friend) else { return nil }
            return (friend, p)
        }
    }

    // MARK: - Rest

    func isResting(_ c: Catch) -> Bool {
        guard let until = progress(for: c)?.restingUntil else { return false }
        return until > .now
    }
    func restRemaining(_ c: Catch) -> TimeInterval {
        guard let until = progress(for: c)?.restingUntil else { return 0 }
        return max(0, until.timeIntervalSinceNow)
    }
    /// Put a friend down for a nap after a match: 20 minutes fresh, up to 40
    /// when they finished worn out (seconds in fast pace).
    private func beginRest(_ s: inout FriendState, hpFraction: Double, from start: Date) {
        let worn = 1 - max(0, min(1, hpFraction))
        let nap = Self.fastPace ? 30 + worn * 90 : (20 + worn * 20) * 60
        s.progress?.restingUntil = start.addingTimeInterval(nap)
    }

    // MARK: - Away matches (send → resolve)

    /// True while a friend is off at a match (sent, not yet resolved).
    func isAway(_ c: Catch) -> Bool { state(c).pending.map { !$0.settled } ?? false }
    /// Seconds until the away match resolves.
    func awayRemaining(_ c: Catch) -> TimeInterval {
        guard let pm = state(c).pending, !pm.settled else { return 0 }
        return max(0, pm.resolvesAt.timeIntervalSinceNow)
    }
    /// A resolved match whose replay hasn't been watched yet.
    func hasUnwatchedResult(_ c: Catch) -> Bool {
        state(c).pending.map { $0.settled && !$0.watched } ?? false
    }
    /// The outcome of the pending or last match, if any.
    func pendingOutcome(_ c: Catch) -> MatchOutcome? { state(c).pending?.outcome }

    /// Available to send: not already away, and not napping.
    func canSend(_ c: Catch) -> Bool { !isAway(c) && !isResting(c) }

    /// Send a friend to a match. The fight is resolved now (deterministic) but
    /// held; XP and the nap land when it resolves.
    func send(_ c: Catch, opponent: Contender, opponentLevel: Int, level: Int, plan: StoredPlan,
              seed: UInt64, result: BattleResult) {
        let k = ensureID(c)
        let me = Contender.from(c)
        let maxHP = Double(max(1, result.fighters[0].maxHP))
        let endHP = Double(max(0, result.events.last?.hpAfter.first ?? result.fighters[0].maxHP))
        // A brand-new player's first match is quick (a minute), so they see
        // how it works right away.
        let firstEver = history.isEmpty && trophies.matches == 0 && !defaults.bool(forKey: Self.firstMatchKey)
        defaults.set(true, forKey: Self.firstMatchKey)
        let resolvesAt = Date().addingTimeInterval(firstEver ? min(awaySeconds, 60) : awaySeconds)
        update(c) { s in
            s.pending = PendingMatch(seed: seed, level: level, plan: plan,
                                     fighter: FighterSnapshot(name: me.name, type: me.type, archetype: me.archetype),
                                     oppName: opponent.name, oppType: opponent.type,
                                     oppArchetype: opponent.archetype,
                                     oppLevel: opponentLevel, oppSpeciesID: opponent.speciesID,
                                     hpFraction: endHP / maxHP, outcome: MatchOutcome(result),
                                     resolvesAt: resolvesAt, settled: false, watched: false)
        }
        NotificationManager.scheduleMatchResult(id: notifID(k), friendName: c.displayName, at: resolvesAt)
    }

    /// Re-plan the "match is done" pings for friends still away (after the
    /// Reminders switch changes).
    func refreshNotifications(from all: [Catch]) {
        let now = Date.now
        let due = all.compactMap { c -> (id: String, friendName: String, date: Date)? in
            guard let k = c.battleID, let pm = state(c).pending, !pm.settled, pm.resolvesAt > now else { return nil }
            return (notifID(k), c.displayName, pm.resolvesAt)
        }
        NotificationManager.refreshMatchResults(due)
    }

    /// Land any away matches whose window has passed: apply XP, start the
    /// nap, log it to History. Called whenever the Arena is on screen.
    func settleDueMatches(from all: [Catch]) {
        let now = Date.now
        var newRecords: [MatchRecord] = []
        var levels: [UUID: Int] = [:]
        for c in all where c.battleData != nil {
            var s = state(c)
            guard var pm = s.pending, !pm.settled, pm.resolvesAt <= now, s.progress != nil else { continue }
            award(&s, pm.outcome)
            // The nap starts when the match ended, even if you open the
            // Arena much later.
            beginRest(&s, hpFraction: pm.hpFraction, from: pm.resolvesAt)
            pm.settled = true
            s.pending = pm
            setState(s, for: c)
            let id = UUID()
            levels[id] = s.progress?.level
            newRecords.append(MatchRecord(id: id, date: pm.resolvesAt, fighterKey: ensureID(c),
                                          fighterName: pm.fighter.name, fighterType: pm.fighter.type,
                                          fighterArchetype: pm.fighter.archetype, level: pm.level,
                                          plan: pm.plan, oppName: pm.oppName, oppType: pm.oppType,
                                          oppArchetype: pm.oppArchetype, seed: pm.seed, outcome: pm.outcome,
                                          oppLevel: pm.oppLevel, oppSpeciesID: pm.oppSpeciesID))
        }
        guard !newRecords.isEmpty else { return }
        for rec in newRecords.sorted(by: { $0.date < $1.date }) {
            countForTrophies(rec, newLevel: levels[rec.id])
        }
        history.insert(contentsOf: newRecords.sorted { $0.date > $1.date }, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        saveShared()
    }

    /// Mark the resolved match's replay as watched (clears "Result ready").
    func markWatched(_ c: Catch) {
        guard let pm = state(c).pending, pm.settled, !pm.watched else { return }
        update(c) { $0.pending?.watched = true }
        if let k = c.battleID { NotificationManager.cancelMatchResult(id: notifID(k)) }
    }

    /// A finished match whose result hasn't been watched yet.
    func isUnwatched(_ rec: MatchRecord, in all: [Catch]) -> Bool {
        guard let c = friend(for: rec, in: all), let pm = state(c).pending else { return false }
        return pm.settled && !pm.watched && pm.seed == rec.seed
    }

    /// Reproduce the exact replay of a friend's pending or last match.
    func replayResult(for c: Catch) -> BattleResult? { state(c).pending?.replay() }
    /// The rival in a friend's pending or last match, as drawn in the replay.
    func rivalPortrait(for c: Catch) -> BattlePortrait { state(c).pending?.rivalPortrait ?? .none }

    #if DEBUG
    /// Dev: collapse an away friend's window so it resolves on the next tick.
    func devResolveNow(_ c: Catch) {
        guard let pm = state(c).pending, !pm.settled else { return }
        update(c) { $0.pending?.resolvesAt = .now }
    }
    /// Dev: wake a napping friend.
    func devWake(_ c: Catch) {
        update(c) { $0.progress?.restingUntil = nil }
    }
    #endif

    /// Most-recent-first log of finished matches.
    func matchHistory() -> [MatchRecord] { history }

    /// Consecutive wins counted back from the most recent match.
    var winStreak: Int {
        var n = 0
        for rec in history { if rec.won { n += 1 } else { break } }
        return n
    }

    /// Lifetime record across every recorded match.
    var record: (wins: Int, losses: Int, draws: Int) {
        (history.lazy.filter { $0.outcome == .win }.count,
         history.lazy.filter { $0.outcome == .loss }.count,
         history.lazy.filter { $0.outcome == .draw }.count)
    }

    /// The fighter's current photo for a record, if the friend still exists.
    func friendPhoto(for record: MatchRecord, in all: [Catch]) -> Data? {
        friend(for: record, in: all)?.photoData
    }
    func friend(for record: MatchRecord, in all: [Catch]) -> Catch? {
        all.first { $0.battleID == record.fighterKey }
    }

    // MARK: - Team

    @discardableResult
    func promote(_ c: Catch) -> Bool {
        let k = ensureID(c)
        if !hasFreeSlot { dropMissingMembers(using: c) }
        guard !team.contains(k), hasFreeSlot else { return false }
        if progress(for: c) == nil {
            update(c) { $0.progress = Progress(level: 1, xp: 0, promotedAt: .now) }
        } else {
            try? c.modelContext?.save()
        }
        team.append(k)
        saveShared()
        return true
    }

    /// Whether a friend can leave the team: not while they're away at a match
    /// (their result would have nowhere to land).
    func canBench(_ c: Catch) -> Bool { !isAway(c) }

    @discardableResult
    func bench(_ c: Catch) -> Bool {
        guard canBench(c), let k = c.battleID else { return false }
        team.removeAll { $0 == k }
        saveShared()
        return true
    }

    @discardableResult
    func swap(out: Catch, incoming: Catch) -> Bool {
        guard canBench(out), let outK = out.battleID, let idx = team.firstIndex(of: outK) else {
            return promote(incoming)
        }
        let inK = ensureID(incoming)
        if progress(for: incoming) == nil {
            update(incoming) { $0.progress = Progress(level: 1, xp: 0, promotedAt: .now) }
        }
        team.remove(at: idx)
        team.removeAll { $0 == inK }
        team.insert(inK, at: min(idx, team.count))
        saveShared()
        return true
    }

    /// A friend was released: take them off the team (their own battle data
    /// goes with them).
    func forget(_ c: Catch) {
        guard let k = c.battleID else { return }
        NotificationManager.cancelMatchResult(id: notifID(k))
        if team.contains(k) {
            team.removeAll { $0 == k }
            saveShared()
        }
    }

    /// The whole Grove was erased.
    func reset() {
        team = []
        history = []
        trophies = TrophyLedger()
        for key in [Self.introSeenKey, Self.setupDoneKey, Self.firstMatchKey] { defaults.removeObject(forKey: key) }
        saveShared()
    }

    // MARK: - Trophies

    private func countForTrophies(_ rec: MatchRecord, newLevel: Int?) {
        trophies.record(outcome: rec.outcome, fighterName: rec.fighterName,
                        archetype: rec.fighterArchetype, habitat: rec.fighterType, level: rec.level,
                        oppName: rec.oppName, oppLevel: rec.oppLevel ?? rec.level,
                        oppSpeciesID: rec.oppSpeciesID, newLevel: newLevel, at: rec.date)
    }

    /// Count matches played before trophies existed (from History, plus the
    /// team's current levels), once.
    private func backfillTrophies(_ all: [Catch]) {
        guard !trophies.backfilled else { return }
        for rec in history.reversed() { countForTrophies(rec, newLevel: nil) }
        let best = teamCatches(from: all).map(\.progress.level).max() ?? 1
        if best > trophies.bestLevel { trophies.bestLevel = best }
        trophies.award(at: .now)
        trophies.unseen = [] // old news; no "New" tags for these
        trophies.backfilled = true
        saveShared()
    }

    /// The Trophies tab was seen: clear the "New" tags.
    func markTrophiesSeen() {
        guard !trophies.unseen.isEmpty else { return }
        trophies.unseen = []
        saveShared()
    }

    var hasUnseenTrophies: Bool { !trophies.unseen.isEmpty }

    #if DEBUG
    /// Dev: a few days' worth of trophy progress, with one just earned.
    func devSampleTrophies() {
        var t = TrophyLedger()
        let day: TimeInterval = 86_400
        t.matches = 12; t.wins = 8; t.streak = 2; t.bestStreak = 2
        t.rivals = Set(CreatureCatalog.all.prefix(9).map(\.id))
        t.archetypes = ["trickster", "wall", "skirmisher"]
        t.habitats = ["timber", "tide", "bloom"]
        t.bestLevel = 10
        t.giantSlain = true
        t.earned = [Trophy.firstWin.rawValue: .now - 6 * day,
                    Trophy.giantSlayer.rawValue: .now - 2 * day,
                    Trophy.seasoned.rawValue: .now - 600]
        t.notes = [Trophy.giantSlayer.rawValue: "vs Wild Badger", Trophy.seasoned.rawValue: "Ember"]
        t.unseen = [Trophy.seasoned.rawValue]
        t.backfilled = true
        trophies = t
        saveShared()
    }
    #endif

    // MARK: - XP & leveling

    static func xpNeeded(for level: Int) -> Int { 60 + (level - 1) * 40 }
    static let maxLevel = 30

    private func award(_ s: inout FriendState, _ outcome: MatchOutcome) {
        guard var p = s.progress else { return }
        p.xp += outcome.xp
        while p.level < Self.maxLevel && p.xp >= Self.xpNeeded(for: p.level) {
            p.xp -= Self.xpNeeded(for: p.level)
            p.level += 1
        }
        s.progress = p
    }

    // MARK: - Battle plans

    func storedPlan(for c: Catch, archetype: Archetype) -> StoredPlan {
        state(c).plan ?? StoredPlan(.defaultPlan(for: archetype))
    }
    func setPlan(_ plan: StoredPlan, for c: Catch) {
        update(c) { $0.plan = plan }
    }
    func battlePlan(for c: Catch, archetype: Archetype) -> BattlePlan {
        storedPlan(for: c, archetype: archetype).battlePlan
    }

    // MARK: - Setup

    /// Call when the Arena opens: moves pre-sync data onto friends (once),
    /// then lands any matches that finished while you were away.
    func prepare(with all: [Catch]) {
        migrateLegacy(all)
        backfillTrophies(all)
        settleDueMatches(from: all)
    }

    // MARK: - Persistence (team + history)

    private func loadShared() {
        guard !isSaving else { return }
        let newTeam = defaults.stringArray(forKey: Self.teamKey) ?? []
        let newHistory = defaults.data(forKey: Self.historyKey)
            .flatMap { try? JSONDecoder().decode([MatchRecord].self, from: $0) } ?? []
        let newTrophies = defaults.data(forKey: Self.trophiesKey)
            .flatMap { try? JSONDecoder().decode(TrophyLedger.self, from: $0) } ?? TrophyLedger()
        if newTeam != team { team = newTeam }
        let deduped = Self.unique(newHistory)
        if deduped != history { history = deduped }
        if newTrophies != trophies { trophies = newTrophies }
    }

    /// One entry per match: the same match can arrive twice (e.g. old data
    /// upgraded on two devices, then merged through iCloud).
    private static func unique(_ records: [MatchRecord]) -> [MatchRecord] {
        var seen = Set<UUID>()
        return records.filter { seen.insert($0.id).inserted }
    }

    private func saveShared() {
        isSaving = true
        defer { isSaving = false }
        defaults.set(team, forKey: Self.teamKey)
        defaults.set(try? JSONEncoder().encode(history), forKey: Self.historyKey)
        defaults.set(try? JSONEncoder().encode(trophies), forKey: Self.trophiesKey)
    }

    // MARK: - Legacy (pre-sync) data

    private struct LegacyPending: Codable {
        var seed: UInt64; var level: Int; var plan: StoredPlan
        var oppName: String; var oppType: BattleType; var oppArchetype: Archetype
        var hpFraction: Double; var won: Bool; var resolvesAt: Date
        var settled: Bool; var watched: Bool
    }
    private struct LegacyRecord: Codable {
        var id: UUID; var date: Date; var fighterKey: String; var fighterName: String
        var fighterType: BattleType; var fighterArchetype: Archetype; var level: Int
        var plan: StoredPlan; var oppName: String; var oppType: BattleType
        var oppArchetype: Archetype; var seed: UInt64; var won: Bool
    }
    private struct LegacyBlob: Codable {
        var team: [String]
        var progress: [String: Progress]
        var plans: [String: StoredPlan]?
        var pending: [String: LegacyPending]?
        var history: [LegacyRecord]?
    }

    /// The old per-device key: the bits of a catch's date and coordinates.
    private func legacyKey(for c: Catch) -> String {
        let t = c.caughtAt.timeIntervalSinceReferenceDate.bitPattern
        let la = (c.latitude ?? 0).bitPattern
        let lo = (c.longitude ?? 0).bitPattern
        return "\(t)-\(la)-\(lo)"
    }

    private func migrateLegacy(_ all: [Catch]) {
        guard !all.isEmpty, let data = defaults.data(forKey: legacyKey),
              let blob = try? JSONDecoder().decode(LegacyBlob.self, from: data) else { return }
        var newID: [String: String] = [:]
        for c in all {
            let old = legacyKey(for: c)
            guard blob.progress[old] != nil || blob.plans?[old] != nil || blob.pending?[old] != nil else { continue }
            let id = ensureID(c)
            newID[old] = id
            let me = Contender.from(c)
            var s = state(c)
            s.progress = s.progress ?? blob.progress[old]
            s.plan = s.plan ?? blob.plans?[old]
            if s.pending == nil, let lp = blob.pending?[old] {
                s.pending = PendingMatch(seed: lp.seed, level: lp.level, plan: lp.plan,
                                         fighter: FighterSnapshot(name: me.name, type: me.type, archetype: me.archetype),
                                         oppName: lp.oppName, oppType: lp.oppType, oppArchetype: lp.oppArchetype,
                                         hpFraction: lp.hpFraction, outcome: lp.won ? .win : .loss,
                                         resolvesAt: lp.resolvesAt, settled: lp.settled, watched: lp.watched)
            }
            setState(s, for: c)
        }
        for old in blob.team { if let id = newID[old], !team.contains(id), team.count < maxSlots { team.append(id) } }
        let oldRecords = (blob.history ?? []).compactMap { r -> MatchRecord? in
            guard let id = newID[r.fighterKey] else { return nil }
            return MatchRecord(id: r.id, date: r.date, fighterKey: id, fighterName: r.fighterName,
                               fighterType: r.fighterType, fighterArchetype: r.fighterArchetype, level: r.level,
                               plan: r.plan, oppName: r.oppName, oppType: r.oppType, oppArchetype: r.oppArchetype,
                               seed: r.seed, outcome: r.won ? .win : .loss)
        }
        history = Array(Self.unique(history + oldRecords).sorted { $0.date > $1.date }.prefix(Self.historyLimit))
        saveShared()
        defaults.removeObject(forKey: legacyKey)
    }
}
