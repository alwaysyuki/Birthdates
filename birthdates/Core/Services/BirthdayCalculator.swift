//
//  BirthdayCalculator.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation

/// Strategy for resolving February 29 birthdays in non-leap years.
enum LeapYearBehavior: String, Sendable, Codable, CaseIterable {
    /// Celebrate on February 28 in non-leap years (default).
    case february28 = "February 28"
    /// Celebrate on March 1 in non-leap years.
    case march1 = "March 1"
}

/// Errors produced when birthday calculation cannot proceed due to missing or invalid data.
enum BirthdayCalculationError: LocalizedError, Equatable, Sendable {
    case missingBirthday
    case invalidMonth(Int)
    case invalidDay(day: Int, month: Int)
    case invalidYear(Int)
    case futureBirthDate(Date)

    var errorDescription: String? {
        switch self {
        case .missingBirthday:
            return "No birthday was provided."
        case .invalidMonth(let month):
            return "Invalid birth month (\(month)). Month must be between 1 and 12."
        case .invalidDay(let day, let month):
            return "Invalid birth day (\(day)) for month \(month)."
        case .invalidYear(let year):
            return "Invalid birth year (\(year)). Year must be between 1900 and the current year."
        case .futureBirthDate(let date):
            return "Birthdate (\(date.formatted(date: .numeric, time: .omitted))) cannot be in the future."
        }
    }
}

/// Comprehensive, strongly-typed result of a birthday calculation.
struct BirthdayDetails: Equatable, Sendable {
    /// Calendar date of the next occurrence of the birthday.
    let nextBirthday: Date
    /// Calendar days remaining until the next occurrence (0 if today).
    let daysRemaining: Int
    /// Whether the birthday is today at calendar-day granularity.
    let isToday: Bool
    /// The age the friend will turn on their next birthday (nil if birth year unknown).
    let turningAge: Int?
    /// The friend's current age as of the reference date (nil if birth year unknown).
    let currentAge: Int?
    /// Western astrological zodiac sign with emoji symbol.
    let zodiacSign: String

    init(
        nextBirthday: Date,
        daysRemaining: Int,
        isToday: Bool,
        turningAge: Int?,
        currentAge: Int?,
        zodiacSign: String
    ) {
        self.nextBirthday = nextBirthday
        self.daysRemaining = daysRemaining
        self.isToday = isToday
        self.turningAge = turningAge
        self.currentAge = currentAge
        self.zodiacSign = zodiacSign
    }
}

/// Standalone calculation engine handling calendar-day granularity, leap-year resolutions,
/// year boundaries, time zones, turning age, and upcoming ranges without seconds-per-day math.
struct BirthdayCalculator: Sendable {
    static let shared = BirthdayCalculator()

    var calendar: Calendar
    var leapYearBehavior: LeapYearBehavior

    init(
        calendar: Calendar = .current,
        leapYearBehavior: LeapYearBehavior = .february28
    ) {
        self.calendar = calendar
        self.leapYearBehavior = leapYearBehavior
    }

