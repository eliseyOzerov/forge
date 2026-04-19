import XCTest
@testable import ForgeSwift

final class TimeTests: XCTestCase {

    // MARK: - Duration: Constructors

    func testDurationSeconds() {
        XCTAssertEqual(Duration.seconds(30).seconds, 30)
    }

    func testDurationMinutes() {
        XCTAssertEqual(Duration.minutes(2).seconds, 120)
    }

    func testDurationHours() {
        XCTAssertEqual(Duration.hours(1).seconds, 3600)
    }

    func testDurationDays() {
        XCTAssertEqual(Duration.days(1).seconds, 86400)
    }

    func testDurationWeeks() {
        XCTAssertEqual(Duration.weeks(1).seconds, 604800)
    }

    func testDurationMonths() {
        XCTAssertEqual(Duration.months(1).seconds, 30 * 86400)
    }

    func testDurationYears() {
        XCTAssertEqual(Duration.years(1).seconds, 365 * 86400)
    }

    func testDurationZero() {
        XCTAssertEqual(Duration.zero.seconds, 0)
    }

    func testDurationNamedInit() {
        let d = Duration(hours: 1, minutes: 30)
        XCTAssertEqual(d.seconds, 5400)
    }

    func testDurationNamedInitMultiple() {
        let d = Duration(days: 1, hours: 2, minutes: 30, seconds: 15)
        XCTAssertEqual(d.seconds, 86400 + 7200 + 1800 + 15)
    }

    // MARK: - Duration: Total conversions

    func testInMinutes() {
        XCTAssertEqual(Duration.seconds(90).inMinutes, 1.5)
    }

    func testInHours() {
        XCTAssertEqual(Duration.minutes(90).inHours, 1.5)
    }

    func testInDays() {
        XCTAssertEqual(Duration.hours(36).inDays, 1.5)
    }

    func testInWeeks() {
        XCTAssertEqual(Duration.days(14).inWeeks, 2)
    }

    func testInMilliseconds() {
        XCTAssertEqual(Duration.seconds(1.5).inMilliseconds, 1500)
    }

    // MARK: - Duration: Component extraction

    func testComponentSeconds() {
        let d = Duration(minutes: 2, seconds: 35)
        XCTAssertEqual(d.secs, 35)
    }

    func testComponentMinutes() {
        let d = Duration(hours: 1, minutes: 45)
        XCTAssertEqual(d.mins, 45)
    }

    func testComponentHours() {
        let d = Duration(days: 1, hours: 5)
        XCTAssertEqual(d.hrs, 5)
    }

    func testComponentDays() {
        let d = Duration(weeks: 1, days: 3)
        XCTAssertEqual(d.days, 3)
    }

    func testComponentWeeks() {
        let d = Duration.weeks(3)
        XCTAssertEqual(d.weeks, 3)
    }

    func testComponentMilliseconds() {
        let d = Duration(1.234)
        XCTAssertEqual(d.milliseconds, 234)
    }

    // MARK: - Duration: Operators

    func testDurationAdd() {
        let result = Duration.seconds(10) + Duration.seconds(20)
        XCTAssertEqual(result.seconds, 30)
    }

    func testDurationSubtract() {
        let result = Duration.minutes(5) - Duration.minutes(2)
        XCTAssertEqual(result.seconds, 180)
    }

    func testDurationMultiply() {
        let result = Duration.seconds(10) * 3
        XCTAssertEqual(result.seconds, 30)
    }

    func testDurationMultiplyReversed() {
        let result = 3 * Duration.seconds(10)
        XCTAssertEqual(result.seconds, 30)
    }

    func testDurationDivideByScalar() {
        let result = Duration.seconds(30) / 3
        XCTAssertEqual(result.seconds, 10)
    }

    func testDurationDivideByDuration() {
        let result = Duration.hours(1) / Duration.minutes(30)
        XCTAssertEqual(result, 2)
    }

    func testDurationComparable() {
        XCTAssertTrue(Duration.seconds(1) < Duration.seconds(2))
        XCTAssertFalse(Duration.seconds(2) < Duration.seconds(1))
    }

    // MARK: - Duration: Formatting

    func testDurationFormatHoursMinutes() {
        let d = Duration(hours: 1, minutes: 5)
        XCTAssertEqual(d.format("h:mm"), "1:05")
    }

