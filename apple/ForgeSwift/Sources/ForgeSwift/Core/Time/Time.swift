//
//  Time.swift
//  ForgeSwift
//
//  Time primitives: Duration, Time, Date, Timestamp.
//

import Foundation

// MARK: - Constants

public enum TimeConstants {
    public static let millisecondsInSecond: Double = 1_000
    public static let secondsInMinute: Double = 60
    public static let minutesInHour: Double = 60
    public static let hoursInDay: Double = 24
    public static let daysInWeek: Double = 7
    public static let daysInMonth: Double = 30
    public static let daysInYear: Double = 365
    public static let yearsInDecade: Double = 10
    public static let yearsInCentury: Double = 100
    public static let yearsInMillennium: Double = 1_000

    public static let secondsInHour = secondsInMinute * minutesInHour
    public static let secondsInDay = secondsInHour * hoursInDay
    public static let secondsInWeek = secondsInDay * daysInWeek
    public static let secondsInMonth = secondsInDay * daysInMonth
    public static let secondsInYear = secondsInDay * daysInYear
    public static let secondsInDecade = secondsInYear * yearsInDecade
    public static let secondsInCentury = secondsInYear * yearsInCentury
    public static let secondsInMillennium = secondsInYear * yearsInMillennium
}

private typealias C = TimeConstants

// MARK: - Duration

/// A span of time, stored as seconds.
///
///     let timeout = Duration.seconds(30)
///     let animation = Duration.seconds(0.35)
///     let week = Duration.weeks(1)
///
///     week.days      // 0 (component — remainder after extracting weeks)
///     week.inDays    // 7.0 (total conversion)
public struct Duration: Comparable, Sendable, Hashable {
    public let seconds: Double

    public init(_ seconds: Double) {
        self.seconds = seconds
    }

    /// Construct from named components. All values are additive.
    ///
    ///     Duration(hours: 1, minutes: 30)          // 5400s
    ///     Duration(days: 1, hours: 6)               // 108000s
    ///     Duration(years: 1, months: 2, days: 15)   // ~...s
    public init(
        millennia: Double = 0,
        centuries: Double = 0,
        decades: Double = 0,
        years: Double = 0,
        months: Double = 0,
        weeks: Double = 0,
        days: Double = 0,
        hours: Double = 0,
        minutes: Double = 0,
        seconds: Double = 0
    ) {
        self.seconds = millennia * C.secondsInMillennium
            + centuries * C.secondsInCentury
            + decades * C.secondsInDecade
            + years * C.secondsInYear
            + months * C.secondsInMonth
            + weeks * C.secondsInWeek
            + days * C.secondsInDay
            + hours * C.secondsInHour
            + minutes * C.secondsInMinute
            + seconds
    }

    // MARK: Constructors

    public static let zero = Duration(0)

    public static func seconds(_ s: Double) -> Duration { Duration(s) }
    public static func minutes(_ m: Double) -> Duration { Duration(m * C.secondsInMinute) }
    public static func hours(_ h: Double) -> Duration { Duration(h * C.secondsInHour) }
    public static func days(_ d: Double) -> Duration { Duration(d * C.secondsInDay) }
    public static func weeks(_ w: Double) -> Duration { Duration(w * C.secondsInWeek) }
    public static func months(_ m: Double) -> Duration { Duration(m * C.secondsInMonth) }
    public static func years(_ y: Double) -> Duration { Duration(y * C.secondsInYear) }
    public static func decades(_ d: Double) -> Duration { Duration(d * C.secondsInDecade) }
    public static func centuries(_ c: Double) -> Duration { Duration(c * C.secondsInCentury) }
    public static func millennia(_ m: Double) -> Duration { Duration(m * C.secondsInMillennium) }

    // MARK: Total conversions

