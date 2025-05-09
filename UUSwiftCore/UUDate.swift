//
//  UUDate
//  Useful Utilities - Handy helpers for working with Date's
//
//	License:
//  You are free to use this code for whatever purposes you desire.
//  The only requirement is that you smile everytime you use it.
//

import Foundation

fileprivate let kUUSecondsPerDay: TimeInterval = (60 * 60 * 24)

public struct UUDate
{
    public struct Constants
    {
        public static let secondsInOneMinute : TimeInterval = 60
        public static let minutesInOneHour : TimeInterval = 60
        public static let hoursInOneDay : TimeInterval = 24
        public static let daysInOneWeek : TimeInterval = 7
        public static let millisInOneSecond : TimeInterval = 1000
        
        public static let secondsInOneHour : TimeInterval = secondsInOneMinute * minutesInOneHour
        public static let secondsInOneDay : TimeInterval = secondsInOneHour * hoursInOneDay
        public static let secondsInOneWeek : TimeInterval = secondsInOneDay * daysInOneWeek
    }
    
    public struct Formats
    {
        public static let rfc3339               = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        public static let rfc3339WithMillis     = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        public static let rfc3339WithTimeZone   = "yyyy-MM-dd'T'HH:mm:ssZ"
        public static let rfc3339WithMillisTimeZone = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        public static let iso8601DateOnly       = "yyyy-MM-dd"
        public static let iso8601TimeOnly       = "HH:mm:ss"
        public static let iso8601DateTime       = "yyyy-MM-dd HH:mm:ss"
        public static let timeOfDay             = "h:mm a"
        public static let dayOfMonth            = "d"
        public static let numericMonthOfYear    = "L"
        public static let shortMonthOfYear      = "LLL"
        public static let longMonthOfYear       = "LLLL"
        public static let shortDayOfWeek        = "EE"
        public static let longDayOfWeek         = "EEEE"
        public static let twoDigitYear          = "yy"
        public static let fourDigitYear         = "yyyy"
    }
    
    public struct TimeZones
    {
        public static let utc : TimeZone = TimeZone(abbreviation: "UTC")!
    }
}

public extension Locale
{
    static var uuEnUSPosix : Locale
    {
        get
        {
            return Locale(identifier: "en_US_POSIX")
        }
    }
}

extension DateFormatter
{
    private static var uuSharedFormatterCache : Dictionary<String, DateFormatter> = Dictionary()
    private static let lockingQueue: DispatchQueue = DispatchQueue(label: "UUDateFormatter_LockingQueue")
    
    private static func uuCacheLookupKey(_ format : String, _ timeZone: TimeZone, _ locale: Locale) -> String
    {
        return "\(format)_\(timeZone.identifier)_\(locale.identifier)"
    }
    
    public static func uuCachedFormatter(_ format : String, timeZone: TimeZone = TimeZone.current, locale: Locale = Locale.current) -> DateFormatter
    {
        var df : DateFormatter!
        
        lockingQueue.sync
        {
            let key = uuCacheLookupKey(format, timeZone, locale)
            
            df = uuSharedFormatterCache[key]
            if (df == nil)
            {
                df = DateFormatter()
                df!.dateFormat = format
                df!.locale = locale
                df!.calendar = Calendar(identifier: .gregorian)
                df!.timeZone = timeZone
                uuSharedFormatterCache[key] = df!
            }
        }
        
        return df!
    }
}

public extension Date
{
	func uuFormat(_ format : String, timeZone : TimeZone = TimeZone.current, locale: Locale = Locale.current) -> String
    {
        let df = DateFormatter.uuCachedFormatter(format, timeZone: timeZone, locale: locale)
        return df.string(from: self)
    }
    
	func uuRfc3339String(timeZone : TimeZone = TimeZone.current, locale: Locale = Locale.uuEnUSPosix) -> String
    {
        return uuFormat(UUDate.Formats.rfc3339, timeZone: timeZone, locale: locale)
    }
    
    func uuRfc3339StringUtc() -> String
    {
        return uuRfc3339String(timeZone: UUDate.TimeZones.utc)
    }
    
	func uuRfc3339WithMillisString(timeZone : TimeZone = TimeZone.current, locale: Locale = Locale.uuEnUSPosix) -> String
    {
        return uuFormat(UUDate.Formats.rfc3339WithMillis, timeZone: timeZone, locale: locale)
    }
    
	func uuRfc3339WithMillisStringUtc() -> String
    {
        return uuRfc3339WithMillisString(timeZone: UUDate.TimeZones.utc)
    }
    
	var uuDayOfMonth : String
    {
        return uuFormat(UUDate.Formats.dayOfMonth)
    }
    
