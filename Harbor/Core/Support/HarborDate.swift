import Foundation

/// Centralizes the date formats exchanged with Stremio and TMDB.
enum HarborDate {
    static func parseISO8601(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }

    static func timestamp(_ date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    static func parseCalendarDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return calendarDateFormatter.date(from: value)
    }

    static func calendarDate(
        byAddingDays offset: Int,
        to date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        let adjusted = calendar.date(byAdding: .day, value: offset, to: date) ?? date
        return calendarDateFormatter.string(from: adjusted)
    }

    private static var calendarDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