    public var inMilliseconds: Double { seconds * C.millisecondsInSecond }
    public var inSeconds: Double { seconds }
    public var inMinutes: Double { seconds / C.secondsInMinute }
    public var inHours: Double { seconds / C.secondsInHour }
    public var inDays: Double { seconds / C.secondsInDay }
    public var inWeeks: Double { seconds / C.secondsInWeek }
    public var inMonths: Double { seconds / C.secondsInMonth }
    public var inYears: Double { seconds / C.secondsInYear }

    // MARK: Component extraction (modulo)

    /// Milliseconds remainder (0..<1000).
    public var milliseconds: Int {
        Int(seconds.truncatingRemainder(dividingBy: 1) * C.millisecondsInSecond)
    }

    /// Seconds remainder (0..<60).
    public var secs: Int {
        Int(seconds.truncatingRemainder(dividingBy: C.secondsInMinute))
    }

    /// Minutes remainder (0..<60).
    public var mins: Int {
        Int(inMinutes.truncatingRemainder(dividingBy: C.minutesInHour))
    }

    /// Hours remainder (0..<24).
    public var hrs: Int {
        Int(inHours.truncatingRemainder(dividingBy: C.hoursInDay))
    }

    /// Days remainder (0..<7).
    public var days: Int {
        Int(inDays.truncatingRemainder(dividingBy: C.daysInWeek))
    }

    /// Whole weeks.
    public var weeks: Int {
        Int(inWeeks)
    }

    // MARK: Formatting

    /// Format using tokens: `y` year, `M` month, `w` week, `d` day,
    /// `h` hour, `m` minute, `s` second, `S` millisecond.
    /// Repeat for padding: `hh:mm:ss` → `01:30:05`.
    /// Literal text in single quotes: `h'h' m'm'` → `1h 30m`.
    ///
    ///     Duration(hours: 1, minutes: 5).format("h:mm")       // "1:05"
    ///     Duration(minutes: 90).format("h'h' m'm'")           // "1h 30m"
    ///     Duration(seconds: 61.5).format("m:ss.SSS")           // "1:01.500"
    public func format(_ pattern: String) -> String {
        var result = ""
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let ch = pattern[i]
            if ch == "'" {
                // Literal text between quotes
                let next = pattern.index(after: i)
                if let closing = pattern[next...].firstIndex(of: "'") {
                    result += pattern[next..<closing]
                    i = pattern.index(after: closing)
                } else {
                    result += pattern[next...]
                    break
                }
            } else if let token = FormatToken(rawValue: ch) {
                // Count consecutive identical chars
                var count = 1
                var j = pattern.index(after: i)
                while j < pattern.endIndex && pattern[j] == ch {
                    count += 1
                    j = pattern.index(after: j)
                }
                result += token.resolve(from: self, width: count)
                i = j
            } else {
                result += String(ch)
                i = pattern.index(after: i)
            }
        }
        return result
    }

    private enum FormatToken: Character {
        case year = "y"
        case month = "M"
        case week = "w"
        case day = "d"
        case hour = "h"
        case minute = "m"
        case second = "s"
        case millisecond = "S"

        func resolve(from d: Duration, width: Int) -> String {
            let value: Int
            switch self {
            case .year:        value = Int(d.inYears)
            case .month:       value = Int(d.inMonths.truncatingRemainder(dividingBy: 12))
            case .week:        value = d.weeks
            case .day:         value = d.days
            case .hour:        value = d.hrs
            case .minute:      value = d.mins
            case .second:      value = d.secs
            case .millisecond: value = d.milliseconds
            }
            let s = String(value)
            if s.count >= width { return s }
            return String(repeating: "0", count: width - s.count) + s
        }
    }

    // MARK: Operators

    public static func + (lhs: Duration, rhs: Duration) -> Duration {
        Duration(lhs.seconds + rhs.seconds)
    }

    public static func - (lhs: Duration, rhs: Duration) -> Duration {
        Duration(lhs.seconds - rhs.seconds)
    }

    public static func * (lhs: Duration, rhs: Double) -> Duration {
        Duration(lhs.seconds * rhs)
    }

    public static func * (lhs: Double, rhs: Duration) -> Duration {
        Duration(lhs * rhs.seconds)
    }

    public static func / (lhs: Duration, rhs: Double) -> Duration {
        Duration(lhs.seconds / rhs)
    }

    public static func / (lhs: Duration, rhs: Duration) -> Double {
        lhs.seconds / rhs.seconds
    }

    public static func < (lhs: Duration, rhs: Duration) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

