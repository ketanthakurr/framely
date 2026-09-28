import Foundation

/// Decides which photo a widget shows at a given moment.
///
/// It's deterministic: the same set + time always gives the same photo, in the
/// app preview and in every widget. Shuffle uses a seeded permutation per cycle,
/// so every photo appears once before any repeats.
enum PhotoScheduler {
    /// Local-midnight reference day. Slots line up with the set's anchor time
    /// (e.g. 8:00 AM) and stay on the wall clock across DST changes.
    private static func epochDay(_ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 1_704_067_200)
    }

    /// Intervals that divide a day evenly (5m, 15m, 1h, 6h, 1d…) are computed per local day.
    private static func isDayAligned(_ s: RotationSchedule) -> Bool {
        s.minutes > 0 && s.minutes <= 1440 && 1440 % s.minutes == 0
    }

    static func slot(at date: Date, schedule s: RotationSchedule, calendar: Calendar = .current) -> Int {
        let m = max(1, s.minutes)
        let anchor = mod(s.anchorMinutes, 1440)
        let epoch = epochDay(calendar)
        if isDayAligned(s) {
            let perDay = 1440 / m
            let dayStart = calendar.startOfDay(for: date)
            let dayIndex = calendar.dateComponents([.day], from: epoch, to: dayStart).day ?? 0
            let minutesIntoDay = Int(floor(date.timeIntervalSince(dayStart) / 60))
            let within = floorDiv(minutesIntoDay - (anchor % m), m)
            return dayIndex * perDay + within
        }
        let start = epoch.addingTimeInterval(Double(anchor) * 60)
        return Int(floor(date.timeIntervalSince(start) / s.seconds))
    }

    static func slotStart(_ slot: Int, schedule s: RotationSchedule, calendar: Calendar = .current) -> Date {
        let m = max(1, s.minutes)
        let anchor = mod(s.anchorMinutes, 1440)
        let epoch = epochDay(calendar)
        if isDayAligned(s) {
            let perDay = 1440 / m
            let day = calendar.date(byAdding: .day, value: floorDiv(slot, perDay), to: epoch) ?? epoch
            let minutes = (anchor % m) + mod(slot, perDay) * m
            return calendar.date(byAdding: .minute, value: minutes, to: day) ?? day
        }
        return epoch.addingTimeInterval(Double(anchor) * 60 + Double(slot) * s.seconds)
    }

    /// The next time the photo changes after `date`.
    static func nextChange(after date: Date, schedule s: RotationSchedule) -> Date {
        slotStart(slot(at: date, schedule: s) + 1, schedule: s)
    }

    /// Photo index for a slot; `shift` lets different widgets of the same set
    /// (e.g. mosaic tiles) show different photos.
    static func index(for set: PhotoSet, slot: Int, shift: Int = 0) -> Int? {
        let n = set.photos.count
        guard n > 0 else { return nil }
        let position = slot + SharedStore.shared.manualOffset(for: set.id) + shift
        switch set.order {
        case .sequential:
            return mod(position, n)
        case .shuffle:
            let cycle = floorDiv(position, n)
            let perm = permutation(count: n, seed: seed(for: set.id) &+ UInt64(bitPattern: Int64(cycle)))
            return perm[mod(position, n)]
        }
    }

    static func photo(for set: PhotoSet, at date: Date, schedule: RotationSchedule, shift: Int = 0) -> PhotoItem? {
        guard let i = index(for: set, slot: slot(at: date, schedule: schedule), shift: shift) else { return nil }
        return set.photos[i]
    }

    /// Timeline dates for the next rotations, capped to keep the widget's timeline small.
    static func upcomingDates(from now: Date, schedule: RotationSchedule, maxEntries: Int = 144, horizon: TimeInterval = 24 * 3600) -> [Date] {
        var dates = [now]
        var s = slot(at: now, schedule: schedule) + 1
        while dates.count < maxEntries {
            let d = slotStart(s, schedule: schedule)
            if d.timeIntervalSince(now) > horizon { break }
            if d > now { dates.append(d) }
            s += 1
        }
        return dates
    }

    /// Photos taken on today's month/day in earlier years ("On this day").
    static func onThisDay(in sets: [PhotoSet], date: Date = .now, calendar: Calendar = .current) -> [PhotoItem] {
        let today = calendar.dateComponents([.month, .day, .year], from: date)
        return sets.flatMap(\.photos).filter { item in
            guard let captured = item.capturedAt else { return false }
            let c = calendar.dateComponents([.month, .day, .year], from: captured)
            return c.month == today.month && c.day == today.day && (c.year ?? 0) < (today.year ?? 0)
        }
    }

    // MARK: Math helpers

    private static func mod(_ a: Int, _ n: Int) -> Int { ((a % n) + n) % n }
    private static func floorDiv(_ a: Int, _ n: Int) -> Int { a >= 0 ? a / n : -((-a + n - 1) / n) }

    private static func seed(for id: UUID) -> UInt64 {
        let u = id.uuid
        return [u.0, u.1, u.2, u.3, u.4, u.5, u.6, u.7].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    private static func permutation(count: Int, seed: UInt64) -> [Int] {
        var rng = SplitMix64(seed: seed)
        var array = Array(0..<count)
        array.shuffle(using: &rng)
        return array
    }
}

/// Small, fast, deterministic RNG (stable across launches, unlike SystemRandomNumberGenerator).
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