    func testDurationFormatWithLiterals() {
        let d = Duration(hours: 2, minutes: 30)
        XCTAssertEqual(d.format("h'h' m'm'"), "2h 30m")
    }

    func testDurationFormatSecondsMilliseconds() {
        let d = Duration(61.5)
        XCTAssertEqual(d.format("m:ss.SSS"), "1:01.500")
    }

    func testDurationFormatPadded() {
        let d = Duration(hours: 1, minutes: 5, seconds: 3)
        XCTAssertEqual(d.format("hh:mm:ss"), "01:05:03")
    }

    // MARK: - Time: Constructors

    func testTimeInit() {
        let t = Time(hour: 14, minute: 30, second: 45)
        XCTAssertEqual(t.hour, 14)
        XCTAssertEqual(t.minute, 30)
        XCTAssertEqual(t.second, 45)
    }

    func testTimeInitDefaults() {
        let t = Time(hour: 9)
        XCTAssertEqual(t.hour, 9)
        XCTAssertEqual(t.minute, 0)
        XCTAssertEqual(t.second, 0)
    }

    func testTimeInitWrapsOverflow() {
        let t = Time(hour: 25, minute: 0)
        XCTAssertEqual(t.hour, 1)
    }

    func testTimeInitWrapsNegative() {
        let t = Time(hour: -1)
        XCTAssertEqual(t.hour, 23)
    }

    func testTimeFromDuration() {
        let t = Time(fromStartOfDay: .hours(14.5))
        XCTAssertEqual(t.hour, 14)
        XCTAssertEqual(t.minute, 30)
        XCTAssertEqual(t.second, 0)
    }

    func testTimeNow() {
        let t = Time.now
        XCTAssertTrue(t.hour >= 0 && t.hour < 24)
        XCTAssertTrue(t.minute >= 0 && t.minute < 60)
    }

    // MARK: - Time: Properties

    func testTimeSinceStartOfDay() {
        let t = Time(hour: 1, minute: 30)
        XCTAssertEqual(t.sinceStartOfDay.seconds, 5400)
    }

    func testTimePartOfDayMorning() {
        XCTAssertEqual(Time(hour: 8).partOfDay, .morning)
    }

    func testTimePartOfDayNoon() {
        XCTAssertEqual(Time(hour: 12).partOfDay, .noon)
    }

    func testTimePartOfDayAfternoon() {
        XCTAssertEqual(Time(hour: 15).partOfDay, .afternoon)
    }

    func testTimePartOfDayEvening() {
        XCTAssertEqual(Time(hour: 20).partOfDay, .evening)
    }

    func testTimePartOfDayNight() {
        XCTAssertEqual(Time(hour: 2).partOfDay, .night)
    }

    func testTimeIsAM() {
        XCTAssertTrue(Time(hour: 11).isAM)
        XCTAssertFalse(Time(hour: 12).isAM)
        XCTAssertFalse(Time(hour: 15).isAM)
    }

    func testTimeHour12() {
        XCTAssertEqual(Time(hour: 0).hour12, 12)
        XCTAssertEqual(Time(hour: 1).hour12, 1)
        XCTAssertEqual(Time(hour: 12).hour12, 12)
        XCTAssertEqual(Time(hour: 13).hour12, 1)
        XCTAssertEqual(Time(hour: 23).hour12, 11)
    }

    // MARK: - Time: Arithmetic

    func testTimeAddDuration() {
        let t = Time(hour: 10) + .hours(3)
        XCTAssertEqual(t.hour, 13)
    }

    func testTimeAddWraps() {
        let t = Time(hour: 23) + .hours(3)
        XCTAssertEqual(t.hour, 2)
    }

    func testTimeSubtractDuration() {
        let t = Time(hour: 10) - .hours(3)
        XCTAssertEqual(t.hour, 7)
    }

    func testTimeSubtractWraps() {
        let t = Time(hour: 1) - .hours(3)
        XCTAssertEqual(t.hour, 22)
    }

    func testTimeDifference() {
        let diff = Time(hour: 14) - Time(hour: 10)
        XCTAssertEqual(diff.seconds, 4 * 3600)
    }

