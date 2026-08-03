import Foundation

/// Pure daily-streak math. A "streak day" is any calendar day on which the
/// player caught at least one critter. The current streak counts consecutive
/// days ending today (or yesterday, so you don't lose it until a full day lapses).
enum StreakEngine {

    /// Distinct calendar days (as start-of-day dates) that have at least one catch.
    private static func streakDays(from dates: [Date], calendar: Calendar) -> Set<Date> {
        Set(dates.map { calendar.startOfDay(for: $0) })
    }

    /// Consecutive-day streak ending today or yesterday. Returns 0 if the most
    /// recent catch is older than yesterday.
    static func currentStreak(
        from dates: [Date],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> Int {
        let days = streakDays(from: dates, calendar: calendar)
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // The streak is only "alive" if there's a catch today or yesterday.
        var cursor: Date
        if days.contains(today) {
            cursor = today
        } else if days.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var count = 0
        while days.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// The longest consecutive-day run ever achieved.
    static func longestStreak(from dates: [Date], calendar: Calendar = .current) -> Int {
        let days = streakDays(from: dates, calendar: calendar).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var run = 1
        for i in 1..<days.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(expected, inSameDayAs: days[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }
}
