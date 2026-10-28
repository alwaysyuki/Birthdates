//
//  BirthdayValidator.swift
//  birthdates
//
//  Created for native macOS offline-first birthday management.
//

import Foundation

/// Specific validation errors that can occur when validating birthday components.
enum BirthdayValidationError: LocalizedError, Equatable {
    case invalidMonth(Int)
    case invalidDay(day: Int, month: Int)
    case invalidYear(Int)
    case futureDate(Date)

    var errorDescription: String? {
        switch self {
        case .invalidMonth(let month):
            return "Invalid birth month (\(month)). Month must be between 1 and 12."
        case .invalidDay(let day, let month):
            return "Invalid birth day (\(day)) for month \(month)."
        case .invalidYear(let year):
            return "Invalid birth year (\(year)). Year must be between 1900 and current year."
        case .futureDate(let date):
            return "Birthdate (\(date.formatted(date: .numeric, time: .omitted))) cannot be in the future."
        }
    }
}

/// Validates individual birthday components (month, day, optional year) to prevent corrupt data entry.
enum BirthdayValidator {
    /// Validates month, day, and optional year against the calendar.
    static func validate(
        month: Int,
        day: Int,
        year: Int?,
        relativeTo referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) throws {
        // Validate month range (1 - 12)
        guard (1...12).contains(month) else {
            throw BirthdayValidationError.invalidMonth(month)
        }

        // Validate day range for the given month (and year if known)
        let maxDays = maxDaysInMonth(month: month, year: year)
        guard day >= 1 && day <= maxDays else {
            throw BirthdayValidationError.invalidDay(day: day, month: month)
        }

        // Validate year if specified
        if let year {
            let currentYear = calendar.component(.year, from: referenceDate)
            guard (1900...currentYear).contains(year) else {
                throw BirthdayValidationError.invalidYear(year)
            }

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day

            if let date = calendar.date(from: components),
               calendar.startOfDay(for: date) > calendar.startOfDay(for: referenceDate) {
                throw BirthdayValidationError.futureDate(date)
            }
        }
    }

    /// Determines the maximum valid days for a given month, accounting for leap years if the year is known.
    static func maxDaysInMonth(month: Int, year: Int?) -> Int {
        switch month {
        case 2:
            if let year {
                let isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
                return isLeap ? 29 : 28
            }
            // Allow Feb 29 for unknown year to support leap-year birthdays
            return 29
        case 4, 6, 9, 11:
            return 30
        default:
            return 31
        }
    }
}