// MARK: - PartOfDay

public enum PartOfDay: String, Sendable, CaseIterable {
    case morning
    case noon
    case afternoon
    case evening
    case night
}

// MARK: - Time

/// Time of day — hours, minutes, seconds. No date, no timezone.
///
///     let t = Time(hour: 14, minute: 30)
///     t.format("h:mm a")       // "2:30 PM"
///     t.format("HH:mm:ss")     // "14:30:00"
///     t.partOfDay               // .afternoon
///     t.adding(.hours(2))       // Time(16, 30, 0)
///     Time(hour: 23).adding(.hours(3))  // Time(2, 0, 0) — wraps
public struct Time: Comparable, Sendable, Hashable {
    public let hour: Int
    public let minute: Int
    public let second: Int

    // MARK: Constructors

    public init(hour: Int = 0, minute: Int = 0, second: Int = 0) {
        let totalSeconds = hour * Int(C.secondsInHour)
            + minute * Int(C.secondsInMinute)
            + second
        let wrapped = ((totalSeconds % Int(C.secondsInDay)) + Int(C.secondsInDay)) % Int(C.secondsInDay)
        self.hour = wrapped / Int(C.secondsInHour)
        self.minute = (wrapped % Int(C.secondsInHour)) / Int(C.secondsInMinute)
        self.second = wrapped % Int(C.secondsInMinute)
    }