	var uuNumericMonthOfYear : String
    {
        return uuFormat(UUDate.Formats.numericMonthOfYear)
    }
    
	var uuShortMonthOfYear : String
    {
        return uuFormat(UUDate.Formats.shortMonthOfYear)
    }
    
	var uuLongMonthOfYear : String
    {
        return uuFormat(UUDate.Formats.longMonthOfYear)
    }
    
	var uuShortDayOfWeek : String
    {
        return uuFormat(UUDate.Formats.shortDayOfWeek)
    }
    
	var uuLongDayOfWeek : String
    {
        return uuFormat(UUDate.Formats.longDayOfWeek)
    }
    
	var uuTwoDigitYear : String
    {
        return uuFormat(UUDate.Formats.twoDigitYear)
    }
    
	var uuFourDigitYear : String
    {
        return uuFormat(UUDate.Formats.fourDigitYear)
    }
    
	func uuIsDatePartEqual(_ other: Date) -> Bool
    {
        let cal = Calendar(identifier: .gregorian)
        let parts: Set<Calendar.Component> = [.year, .month, .day]
        
        let thisDate = cal.dateComponents(parts, from: self)
        let otherDate = cal.dateComponents(parts, from: other)
        
        guard   let thisYear = thisDate.year, let thisMonth = thisDate.month, let thisDay = thisDate.day,
                let otherYear = otherDate.year, let otherMonth = otherDate.month, let otherDay = otherDate.day else
        {
            return false
        }
        
        return (thisYear == otherYear) && (thisMonth == otherMonth) && (thisDay == otherDay)
    }
    
	func uuIsToday() -> Bool
    {
        return uuIsDatePartEqual(Date())
    }
	
	func uuCountDaysInMonth() -> Int {
		let start = self.uuStartOfMonth()
		let end = self.uuEndOfMonth()
		return Calendar.current.dateComponents([.day], from: start, to:end).day! + 1
	}
	
	func uuCountWeeksInMonth() -> Int {
		
		var calendar = Calendar.current
		calendar.firstWeekday = 1
		let weekRange = calendar.range(of: .weekOfMonth, in: .month, for: self)
		return  weekRange!.count
	}

	func uuStartOfHour() -> Date {
		return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day, .hour], from: Calendar.current.startOfDay(for: self)))!
	}
	
	func uuStartOfDay() -> Date {
		return Calendar.current.startOfDay(for: self)
	}

	func uuEndOfDay() -> Date {
		return self.uuStartOfDay().addingTimeInterval((24.0 * 60.0 * 60.0) - 1)
	}
	
	func uuStartOfNextDay() -> Date {
		let date = Calendar.current.startOfDay(for: self)
		return date.addingTimeInterval(24.0 * 60.0 * 60.0)
	}
	
	func uuStartOfWeek() -> Date {
		let startOfWeek = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))!
		return startOfWeek
	}
	
	func uuEndOfWeek() -> Date {
		let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: self.uuStartOfWeek())!
		return endOfWeek
	}
	
	func uuStartOfMonth() -> Date {
		return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self)))!
	}
	
	func uuEndOfMonth() -> Date {
		return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.uuStartOfMonth())!
	}

	func uuAddDays(_ days : Int) -> Date {
		var dateComponents = DateComponents()
		dateComponents.day = days
		
		let newDate = Calendar.current.date(byAdding: dateComponents, to: self)
		return newDate!
	}
	
	func uuAddWeeks(_ weeks : Int) -> Date {
		var dateComponents = DateComponents()
		dateComponents.weekOfYear = weeks
		
		let newDate = Calendar.current.date(byAdding: dateComponents, to: self)
		return newDate!
	}
	
	func uuAddMonths(_ months : Int) -> Date {
		var dateComponents = DateComponents()
		dateComponents.month = months
		
		let newDate = Calendar.current.date(byAdding: dateComponents, to: self)
		return newDate!
	}
}

public extension Date // Delta formatters
{
    private static let kUUTimeDeltaJustNowFormat              = "Just now"
    private static let kUUTimeDeltaSecondsSingularFormat      = "%@ second ago"
    private static let kUUTimeDeltaSecondsPluralFormat        = "%@ seconds ago"
    private static let kUUTimeDeltaMinutesSingularFormat      = "%@ minute ago"
    private static let kUUTimeDeltaMinutesPluralFormat        = "%@ minutes ago"
    private static let kUUTimeDeltaHoursSingularFormat        = "%@ hour ago"
    private static let kUUTimeDeltaHoursPluralFormat          = "%@ hours ago"
    private static let kUUTimeDeltaDaysSingularFormat         = "%@ day ago"
    private static let kUUTimeDeltaDaysPluralFormat           = "%@ days ago"