    func testTimeDifferenceShortestPath() {
        let diff = Time(hour: 1) - Time(hour: 23)
        XCTAssertEqual(diff.seconds, 2 * 3600)
    }

    // MARK: - Time: Formatting

    func testTimeFormat24h() {
        let t = Time(hour: 9, minute: 5, second: 3)
        XCTAssertEqual(t.format("HH:mm:ss"), "09:05:03")
    }

    func testTimeFormat12h() {
        let t = Time(hour: 14, minute: 30)
        XCTAssertEqual(t.format("h:mm a"), "2:30 PM")
    }

    func testTimeFormatAM() {
        let t = Time(hour: 9, minute: 15)
        XCTAssertEqual(t.format("h:mm a"), "9:15 AM")
    }

    func testTimeFormatMidnight() {
        let t = Time(hour: 0, minute: 0)
        XCTAssertEqual(t.format("h:mm a"), "12:00 AM")
    }

    // MARK: - Time: Comparable

    func testTimeComparable() {
        XCTAssertTrue(Time(hour: 9) < Time(hour: 10))
        XCTAssertTrue(Time(hour: 9, minute: 30) < Time(hour: 9, minute: 45))
        XCTAssertFalse(Time(hour: 10) < Time(hour: 9))
    }

    // MARK: - Date: Constructors

    func testDateInit() {
        let d = Date(year: 2026, month: 4, day: 19)
        XCTAssertEqual(d.year, 2026)
        XCTAssertEqual(d.month, 4)
        XCTAssertEqual(d.day, 19)
    }

    func testDateDefaults() {
        let d = Date(year: 2026)
        XCTAssertEqual(d.month, 1)
        XCTAssertEqual(d.day, 1)
    }

