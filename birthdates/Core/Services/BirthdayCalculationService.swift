//
//  BirthdayCalculationService.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation

/// Protocol defining birthday calculation capabilities for testability.
protocol BirthdayCalculationServiceProtocol: Sendable {
    func nextBirthday(for birthdate: Date, relativeTo referenceDate: Date) -> Date
    func daysRemaining(for birthdate: Date, relativeTo referenceDate: Date) -> Int
    func ageTurning(for birthdate: Date, isBirthYearKnown: Bool, relativeTo referenceDate: Date) -> Int?
    func zodiacSign(for birthdate: Date) -> String
    func isBirthdayToday(for birthdate: Date, relativeTo referenceDate: Date) -> Bool
    func daysRemainingText(for days: Int) -> String
}

/// Native offline service adapting BirthdayCalculator for backward-compatible Date-based interfaces.
final class BirthdayCalculationService: BirthdayCalculationServiceProtocol {
    private let calculator: BirthdayCalculator
    private let calendar: Calendar

    init(calendar: Calendar = .current, leapYearBehavior: LeapYearBehavior = .february28) {
        self.calendar = calendar
        self.calculator = BirthdayCalculator(calendar: calendar, leapYearBehavior: leapYearBehavior)
    }

    /// Access to the underlying strongly-typed standalone calculator
    var underlyingCalculator: BirthdayCalculator {
        calculator
    }

    /// Determines the next occurrence of a friend's birthday on or after the reference date.
    func nextBirthday(for birthdate: Date, relativeTo referenceDate: Date = Date()) -> Date {
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        return (try? calculator.nextBirthday(month: month, day: day, relativeTo: referenceDate)) ?? referenceDate
    }

    /// Calculates days remaining until the next birthday occurrence.
    func daysRemaining(for birthdate: Date, relativeTo referenceDate: Date = Date()) -> Int {
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        return (try? calculator.daysRemaining(month: month, day: day, relativeTo: referenceDate)) ?? 0
    }

    /// Calculates the turning age if the birth year was recorded.
    func ageTurning(for birthdate: Date, isBirthYearKnown: Bool, relativeTo referenceDate: Date = Date()) -> Int? {
        guard isBirthYearKnown else { return nil }
        let year = calendar.component(.year, from: birthdate)
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        return calculator.ageTurning(birthYear: year, birthMonth: month, birthDay: day, relativeTo: referenceDate)
    }

    /// Checks if today is the friend's birthday.
    func isBirthdayToday(for birthdate: Date, relativeTo referenceDate: Date = Date()) -> Bool {
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        return calculator.isBirthdayToday(month: month, day: day, relativeTo: referenceDate)
    }

    /// Formats days remaining into human-readable text.
    func daysRemainingText(for days: Int) -> String {
        switch days {
        case 0:
            return "Today! 🎉"
        case 1:
            return "Tomorrow"
        default:
            return "In \(days) days"
        }
    }

    /// Determines Western zodiac sign for the given date.
    func zodiacSign(for birthdate: Date) -> String {
        let month = calendar.component(.month, from: birthdate)
        let day = calendar.component(.day, from: birthdate)
        return calculator.zodiacSign(month: month, day: day)
    }
}