    private static let kUUTimeDeltaJustNowFormatKey           = "UUTimeDeltaJustNowFormatKey"
    private static let kUUTimeDeltaSecondsSingularFormatKey   = "UUTimeDeltaSecondsSingularFormatKey"
    private static let kUUTimeDeltaSecondsPluralFormatKey     = "UUTimeDeltaSecondsPluralFormatKey"
    private static let kUUTimeDeltaMinutesSingularFormatKey   = "UUTimeDeltaMinutesSingularFormatKey"
    private static let kUUTimeDeltaMinutesPluralFormatKey     = "UUTimeDeltaMinutesPluralFormatKey"
    private static let kUUTimeDeltaHoursSingularFormatKey     = "UUTimeDeltaHoursSingularFormatKey"
    private static let kUUTimeDeltaHoursPluralFormatKey       = "UUTimeDeltaHoursPluralFormatKey"
    private static let kUUTimeDeltaDaysSingularFormatKey      = "UUTimeDeltaDaysSingularFormatKey"
    private static let kUUTimeDeltaDaysPluralFormatKey        = "UUTimeDeltaDaysPluralFormatKey"

    static func uuFormatTimeDelta(_ interval: TimeInterval) -> String
    {
        let days = (interval / kUUSecondsPerDay)
        
        if (days < 1)
        {
            let hours = days * 24
            
            if (hours < 1)
            {
                let minutes = hours * 60
                
                if (minutes < 1)
                {
                    let seconds = minutes * 60
                    
                    if (seconds >= 1 && seconds < 2)
                    {
                        return uuFormatDelta(kUUTimeDeltaSecondsSingularFormatKey, kUUTimeDeltaSecondsSingularFormat, seconds)
                    }
                    else if (seconds <= 0)
                    {
                        return Bundle.main.localizedString(forKey: kUUTimeDeltaJustNowFormatKey, value:kUUTimeDeltaJustNowFormat, table: nil)
                    }
                    else
                    {
                        return uuFormatDelta(kUUTimeDeltaSecondsPluralFormatKey, kUUTimeDeltaSecondsPluralFormat, seconds)
                    }
                }
                else if (minutes >= 1 && minutes < 2)
                {
                    return uuFormatDelta(kUUTimeDeltaMinutesSingularFormatKey, kUUTimeDeltaMinutesSingularFormat, minutes)
                }
                else
                {
                    return uuFormatDelta(kUUTimeDeltaMinutesPluralFormatKey, kUUTimeDeltaMinutesPluralFormat, minutes)
                }
            }
            else if (hours >= 1 && hours < 2)
            {
                return uuFormatDelta(kUUTimeDeltaHoursSingularFormatKey, kUUTimeDeltaHoursSingularFormat, hours)
            }
            else
            {
                return uuFormatDelta(kUUTimeDeltaHoursPluralFormatKey, kUUTimeDeltaHoursPluralFormat, hours)
            }
        }
        else if (days >= 1 && days < 2)
        {
            return uuFormatDelta(kUUTimeDeltaDaysSingularFormatKey, kUUTimeDeltaDaysSingularFormat, days)
        }
        else
        {
            return uuFormatDelta(kUUTimeDeltaDaysPluralFormatKey, kUUTimeDeltaDaysPluralFormat, days)
        }
    }

    static func uuFormatDelta(_ key: String, _ defaultFormatter: String, _ value: TimeInterval) -> String
    {
        let formatter = Bundle.main.localizedString(forKey: key, value: defaultFormatter, table: nil)
        return String(format: formatter, "\(Int(value))")
    }
}

public extension String
{
	func uuParseDate(format: String, timeZone: TimeZone = TimeZone.current, locale: Locale = Locale.current) -> Date?
    {
        let df = DateFormatter.uuCachedFormatter(format, timeZone: timeZone, locale: locale)
        return df.date(from: self)
    }
    
    // Formats a time duration string from a quantity of seconds --> HH:MM:SS
    static func uuFormatTimeDuration(_ seconds: Int, includeHoursIfZero: Bool = false) -> String
    {
        var workingSeconds = seconds
        let hours = workingSeconds / 3600;
        workingSeconds = workingSeconds % 3600
        
        let minutes = workingSeconds / 60
        workingSeconds = workingSeconds % 60
        
        if (includeHoursIfZero || hours > 0)
        {
            return String(format: "%02d:%02d:%02d", hours, minutes, workingSeconds)
        }
        else
        {
            return String(format: "%02d:%02d", minutes, workingSeconds)
        }
    }
}