    func testDateToday() {
        let d = Date.today
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: FoundationDate())
        XCTAssertEqual(d.year, comps.year)
        XCTAssertEqual(d.month, comps.month)
        XCTAssertEqual(d.day, comps.day)
    }

    // MARK: - Date: Derived

    func testDateIsWeekend() {
        // 2026-04-19 is a Sunday
        let d = Date(year: 2026, month: 4, day: 19)
        XCTAssertTrue(d.isWeekend)
    }

    func testDateIsNotWeekend() {
        // 2026-04-20 is a Monday
        let d = Date(year: 2026, month: 4, day: 20)
        XCTAssertFalse(d.isWeekend)
    }

    func testDateDaysInMonth() {
        XCTAssertEqual(Date(year: 2026, month: 2).daysInMonth, 28)
        XCTAssertEqual(Date(year: 2024, month: 2).daysInMonth, 29) // leap year
        XCTAssertEqual(Date(year: 2026, month: 4).daysInMonth, 30)
        XCTAssertEqual(Date(year: 2026, month: 1).daysInMonth, 31)
    }

    // MARK: - Date: Boundaries

    func testDateStartOfMonth() {
        let d = Date(year: 2026, month: 4, day: 19).startOfMonth
        XCTAssertEqual(d.day, 1)
        XCTAssertEqual(d.month, 4)
    }

    func testDateStartOfYear() {
        let d = Date(year: 2026, month: 4, day: 19).startOfYear
        XCTAssertEqual(d.month, 1)
        XCTAssertEqual(d.day, 1)
    }

    func testDateStartOfWeek() {
        let d = Date(year: 2026, month: 4, day: 19) // Sunday
        let start = d.startOfWeek
        // startOfWeek should be 0..6 days before
        XCTAssertTrue(start <= d)
        let diff = d - start
        XCTAssertTrue(diff.inDays < 7)
    }

    // MARK: - Date: Expansion

    func testDateDaysInWeek() {
        let d = Date(year: 2026, month: 4, day: 19)
        let week = d.daysInWeek
        XCTAssertEqual(week.count, 7)
        // First day should be start of week
        XCTAssertEqual(week[0], d.startOfWeek)
    }

    func testDateDaysOfMonth() {
        let d = Date(year: 2026, month: 4)
        let days = d.daysOfMonth
        XCTAssertEqual(days.count, 30)
        XCTAssertEqual(days[0].day, 1)
        XCTAssertEqual(days[29].day, 30)
    }

    // MARK: - Date: Arithmetic

    func testDateAddingDays() {
        let d = Date(year: 2026, month: 4, day: 19).adding(5, .day)
        XCTAssertEqual(d.day, 24)
    }

    func testDateAddingMonths() {
        let d = Date(year: 2026, month: 1, day: 31).adding(1, .month)
        // Jan 31 + 1 month = Feb 28 (clamped by Calendar)
        XCTAssertEqual(d.month, 2)
        XCTAssertEqual(d.day, 28)
    }

    func testDateAddingYears() {
        let d = Date(year: 2026, month: 4, day: 19).adding(1, .year)
        XCTAssertEqual(d.year, 2027)
    }

    func testDateSubtracting() {
        let d = Date(year: 2026, month: 4, day: 19).subtracting(19, .day)
        XCTAssertEqual(d.day, 31)
        XCTAssertEqual(d.month, 3)
    }

    func testDatePlusDuration() {
        let d = Date(year: 2026, month: 4, day: 19) + .days(1)
        XCTAssertEqual(d.day, 20)
    }

    func testDateMinusDuration() {
        let d = Date(year: 2026, month: 4, day: 19) - .days(1)
        XCTAssertEqual(d.day, 18)
    }

    func testDateDifference() {
        let diff = Date(year: 2026, month: 4, day: 20) - Date(year: 2026, month: 4, day: 19)
        XCTAssertEqual(diff.inDays, 1, accuracy: 0.01)
    }

    // MARK: - Date: Composition

    func testDateAtTime() {
        let ts = Date(year: 2026, month: 4, day: 19).at(Time(hour: 14, minute: 30))
        XCTAssertEqual(ts.year, 2026)
        XCTAssertEqual(ts.month, 4)
        XCTAssertEqual(ts.day, 19)
        XCTAssertEqual(ts.hour, 14)
        XCTAssertEqual(ts.minute, 30)
    }

    func testDateTimestamp() {
        let ts = Date(year: 2026, month: 4, day: 19).timestamp
        XCTAssertEqual(ts.hour, 0)
        XCTAssertEqual(ts.minute, 0)
    }

    // MARK: - Date: Comparable

    func testDateComparable() {
        XCTAssertTrue(Date(year: 2026, month: 1) < Date(year: 2026, month: 2))
        XCTAssertTrue(Date(year: 2025) < Date(year: 2026))
        XCTAssertTrue(Date(year: 2026, month: 4, day: 1) < Date(year: 2026, month: 4, day: 2))
    }

    // MARK: - Timestamp: Constructors

    func testTimestampFromComponents() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14, minute: 30, second: 15)
        XCTAssertEqual(ts.year, 2026)
        XCTAssertEqual(ts.month, 4)
        XCTAssertEqual(ts.day, 19)
        XCTAssertEqual(ts.hour, 14)
        XCTAssertEqual(ts.minute, 30)
        XCTAssertEqual(ts.second, 15)
    }

    func testTimestampNow() {
        let ts = Timestamp.now
        XCTAssertTrue(ts.value > 0)
    }

    func testTimestampFromFoundation() {
        let fd = FoundationDate()
        let ts = Timestamp(fd)
        XCTAssertEqual(ts.value, fd.timeIntervalSince1970, accuracy: 0.001)
    }

    // MARK: - Timestamp: Projections

    func testTimestampDate() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14)
        let d = ts.date
        XCTAssertEqual(d.year, 2026)
        XCTAssertEqual(d.month, 4)
        XCTAssertEqual(d.day, 19)
    }

    func testTimestampTime() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14, minute: 30, second: 45)
        let t = ts.time
        XCTAssertEqual(t.hour, 14)
        XCTAssertEqual(t.minute, 30)
        XCTAssertEqual(t.second, 45)
    }

    // MARK: - Timestamp: Boundaries

    func testTimestampStartOfDay() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14, minute: 30)
        let start = ts.startOfDay
        XCTAssertEqual(start.hour, 0)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(start.second, 0)
        XCTAssertEqual(start.day, 19)
    }

    func testTimestampStartOfMonth() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14)
        let start = ts.startOfMonth
        XCTAssertEqual(start.day, 1)
        XCTAssertEqual(start.hour, 0)
    }

    func testTimestampStartOfYear() {
        let ts = Timestamp(year: 2026, month: 4, day: 19)
        let start = ts.startOfYear
        XCTAssertEqual(start.month, 1)
        XCTAssertEqual(start.day, 1)
    }

    func testTimestampStartOfHour() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14, minute: 30, second: 45)
        let start = ts.startOfHour
        XCTAssertEqual(start.hour, 14)
        XCTAssertEqual(start.minute, 0)
        XCTAssertEqual(start.second, 0)
    }

    func testTimestampEndOfDay() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14)
        let end = ts.endOfDay
        XCTAssertEqual(end.day, 20)
        XCTAssertEqual(end.hour, 0)
    }

    // MARK: - Timestamp: With

    func testTimestampWith() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 14, minute: 30)
        let modified = ts.with(hour: 9, minute: 0)
        XCTAssertEqual(modified.year, 2026)
        XCTAssertEqual(modified.month, 4)
        XCTAssertEqual(modified.day, 19)
        XCTAssertEqual(modified.hour, 9)
        XCTAssertEqual(modified.minute, 0)
    }

    // MARK: - Timestamp: Calendar arithmetic

    func testTimestampAddingMonth() {
        let ts = Timestamp(year: 2026, month: 1, day: 31).adding(1, .month)
        XCTAssertEqual(ts.month, 2)
        XCTAssertEqual(ts.day, 28) // clamped
    }

    func testTimestampAddingYear() {
        let ts = Timestamp(year: 2026, month: 4, day: 19).adding(1, .year)
        XCTAssertEqual(ts.year, 2027)
    }

    func testTimestampSubtractingDays() {
        let ts = Timestamp(year: 2026, month: 4, day: 19).subtracting(19, .day)
        XCTAssertEqual(ts.month, 3)
        XCTAssertEqual(ts.day, 31)
    }

    // MARK: - Timestamp: Duration arithmetic

    func testTimestampPlusDuration() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 10)
        let result = ts + .hours(5)
        XCTAssertEqual(result.hour, 15)
    }

    func testTimestampMinusDuration() {
        let ts = Timestamp(year: 2026, month: 4, day: 19, hour: 10)
        let result = ts - .hours(5)
        XCTAssertEqual(result.hour, 5)
    }

    func testTimestampDifference() {
        let a = Timestamp(year: 2026, month: 4, day: 20)
        let b = Timestamp(year: 2026, month: 4, day: 19)
        let diff = a - b
        XCTAssertEqual(diff.inDays, 1, accuracy: 0.01)
    }

    // MARK: - Timestamp: Comparison helpers

    func testTimestampBefore() {
        let a = Timestamp(year: 2026, month: 1)
        let b = Timestamp(year: 2026, month: 2)
        XCTAssertTrue(a.before(b))
        XCTAssertFalse(b.before(a))
    }

    func testTimestampAfter() {
        let a = Timestamp(year: 2026, month: 2)
        let b = Timestamp(year: 2026, month: 1)
        XCTAssertTrue(a.after(b))
    }

    func testTimestampBetween() {
        let a = Timestamp(year: 2026, month: 2)
        let start = Timestamp(year: 2026, month: 1)
        let end = Timestamp(year: 2026, month: 3)
        XCTAssertTrue(a.between(start: start, end: end))
        XCTAssertFalse(start.between(start: start, end: end))
    }

    // MARK: - Timestamp: Comparable

    func testTimestampComparable() {
        let a = Timestamp(year: 2026, month: 1)
        let b = Timestamp(year: 2026, month: 2)
        XCTAssertTrue(a < b)
    }

    // MARK: - Roundtrip: Date ↔ Timestamp ↔ Time

    func testRoundtripDateTimestamp() {
        let d = Date(year: 2026, month: 4, day: 19)
        let ts = d.timestamp
        XCTAssertEqual(ts.date, d)
    }

    func testRoundtripTimeTimestamp() {
        let t = Time(hour: 14, minute: 30, second: 45)
        let ts = Date(year: 2026, month: 1).at(t)
        XCTAssertEqual(ts.time, t)
    }

    func testComposition() {
        let d = Date(year: 2026, month: 7, day: 4)
        let t = Time(hour: 18, minute: 0)
        let ts = d.at(t)
        XCTAssertEqual(ts.date, d)
        XCTAssertEqual(ts.time, t)
    }
}