    public static var now: Time {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: Foundation.Date())
        return Time(hour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0)
    }

    // MARK: Conversions

    /// Duration elapsed since midnight.
    public var sinceStartOfDay: Duration {
        Duration(
            hours: Double(hour),
            minutes: Double(minute),
            seconds: Double(second)
        )
    }

    /// Construct from a duration since midnight. Wraps on overflow.
    public init(fromStartOfDay duration: Duration) {
        let secs = Int(duration.seconds)
        let wrapped = ((secs % Int(C.secondsInDay)) + Int(C.secondsInDay)) % Int(C.secondsInDay)
        self.hour = wrapped / Int(C.secondsInHour)
        self.minute = (wrapped % Int(C.secondsInHour)) / Int(C.secondsInMinute)
        self.second = wrapped % Int(C.secondsInMinute)
    }

    // MARK: Properties

    public var partOfDay: PartOfDay {
        switch hour {
        case 6..<12:  .morning
        case 12..<13: .noon
        case 13..<17: .afternoon
        case 17..<22: .evening
        default:      .night
        }
    }

    /// Whether the hour is before noon.
    public var isAM: Bool { hour < 12 }

    /// Hour in 12-hour format (1...12).
    public var hour12: Int {
        let h = hour % 12
        return h == 0 ? 12 : h
    }

    // MARK: Arithmetic

    public func adding(_ duration: Duration) -> Time {
        Time(fromStartOfDay: sinceStartOfDay + duration)
    }

    public func subtracting(_ duration: Duration) -> Time {
        Time(fromStartOfDay: sinceStartOfDay - duration)
    }

    public static func + (lhs: Time, rhs: Duration) -> Time {
        lhs.adding(rhs)
    }

    public static func - (lhs: Time, rhs: Duration) -> Time {
        lhs.subtracting(rhs)
    }

    /// Duration between two times (always positive, shortest path).
    public static func - (lhs: Time, rhs: Time) -> Duration {
        let diff = lhs.sinceStartOfDay.seconds - rhs.sinceStartOfDay.seconds
        let wrapped = ((diff.truncatingRemainder(dividingBy: C.secondsInDay)) + C.secondsInDay)
            .truncatingRemainder(dividingBy: C.secondsInDay)
        return Duration(min(wrapped, C.secondsInDay - wrapped))
    }

    // MARK: Formatting

    /// Format using tokens:
    /// - `H` / `HH`: hour 0-23 / 00-23
    /// - `h` / `hh`: hour 1-12 / 01-12
    /// - `m` / `mm`: minute 0-59 / 00-59
    /// - `s` / `ss`: second 0-59 / 00-59
    /// - `a`: AM/PM
    /// - Literal text in single quotes: `h:mm 'o''clock'`
    ///
    ///     Time(hour: 14, minute: 5).format("h:mm a")   // "2:05 PM"
    ///     Time(hour: 9, minute: 0).format("HH:mm")     // "09:00"
    public func format(_ pattern: String) -> String {
        var result = ""
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let ch = pattern[i]
            if ch == "'" {
                let next = pattern.index(after: i)
                if let closing = pattern[next...].firstIndex(of: "'") {
                    result += pattern[next..<closing]
                    i = pattern.index(after: closing)
                } else {
                    result += pattern[next...]
                    break
                }
            } else if ch == "a" {
                result += isAM ? "AM" : "PM"
                i = pattern.index(after: i)
            } else if let token = TimeFormatToken(rawValue: ch) {
                var count = 1
                var j = pattern.index(after: i)
                while j < pattern.endIndex && pattern[j] == ch {
                    count += 1
                    j = pattern.index(after: j)
                }
                result += token.resolve(from: self, width: count)
                i = j
            } else {
                result += String(ch)
                i = pattern.index(after: i)
            }
        }
        return result
    }

    private enum TimeFormatToken: Character {
        case hour24 = "H"
        case hour12 = "h"
        case minute = "m"
        case second = "s"

        func resolve(from t: Time, width: Int) -> String {
            let value: Int
            switch self {
            case .hour24: value = t.hour
            case .hour12: value = t.hour12
            case .minute: value = t.minute
            case .second: value = t.second
            }
            let s = String(value)
            if s.count >= width { return s }
            return String(repeating: "0", count: width - s.count) + s
        }
    }

    // MARK: Comparable

    public static func < (lhs: Time, rhs: Time) -> Bool {
        lhs.sinceStartOfDay.seconds < rhs.sinceStartOfDay.seconds
    }
}

// MARK: - TimeComponent

public enum TimeComponent: Sendable, CaseIterable {
    case millisecond
    case second
    case minute
    case hour
    case day
    case week
    case month
    case year

    var calendarComponent: Calendar.Component {
        switch self {
        case .millisecond: .nanosecond
        case .second:      .second
        case .minute:      .minute
        case .hour:        .hour
        case .day:         .day
        case .week:        .weekOfYear
        case .month:       .month
        case .year:        .year
        }
    }

    /// Multiplier for millisecond → nanosecond conversion.
    var calendarMultiplier: Int {
        self == .millisecond ? 1_000_000 : 1
    }
}

// MARK: - FoundationDate alias

public typealias FoundationDate = Foundation.Date

// MARK: - Date

/// Calendar date — year, month, day. No time, no timezone.
///
///     let d = Date(year: 2026, month: 4, day: 19)
///     d.weekday           // locale-aware day index
///     d.isWeekend         // true/false
///     d.startOfMonth      // Date(2026, 4, 1)
///     d.at(Time(hour: 14, minute: 30))  // → Timestamp
///     d.format("dd MMM yyyy")           // "19 Apr 2026"
public struct Date: Comparable, Sendable, Hashable {
    public let year: Int
    public let month: Int
    public let day: Int

    private var calendar: Calendar { Calendar.current }

    // MARK: Constructors