    // MARK: - Validation & Date Resolution
    /// Determines whether the specified Gregorian calendar year is a leap year.
    func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    }

    /// Resolves the actual calendar date for a given month and day in a target year,
    /// respecting leap-year rules and configurable non-leap February 29 behavior.
    func resolveDate(month: Int, day: Int, inYear targetYear: Int) -> Date? {
        var resolvedMonth = month
        var resolvedDay = day

        if month == 2 && day == 29 {
            if !isLeapYear(targetYear) {
                switch leapYearBehavior {
                case .february28:
                    resolvedMonth = 2
                    resolvedDay = 28
                case .march1:
                    resolvedMonth = 3
                    resolvedDay = 1
                }
            }
        }

        var components = DateComponents()
        components.year = targetYear
        components.month = resolvedMonth
        components.day = resolvedDay

        return calendar.date(from: components)
    }

    // MARK: - Core Calculations
    /// Determines the next occurrence of a birthday on or after the reference date at calendar-day granularity.
    func nextBirthday(
        month: Int,
        day: Int,
        relativeTo referenceDate: Date = Date()
    ) throws -> Date {
        guard (1...12).contains(month) else {
            throw BirthdayCalculationError.invalidMonth(month)
        }

        let maxDays = (month == 2) ? 29 : BirthdayValidator.maxDaysInMonth(month: month, year: nil)
        guard day >= 1 && day <= maxDays else {
            throw BirthdayCalculationError.invalidDay(day: day, month: month)
        }

        let referenceYear = calendar.component(.year, from: referenceDate)
        let startOfRef = calendar.startOfDay(for: referenceDate)

        // Attempt birthday in current reference year
        guard let thisYearDate = resolveDate(month: month, day: day, inYear: referenceYear) else {
            throw BirthdayCalculationError.invalidDay(day: day, month: month)
        }

        let startOfThisYear = calendar.startOfDay(for: thisYearDate)

        if startOfThisYear >= startOfRef {
            return startOfThisYear
        } else {
            // Roll over to following calendar year
            guard let nextYearDate = resolveDate(month: month, day: day, inYear: referenceYear + 1) else {
                throw BirthdayCalculationError.invalidDay(day: day, month: month)
            }
            return calendar.startOfDay(for: nextYearDate)
        }
    }

    /// Calculates days remaining until the next birthday occurrence using Calendar dateComponents.
    func daysRemaining(
        month: Int,
        day: Int,
        relativeTo referenceDate: Date = Date()
    ) throws -> Int {
        let next = try nextBirthday(month: month, day: day, relativeTo: referenceDate)
        let startOfRef = calendar.startOfDay(for: referenceDate)
        let components = calendar.dateComponents([.day], from: startOfRef, to: next)
        return max(0, components.day ?? 0)
    }

    /// Checks if a birthday falls on the reference date at calendar-day granularity.
    func isBirthdayToday(
        month: Int,
        day: Int,
        relativeTo referenceDate: Date = Date()
    ) -> Bool {
        guard let remaining = try? daysRemaining(month: month, day: day, relativeTo: referenceDate) else {
            return false
        }
        return remaining == 0
    }

    /// Checks if a birthday occurs within the specified number of days from the reference date.
    func isBirthdayWithin(
        month: Int,
        day: Int,
        days: Int,
        relativeTo referenceDate: Date = Date()
    ) -> Bool {
        guard let remaining = try? daysRemaining(month: month, day: day, relativeTo: referenceDate) else {
            return false
        }
        return remaining >= 0 && remaining <= days
    }

    /// Calculates the turning age on the upcoming birthday occurrence if birth year is known.
    func ageTurning(
        birthYear: Int?,
        birthMonth: Int,
        birthDay: Int,
        relativeTo referenceDate: Date = Date()
    ) -> Int? {
        guard let birthYear else { return nil }
        guard let nextOccurrence = try? nextBirthday(month: birthMonth, day: birthDay, relativeTo: referenceDate) else {
            return nil
        }
        let nextYear = calendar.component(.year, from: nextOccurrence)
        let age = nextYear - birthYear
        return age >= 0 ? age : nil
    }

    /// Calculates the person's current age as of the reference date if birth year is known.
    func currentAge(
        birthYear: Int?,
        birthMonth: Int,
        birthDay: Int,
        relativeTo referenceDate: Date = Date()
    ) -> Int? {
        guard let birthYear else { return nil }

        let referenceYear = calendar.component(.year, from: referenceDate)
        let startOfRef = calendar.startOfDay(for: referenceDate)

        guard let birthdayThisYear = resolveDate(month: birthMonth, day: birthDay, inYear: referenceYear) else {
            return nil
        }
        let startOfBirthdayThisYear = calendar.startOfDay(for: birthdayThisYear)

        if startOfRef >= startOfBirthdayThisYear {
            // Birthday has occurred (or is today) in the reference year
            return max(0, referenceYear - birthYear)
        } else {
            // Birthday has not yet occurred this year
            return max(0, referenceYear - birthYear - 1)
        }
    }

    /// Determines the Western zodiac sign and symbol for a given month and day.
    func zodiacSign(month: Int, day: Int) -> String {
        switch (month, day) {
        case (1, 20...31), (2, 1...18): return "Aquarius ♒️"
        case (2, 19...29), (3, 1...20): return "Pisces ♓️"
        case (3, 21...31), (4, 1...19): return "Aries ♈️"
        case (4, 20...30), (5, 1...20): return "Taurus ♉️"
        case (5, 21...31), (6, 1...20): return "Gemini ♊️"
        case (6, 21...30), (7, 1...22): return "Cancer ♋️"
        case (7, 23...31), (8, 1...22): return "Leo ♌️"
        case (8, 23...31), (9, 1...22): return "Virgo ♍️"
        case (9, 23...30), (10, 1...22): return "Libra ♎️"
        case (10, 23...31), (11, 1...21): return "Scorpio ♏️"
        case (11, 22...30), (12, 1...21): return "Sagittarius ♐️"
        default: return "Capricorn ♑️"
        }
    }

    // MARK: - Comprehensive Calculation
    /// Validates inputs and compiles full BirthdayDetails for a given set of components.
    func calculateDetails(
        month: Int?,
        day: Int?,
        year: Int? = nil,
        relativeTo referenceDate: Date = Date()
    ) -> Result<BirthdayDetails, BirthdayCalculationError> {
        guard let month, let day else {
            return .failure(.missingBirthday)
        }

        guard (1...12).contains(month) else {
            return .failure(.invalidMonth(month))
        }

        let maxDays = (month == 2) ? 29 : BirthdayValidator.maxDaysInMonth(month: month, year: year)
        guard day >= 1 && day <= maxDays else {
            return .failure(.invalidDay(day: day, month: month))
        }

        if let year {
            let currentYear = calendar.component(.year, from: referenceDate)
            guard (1900...currentYear).contains(year) else {
                return .failure(.invalidYear(year))
            }

            if let resolved = resolveDate(month: month, day: day, inYear: year),
               calendar.startOfDay(for: resolved) > calendar.startOfDay(for: referenceDate) {
                return .failure(.futureBirthDate(resolved))
            }
        }

        do {
            let next = try nextBirthday(month: month, day: day, relativeTo: referenceDate)
            let remaining = try daysRemaining(month: month, day: day, relativeTo: referenceDate)
            let today = (remaining == 0)
            let turning = ageTurning(birthYear: year, birthMonth: month, birthDay: day, relativeTo: referenceDate)
            let current = currentAge(birthYear: year, birthMonth: month, birthDay: day, relativeTo: referenceDate)
            let zodiac = zodiacSign(month: month, day: day)

            let details = BirthdayDetails(
                nextBirthday: next,
                daysRemaining: remaining,
                isToday: today,
                turningAge: turning,
                currentAge: current,
                zodiacSign: zodiac
            )
            return .success(details)
        } catch let error as BirthdayCalculationError {
            return .failure(error)
        } catch {
            return .failure(.invalidDay(day: day, month: month))
        }
    }

    // MARK: - Friend Model Helpers
    /// Calculates birthday details directly for a Friend instance.
    func calculate(
        for friend: Friend,
        relativeTo referenceDate: Date = Date()
    ) -> Result<BirthdayDetails, BirthdayCalculationError> {
        guard friend.hasBirthday else {
            return .failure(.missingBirthday)
        }
        return calculateDetails(
            month: friend.birthMonth,
            day: friend.birthDay,
            year: friend.isBirthYearKnown ? friend.birthYear : nil,
            relativeTo: referenceDate
        )
    }

    func nextBirthday(for friend: Friend, relativeTo referenceDate: Date = Date()) -> Date? {
        guard friend.hasBirthday else { return nil }
        return try? nextBirthday(month: friend.birthMonth, day: friend.birthDay, relativeTo: referenceDate)
    }

    func daysRemaining(for friend: Friend, relativeTo referenceDate: Date = Date()) -> Int? {
        guard friend.hasBirthday else { return nil }
        return try? daysRemaining(month: friend.birthMonth, day: friend.birthDay, relativeTo: referenceDate)
    }

    func isBirthdayToday(for friend: Friend, relativeTo referenceDate: Date = Date()) -> Bool {
        guard friend.hasBirthday else { return false }
        return isBirthdayToday(month: friend.birthMonth, day: friend.birthDay, relativeTo: referenceDate)
    }

    func ageTurning(for friend: Friend, relativeTo referenceDate: Date = Date()) -> Int? {
        guard friend.hasBirthday else { return nil }
        return ageTurning(
            birthYear: friend.isBirthYearKnown ? friend.birthYear : nil,
            birthMonth: friend.birthMonth,
            birthDay: friend.birthDay,
            relativeTo: referenceDate
        )
    }

    func currentAge(for friend: Friend, relativeTo referenceDate: Date = Date()) -> Int? {
        guard friend.hasBirthday else { return nil }
        return currentAge(
            birthYear: friend.isBirthYearKnown ? friend.birthYear : nil,
            birthMonth: friend.birthMonth,
            birthDay: friend.birthDay,
            relativeTo: referenceDate
        )
    }

    func zodiacSign(for friend: Friend) -> String? {
        guard friend.hasBirthday else { return nil }
        return zodiacSign(month: friend.birthMonth, day: friend.birthDay)
    }
}