    public init(year: Int, month: Int = 1, day: Int = 1) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static var today: Date {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: FoundationDate())
        return Date(year: comps.year!, month: comps.month!, day: comps.day!)
    }

    init(from foundation: FoundationDate) {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: foundation)
        self.year = comps.year!
        self.month = comps.month!
        self.day = comps.day!
    }

    // MARK: Derived

    public var weekday: Int {
        var idx = calendar.component(.weekday, from: foundationDate) - calendar.firstWeekday
        if idx < 0 { idx += 7 }
        return idx
    }

    public var isWeekend: Bool {
        calendar.isDateInWeekend(foundationDate)
    }

    public var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: foundationDate)!.count
    }

    // MARK: Boundaries

    public var startOfWeek: Date {
        Date(from: calendar.startOfDay(for: foundationDate))
            .subtracting(weekday, .day)
    }

    public var startOfMonth: Date {
        Date(year: year, month: month, day: 1)
    }

    public var startOfYear: Date {
        Date(year: year, month: 1, day: 1)
    }

    // MARK: Expansion

    public var daysInWeek: [Date] {
        let start = startOfWeek
        return (0..<7).map { start.adding($0, .day) }
    }

    public var daysOfMonth: [Date] {
        let start = startOfMonth
        return (0..<daysInMonth).map { start.adding($0, .day) }
    }

    // MARK: Arithmetic

    public func adding(_ value: Int, _ component: TimeComponent) -> Date {
        let result = calendar.date(
            byAdding: component.calendarComponent,
            value: value * component.calendarMultiplier,
            to: foundationDate
        )!
        return Date(from: result)
    }

    public func subtracting(_ value: Int, _ component: TimeComponent) -> Date {
        adding(-value, component)
    }

    public static func + (lhs: Date, rhs: Duration) -> Date {
        Date(from: lhs.foundationDate.addingTimeInterval(rhs.seconds))
    }

    public static func - (lhs: Date, rhs: Duration) -> Date {
        Date(from: lhs.foundationDate.addingTimeInterval(-rhs.seconds))
    }

    public static func - (lhs: Date, rhs: Date) -> Duration {
        Duration(lhs.foundationDate.timeIntervalSince(rhs.foundationDate))
    }

    // MARK: Composition

    public func at(_ time: Time) -> Timestamp {
        Timestamp(
            year: year, month: month, day: day,
            hour: time.hour, minute: time.minute, second: time.second
        )
    }

    /// Timestamp at midnight.
    public var timestamp: Timestamp {
        at(Time())
    }

    // MARK: Formatting

    /// Format using pattern tokens:
    /// - `d` / `dd`: day 1-31 / 01-31
    /// - `M` / `MM`: month 1-12 / 01-12
    /// - `MMM`: abbreviated month name (Jan, Feb...)
    /// - `MMMM`: full month name (January, February...)
    /// - `yy` / `yyyy`: 2-digit / 4-digit year
    /// - `E` / `EEE`: abbreviated weekday (Mon, Tue...)
    /// - `EEEE`: full weekday (Monday, Tuesday...)
    /// - Literal text in single quotes.
    public func format(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: foundationDate)
    }

    // MARK: Comparable

    public static func < (lhs: Date, rhs: Date) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }

    // MARK: Internal

    var foundationDate: FoundationDate {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

// MARK: - Timestamp

/// A point in time — Unix seconds since epoch.
///
///     let ts = Timestamp.now
///     ts.date                    // Date projection
///     ts.time                    // Time projection
///     ts.format("dd MMM yyyy HH:mm")
///     ts.startOfDay              // midnight
///     ts.adding(1, .month)       // calendar-aware
///     ts + .hours(2)             // absolute
public struct Timestamp: Comparable, Sendable, Hashable {
    public let value: Double

    private var calendar: Calendar { Calendar.current }

    // MARK: Constructors

    public init(_ value: Double) {
        self.value = value
    }

    public init(_ foundation: FoundationDate) {
        self.value = foundation.timeIntervalSince1970
    }

    public init(
        year: Int, month: Int = 1, day: Int = 1,
        hour: Int = 0, minute: Int = 0, second: Int = 0
    ) {
        let comps = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second
        )
        self.value = Calendar.current.date(from: comps)!.timeIntervalSince1970
    }

    public static var now: Timestamp {
        Timestamp(FoundationDate())
    }

    // MARK: Component access

    public var year: Int { component(.year) }
    public var month: Int { component(.month) }
    public var day: Int { component(.day) }
    public var hour: Int { component(.hour) }
    public var minute: Int { component(.minute) }
    public var second: Int { component(.second) }

    public var weekday: Int {
        var idx = component(.weekday) - calendar.firstWeekday
        if idx < 0 { idx += 7 }
        return idx
    }

    public var isWeekend: Bool {
        calendar.isDateInWeekend(foundationDate)
    }

    private func component(_ c: Calendar.Component) -> Int {
        calendar.component(c, from: foundationDate)
    }

    // MARK: Projections

    public var date: Date {
        Date(year: year, month: month, day: day)
    }

    public var time: Time {
        Time(hour: hour, minute: minute, second: second)
    }

    // MARK: Boundaries

    public var startOfMinute: Timestamp {
        Timestamp(year: year, month: month, day: day, hour: hour, minute: minute)
    }

    public var startOfHour: Timestamp {
        Timestamp(year: year, month: month, day: day, hour: hour)
    }

    public var startOfDay: Timestamp {
        Timestamp(calendar.startOfDay(for: foundationDate))
    }

    public var startOfWeek: Timestamp {
        startOfDay.subtracting(weekday, .day)
    }

    public var startOfMonth: Timestamp {
        Timestamp(year: year, month: month)
    }

    public var startOfYear: Timestamp {
        Timestamp(year: year)
    }

    public var endOfDay: Timestamp {
        startOfDay.adding(1, .day)
    }

    // MARK: Expansion

    public var daysInWeek: [Date] {
        date.daysInWeek
    }

    public var daysInMonth: [Date] {
        date.daysOfMonth
    }

    // MARK: With (replace components)

    public func with(
        year: Int? = nil, month: Int? = nil, day: Int? = nil,
        hour: Int? = nil, minute: Int? = nil, second: Int? = nil
    ) -> Timestamp {
        Timestamp(
            year: year ?? self.year,
            month: month ?? self.month,
            day: day ?? self.day,
            hour: hour ?? self.hour,
            minute: minute ?? self.minute,
            second: second ?? self.second
        )
    }

    // MARK: Arithmetic (calendar-aware)

    public func adding(_ value: Int, _ component: TimeComponent) -> Timestamp {
        let result = calendar.date(
            byAdding: component.calendarComponent,
            value: value * component.calendarMultiplier,
            to: foundationDate
        )!
        return Timestamp(result)
    }

    public func subtracting(_ value: Int, _ component: TimeComponent) -> Timestamp {
        adding(-value, component)
    }

    // Absolute duration arithmetic
    public static func + (lhs: Timestamp, rhs: Duration) -> Timestamp {
        Timestamp(lhs.value + rhs.seconds)
    }

    public static func - (lhs: Timestamp, rhs: Duration) -> Timestamp {
        Timestamp(lhs.value - rhs.seconds)
    }

    public static func - (lhs: Timestamp, rhs: Timestamp) -> Duration {
        Duration(lhs.value - rhs.value)
    }

    // MARK: Comparison helpers

    public func before(_ other: Timestamp) -> Bool { self < other }
    public func after(_ other: Timestamp) -> Bool { self > other }

    public func between(start: Timestamp, end: Timestamp) -> Bool {
        self > start && self < end
    }

    // MARK: Formatting

    /// Format using DateFormatter pattern tokens.
    /// Same tokens as Date plus time tokens from Time.
    public func format(_ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = pattern
        return formatter.string(from: foundationDate)
    }

    // MARK: Conversion

    public var foundationDate: FoundationDate {
        FoundationDate(timeIntervalSince1970: value)
    }

    // MARK: Comparable

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.value < rhs.value
    }
}
