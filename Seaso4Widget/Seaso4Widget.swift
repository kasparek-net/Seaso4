import WidgetKit
import SwiftUI

// MARK: - Shared app group (must match main app)

private enum WidgetAppGroup {
    static let suiteName = "group.jk.Seaso4"
    static let store: UserDefaults? = UserDefaults(suiteName: suiteName)
}

// MARK: - Season model (duplicated for widget target)

private enum WidgetSeason: String, CaseIterable {
    case winter, spring, summer, autumn
    var emoji: String {
        switch self {
        case .winter: return "❄️"
        case .spring: return "🌸"
        case .summer: return "☀️"
        case .autumn: return "🍂"
        }
    }
    var displayName: String {
        switch self {
        case .winter: return "Winter"
        case .spring: return "Spring"
        case .summer: return "Summer"
        case .autumn: return "Autumn"
        }
    }
    var accentColor: Color {
        switch self {
        case .winter: return .blue
        case .spring: return .green
        case .summer: return .yellow
        case .autumn: return .orange
        }
    }
}

private struct WidgetSeasonProgress {
    let season: WidgetSeason
    let progress: Double
    let startDate: Date
    let endDate: Date
    let elapsedDays: Int
    let remainingDays: Int
}

private enum WidgetSeasonDefinition: String {
    case astronomical
    case calendar
}

// MARK: - Calculator (calendar / astronomical)

private final class WidgetSeasonCalculator {
    static let shared = WidgetSeasonCalculator()
    private init() {}

    private func makeDate(_ calendar: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date {
        var comp = DateComponents()
        comp.year = y
        comp.month = m
        comp.day = d
        return calendar.date(from: comp)!
    }

    /// Počet dní do začátku daného astronomického ročního období od zadaného data.
    func daysUntilSeasonStart(_ season: WidgetSeason, from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let springStart = makeDate(calendar, year, 3, 20)
        let summerStart = makeDate(calendar, year, 6, 21)
        let autumnStart = makeDate(calendar, year, 9, 23)
        let winterStart = makeDate(calendar, year, 12, 21)

        let targetStartThisYear: Date
        switch season {
        case .spring:
            targetStartThisYear = springStart
        case .summer:
            targetStartThisYear = summerStart
        case .autumn:
            targetStartThisYear = autumnStart
        case .winter:
            targetStartThisYear = winterStart
        }

        let startDate: Date
        if date <= targetStartThisYear {
            startDate = targetStartThisYear
        } else {
            // další rok
            let nextYearStart: Date
            switch season {
            case .spring:
                nextYearStart = makeDate(calendar, year + 1, 3, 20)
            case .summer:
                nextYearStart = makeDate(calendar, year + 1, 6, 21)
            case .autumn:
                nextYearStart = makeDate(calendar, year + 1, 9, 23)
            case .winter:
                nextYearStart = makeDate(calendar, year + 1, 12, 21)
            }
            startDate = nextYearStart
        }

        let diff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: startDate)
        ).day ?? 0
        return max(diff, 0)
    }

    func astronomicalProgress(for season: WidgetSeason, date: Date) -> WidgetSeasonProgress {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let winterStart = makeDate(calendar, year - 1, 12, 21)
        let springStart = makeDate(calendar, year, 3, 20)
        let summerStart = makeDate(calendar, year, 6, 21)
        let autumnStart = makeDate(calendar, year, 9, 23)
        let nextWinterStart = makeDate(calendar, year, 12, 21)
        let nextSpringStart = makeDate(calendar, year + 1, 3, 20)
        let (start, end): (Date, Date)
        switch season {
        case .spring: start = springStart; end = summerStart
        case .summer: start = summerStart; end = autumnStart
        case .autumn: start = autumnStart; end = nextWinterStart
        case .winter:
            if date < springStart { start = winterStart; end = springStart }
            else { start = nextWinterStart; end = nextSpringStart }
        }
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
        let elapsedRaw = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        let elapsed = min(max(elapsedRaw, 0), totalDays)
        let remaining = max(totalDays - elapsed, 0)
        let progress = Double(elapsed) / Double(totalDays)
        return WidgetSeasonProgress(season: season, progress: progress, startDate: start, endDate: end, elapsedDays: elapsed, remainingDays: remaining)
    }

    func calendarProgress(for season: WidgetSeason, date: Date) -> WidgetSeasonProgress {
        let (start, end) = calendarDates(for: season, referenceDate: date)
        let calendar = Calendar.current
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
        let elapsedRaw = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        let elapsed = min(max(elapsedRaw, 0), totalDays)
        let remaining = max(totalDays - elapsed, 0)
        let progress = Double(elapsed) / Double(totalDays)
        return WidgetSeasonProgress(season: season, progress: progress, startDate: start, endDate: end, elapsedDays: elapsed, remainingDays: remaining)
    }

    private func calendarDates(for season: WidgetSeason, referenceDate: Date) -> (Date, Date) {
        let astro = astronomicalProgress(for: season, date: referenceDate)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: astro.startDate)
        func lastDayOfFebruary(year: Int) -> Date {
            var c = DateComponents()
            c.year = year
            c.month = 3
            c.day = 0
            return calendar.date(from: c)!
        }
        switch season {
        case .winter: return (makeDate(calendar, year, 12, 1), lastDayOfFebruary(year: year + 1))
        case .spring: return (makeDate(calendar, year, 3, 1), makeDate(calendar, year, 5, 31))
        case .summer: return (makeDate(calendar, year, 6, 1), makeDate(calendar, year, 8, 31))
        case .autumn: return (makeDate(calendar, year, 9, 1), makeDate(calendar, year, 11, 30))
        }
    }

    /// Počet dní do začátku kalendářního (meteorologického) ročního období.
    func daysUntilCalendarSeasonStart(_ season: WidgetSeason, from date: Date = Date()) -> Int {
        let (start, _) = calendarDates(for: season, referenceDate: date)
        let calendar = Calendar.current
        let diff = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: start)
        ).day ?? 0
        return max(diff, 0)
    }

    /// Aktuální roční období podle astronomických hranic (jaro od 20.3., …).
    func currentSeasonAstronomical(date: Date = Date()) -> WidgetSeason {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let springStart = makeDate(calendar, year, 3, 20)
        let summerStart = makeDate(calendar, year, 6, 21)
        let autumnStart = makeDate(calendar, year, 9, 23)
        let nextWinterStart = makeDate(calendar, year, 12, 21)
        let winterStart = makeDate(calendar, year - 1, 12, 21)
        switch date {
        case winterStart..<springStart: return .winter
        case springStart..<summerStart: return .spring
        case summerStart..<autumnStart: return .summer
        case autumnStart..<nextWinterStart: return .autumn
        default: return .winter
        }
    }
    
    /// Aktuální roční období podle kalendářních (meteorologických) hranic (jaro 1.3.–31.5., …).
    func currentSeasonCalendar(date: Date = Date()) -> WidgetSeason {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        switch month {
        case 12, 1, 2: return .winter
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .autumn
        default: return .winter
        }
    }
    
    /// Aktuální roční období podle zvolené definice.
    func currentSeason(useCalendarDefinition: Bool, date: Date = Date()) -> WidgetSeason {
        useCalendarDefinition ? currentSeasonCalendar(date: date) : currentSeasonAstronomical(date: date)
    }
    
    func currentSeason(date: Date = Date()) -> WidgetSeason {
        currentSeasonAstronomical(date: date)
    }
}

// MARK: - Sunrise/sunset (NOAA, stejný výpočet jako v aplikaci)

private enum WidgetSunTimesCalculator {
    private static let jdUnixEpoch = 2440587.5
    static let defaultLat = 50.0755
    static let defaultLon = 14.4378

    static func sunriseSunset(latitude: Double, longitude: Double, date: Date) -> (sunrise: Date, sunset: Date)? {
        let calendar = Calendar.current
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comp.year, let month = comp.month, let day = comp.day else { return nil }
        let jd = julianDay(year: year, month: month, day: day) + 0.5
        let n = jd - 2451545.0
        let jStar = n - longitude / 360.0
        let m = (357.5291 + 0.98560028 * jStar) * .pi / 180
        let c = 1.9148 * sin(m) + 0.0200 * sin(2 * m) + 0.0003 * sin(3 * m)
        let lambda = 280.466 + 0.98564736 * jStar + c
        let lambdaRad = lambda * .pi / 180
        let jTransit = 2451545.0 + jStar + 0.0053 * sin(m) - 0.0069 * sin(2 * lambdaRad)
        let sinDelta = 0.3978 * sin(lambdaRad)
        let cosDelta = cos(asin(sinDelta))
        let latRad = latitude * .pi / 180
        let cosOmega = (sin(-0.833 * .pi / 180) - sin(latRad) * sinDelta) / (cos(latRad) * cosDelta)
        if cosOmega <= -1 || cosOmega >= 1 { return nil }
        let omega = acos(cosOmega) * 180 / .pi
        let jRise = jTransit - omega / 360.0
        let jSet = jTransit + omega / 360.0
        let rise = Date(timeIntervalSince1970: (jRise - jdUnixEpoch) * 86400)
        let set = Date(timeIntervalSince1970: (jSet - jdUnixEpoch) * 86400)
        return (rise, set)
    }

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100, b = 2 - a + a / 4
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + Double(b) - 1524.5
    }
}

// MARK: - Widget entry & provider

/// Jedno konzistentní načtení nastavení z App Group (klíče = mainSeasonDefinition, widgetSeason, displayMode, showDaylight).
private struct WidgetSettingsSnapshot {
    let seasonKey: String
    let mainSeasonDefinition: String?
    let showPercent: Bool
    let showDaylight: Bool
    let daylightLat: Double
    let daylightLon: Double
    /// IANA time zone for the selected manual location; nil = use device timezone.
    let daylightTimeZoneId: String?

    static func load(from store: UserDefaults?) -> WidgetSettingsSnapshot {
        guard let s = store else {
            return WidgetSettingsSnapshot(seasonKey: "current", mainSeasonDefinition: nil, showPercent: true, showDaylight: true, daylightLat: 0, daylightLon: 0, daylightTimeZoneId: nil)
        }
        let sk = s.string(forKey: "widgetSeason") ?? "current"
        let def = s.string(forKey: "mainSeasonDefinition")
        let dm = s.string(forKey: "displayMode")
        let percent = (dm != "days")
        var day = true
        if s.object(forKey: "showDaylight") != nil { day = s.bool(forKey: "showDaylight") }
        let lat = s.double(forKey: "daylightLat")
        let lon = s.double(forKey: "daylightLon")
        let tzId = s.string(forKey: "daylightTimeZoneId")
        return WidgetSettingsSnapshot(seasonKey: sk, mainSeasonDefinition: def, showPercent: percent, showDaylight: day, daylightLat: lat, daylightLon: lon, daylightTimeZoneId: tzId)
    }

    static func loadFromPlist() -> WidgetSettingsSnapshot? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetAppGroup.suiteName) else { return nil }
        let prefs = container.appendingPathComponent("Library/Preferences")
        let plistURL = prefs.appendingPathComponent("\(WidgetAppGroup.suiteName).plist")
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any] else { return nil }
        func str(_ key: String) -> String? { dict[key] as? String }
        func bool(_ key: String) -> Bool {
            (dict[key] as? NSNumber)?.boolValue ?? false
        }
        func double(_ key: String) -> Double {
            (dict[key] as? NSNumber)?.doubleValue ?? 0
        }
        let percent = (str("displayMode") != "days")
        return WidgetSettingsSnapshot(
            seasonKey: str("widgetSeason") ?? "current",
            mainSeasonDefinition: str("mainSeasonDefinition"),
            showPercent: percent,
            showDaylight: bool("showDaylight"),
            daylightLat: double("daylightLat"),
            daylightLon: double("daylightLon"),
            daylightTimeZoneId: str("daylightTimeZoneId")
        )
    }

    /// Preferuje čtení z plist (čerstvá data), jinak fallback na UserDefaults.
    static func loadFresh(store: UserDefaults?) -> WidgetSettingsSnapshot {
        if let fromPlist = loadFromPlist() { return fromPlist }
        return load(from: store)
    }
}

struct SeasonWidgetEntry: TimelineEntry {
    let date: Date
    fileprivate let progress: WidgetSeasonProgress
    let isCalendarDefinition: Bool
    fileprivate let displayedSeason: WidgetSeason
    /// true = show percentage, false = show days
    let showPercent: Bool
    /// show sunrise / sunset row
    let showDaylight: Bool
    let sunriseText: String?
    let sunsetText: String?
}

struct SeasonWidgetProvider: TimelineProvider {
    /// Sunrise/sunset strings for the given date (NOAA). Optional timeZoneId = format in that location’s time; nil = device timezone.
    fileprivate func makeDaylightStrings(for date: Date, lat: Double = 0, lon: Double = 0, timeZoneId: String? = nil) -> (sunrise: String, sunset: String) {
        let latitude = (lat != 0 || lon != 0) ? lat : WidgetSunTimesCalculator.defaultLat
        let longitude = (lat != 0 || lon != 0) ? lon : WidgetSunTimesCalculator.defaultLon
        let today = Calendar.current.startOfDay(for: date)
        let tf = DateFormatter()
        tf.locale = Locale.current
        tf.timeStyle = .short
        if let id = timeZoneId, let tz = TimeZone(identifier: id) {
            tf.timeZone = tz
        }
        guard let times = WidgetSunTimesCalculator.sunriseSunset(latitude: latitude, longitude: longitude, date: today) else {
            return (tf.string(from: date), tf.string(from: date))
        }
        return (tf.string(from: times.sunrise), tf.string(from: times.sunset))
    }

    func placeholder(in context: Context) -> SeasonWidgetEntry {
        SeasonWidgetEntry(
            date: Date(),
            progress: WidgetSeasonProgress(season: .spring, progress: 0.5, startDate: Date(), endDate: Date(), elapsedDays: 45, remainingDays: 47),
            isCalendarDefinition: true,
            displayedSeason: .spring,
            showPercent: true,
            showDaylight: false,
            sunriseText: nil,
            sunsetText: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SeasonWidgetEntry) -> Void) {
        completion(makeEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SeasonWidgetEntry>) -> Void) {
        // Pre-computed entry per midnight: WidgetKit switches entries exactly on
        // schedule, unlike .after refreshes which the system defers for budget.
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        var entries = [makeEntry(date: now)]
        for dayOffset in 1...7 {
            if let midnight = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) {
                entries.append(makeEntry(date: midnight))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(date: Date) -> SeasonWidgetEntry {
        let store = WidgetAppGroup.store
        let snapshot = WidgetSettingsSnapshot.loadFresh(store: store)
        let def: WidgetSeasonDefinition = snapshot.mainSeasonDefinition.flatMap(WidgetSeasonDefinition.init(rawValue:)) ?? .calendar
        let season: WidgetSeason = {
            if snapshot.seasonKey == "current" { return WidgetSeasonCalculator.shared.currentSeason(useCalendarDefinition: def == .calendar, date: date) }
            return WidgetSeason(rawValue: snapshot.seasonKey) ?? .winter
        }()
        let baseProgress = def == .calendar
            ? WidgetSeasonCalculator.shared.calendarProgress(for: season, date: date)
            : WidgetSeasonCalculator.shared.astronomicalProgress(for: season, date: date)
        let isCurrentSeasonKey = (snapshot.seasonKey == "current")
        let finalizedProgress: WidgetSeasonProgress
        let showPercent: Bool
        if isCurrentSeasonKey {
            finalizedProgress = baseProgress
            showPercent = snapshot.showPercent
        } else {
            let daysUntilStart: Int = def == .calendar
                ? WidgetSeasonCalculator.shared.daysUntilCalendarSeasonStart(season, from: date)
                : WidgetSeasonCalculator.shared.daysUntilSeasonStart(season, from: date)
            finalizedProgress = WidgetSeasonProgress(
                season: season, progress: 0, startDate: baseProgress.startDate, endDate: baseProgress.endDate,
                elapsedDays: 0, remainingDays: daysUntilStart
            )
            showPercent = false
        }
        let daylight = snapshot.showDaylight ? makeDaylightStrings(for: date, lat: snapshot.daylightLat, lon: snapshot.daylightLon, timeZoneId: snapshot.daylightTimeZoneId) : nil
        return SeasonWidgetEntry(
            date: date, progress: finalizedProgress, isCalendarDefinition: def == .calendar,
            displayedSeason: season, showPercent: showPercent, showDaylight: snapshot.showDaylight,
            sunriseText: daylight?.sunrise, sunsetText: daylight?.sunset
        )
    }
}

// MARK: - Widget views (dark/light aware)

private let widgetLineWidth: CGFloat = 12

private struct WidgetProgressRing: View {
    let progress: Double
    let color: Color
    var body: some View {
        let p = min(max(progress, 0), 1)
        Circle()
            .trim(from: 0.5, to: 0.5 + 0.5 * p)
            .stroke(color, style: StrokeStyle(lineWidth: widgetLineWidth, lineCap: .round, lineJoin: .round))
    }
}

private struct WidgetProgressRingTrack: View {
    let color: Color
    var body: some View {
        Circle()
            .trim(from: 0.5, to: 1.0)
            .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: widgetLineWidth, lineCap: .round, lineJoin: .round))
    }
}

private struct WidgetProgressBar: View {
    let progress: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color.opacity(0.2))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, g.size.width * CGFloat(min(max(progress, 0), 1))))
            }
        }
    }
}

struct SeasonWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    /// Plný barevný režim vs. accented (Liquid Glass / tinted) – systém v accented odstraní pozadí a nahradí sklem/tintem.
    @Environment(\.widgetRenderingMode) var widgetRenderingMode
    var entry: SeasonWidgetEntry

    private var secondaryText: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    /// Pozadí v containerBackground – systém ho v režimu Clear/Tinted odstraní a nahradí Liquid Glass / tintem.
    private var widgetGradient: LinearGradient {
        let base = colorScheme == .dark
            ? Color(white: 0.18).opacity(0.82)
            : Color.white.opacity(0.78)
        let tint = entry.progress.season.accentColor.opacity(colorScheme == .dark ? 0.16 : 0.12)
        return LinearGradient(
            colors: [base, tint],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryCircular:
                AccessoryCircularView(entry: entry)
            case .accessoryRectangular:
                AccessoryRectangularView(entry: entry)
            case .accessoryInline:
                AccessoryInlineView(entry: entry)
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            widgetGradient
        }
        .widgetURL(URL(string: "seaso4://season"))
    }

    private var smallView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let padH: CGFloat = 0
            let padTop: CGFloat = -10
            let widgetTopInset: CGFloat = 0
            let lineW: CGFloat = max(6, (min(w, h) - padH * 2) * 0.08)
            let size = min(w, h) - padH * 2 - lineW
            let arcHeight = size * 0.7 + lineW * 0.2
            VStack(spacing: 4) {
                // Název období + emoji nahoře na vlastním řádku, s rozestupem mezi písmeny
                HStack(spacing: 5) {
                    Text(entry.progress.season.emoji)
                        .font(.system(size: 12))
                    Text(entry.progress.season.displayName.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(2)
                        .foregroundColor(secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(width: size + lineW, height: arcHeight)
                        .overlay(alignment: .top) {
                            ZStack {
                                Circle()
                                    .trim(from: 0.5, to: 1.0)
                                    .stroke(entry.progress.season.accentColor.opacity(0.25), style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round))
                                Circle()
                                    .trim(from: 0.5, to: 0.5 + 0.5 * min(max(entry.progress.progress, 0), 1))
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                entry.progress.season.accentColor.opacity(0.4),
                                                entry.progress.season.accentColor
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ),
                                        style: StrokeStyle(lineWidth: lineW, lineCap: .round, lineJoin: .round)
                                    )
                            }
                            .frame(width: size, height: size)
                            .offset(y: lineW * 0.55)
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                    VStack(spacing: 2) {
                        if entry.showPercent {
                            Text("\(Int(entry.progress.progress * 100))%")
                                .font(.system(size: min(34, size * 0.36), weight: .bold))
                            Text("\(entry.progress.remainingDays) days left")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(secondaryText)
                        } else {
                            Text("\(entry.progress.remainingDays)")
                                .font(.system(size: min(34, size * 0.36), weight: .bold))
                            Text("days left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(secondaryText)
                                .padding(.top, -5)
                                .padding(.bottom, 0)
                            Text("\(Int(entry.progress.progress * 100))%")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(secondaryText)
                                .padding(.top, 0)
                                .padding(.bottom, -10)
                        }
                    }
                    .padding(.top,0)
                    .padding(.bottom, 0)
                    .widgetAccentable()
                }
                .frame(height: arcHeight + 26)
                
                if entry.showDaylight, let sunrise = entry.sunriseText, let sunset = entry.sunsetText {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "sunrise.fill")
                                .font(.system(size: 9))
                            Text(sunrise)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(secondaryText)
                        Spacer(minLength: 0)
                        HStack(spacing: 4) {
                            Image(systemName: "sunset.fill")
                                .font(.system(size: 9))
                            Text(sunset)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(secondaryText)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, padTop + widgetTopInset)
            .padding(.horizontal, padH)
            .padding(.bottom, padH)
        }
    }

    private var mediumView: some View {
        VStack(alignment: .center, spacing: 8) {
            // Název období + emoji na vlastním řádku nahoře, s rozestupem mezi písmeny
            HStack(spacing: 6) {
                Text(entry.progress.season.emoji)
                    .font(.subheadline)
                Text(entry.progress.season.displayName.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(3)
                    .foregroundColor(secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            VStack(spacing: 2) {
                if entry.showPercent {
                    Text("\(Int(entry.progress.progress * 100))%")
                        .font(.system(size: 40, weight: .bold))
                    Text("\(entry.progress.remainingDays) days left")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(secondaryText)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(entry.progress.remainingDays)")
                            .font(.system(size: 40, weight: .bold))
                        Text("days left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(secondaryText)
                    }
                    Text("\(Int(entry.progress.progress * 100))%")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .widgetAccentable()
            WidgetProgressBar(progress: entry.progress.progress, color: entry.progress.season.accentColor)
                .frame(height: 10)
                .clipShape(Capsule())
                .widgetAccentable()
            
            if entry.showDaylight, let sunrise = entry.sunriseText, let sunset = entry.sunsetText {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sunrise.fill")
                            .font(.caption2)
                        Text(sunrise)
                            .font(.caption2)
                    }
                    .foregroundColor(secondaryText)
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        Image(systemName: "sunset.fill")
                            .font(.caption2)
                        Text(sunset)
                            .font(.caption2)
                    }
                    .foregroundColor(secondaryText)
                }
            }
            HStack(spacing: 10) {
                if entry.showPercent {
                    Text("complete")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                } else {
                    Text("days left")
                        .font(.caption)
                        .foregroundColor(secondaryText)
                }
                HStack(spacing: 10) {
                    Label("\(entry.progress.elapsedDays)", systemImage: "clock")
                    Label("\(entry.progress.remainingDays) left", systemImage: "hourglass")
                }
                .font(.caption2)
                .foregroundColor(secondaryText)
            }
        }
        .padding(16)
    }

}

// MARK: - Lock Screen / StandBy views

private struct AccessoryCircularView: View {
    let entry: SeasonWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(entry.progress.season.emoji)
                    .font(.system(size: 14))
                Text("\(Int(entry.progress.progress * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .widgetAccentable()
    }
}

private struct AccessoryRectangularView: View {
    let entry: SeasonWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(entry.progress.season.emoji)
                Text(entry.progress.season.displayName)
                    .font(.headline)
                    .widgetAccentable()
            }
            ProgressView(value: entry.progress.progress)
            if entry.showPercent {
                Text("\(Int(entry.progress.progress * 100))% — \(entry.progress.remainingDays) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(entry.progress.remainingDays) days left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AccessoryInlineView: View {
    let entry: SeasonWidgetEntry

    var body: some View {
        Text("\(entry.progress.season.emoji) \(Int(entry.progress.progress * 100))% — \(entry.progress.remainingDays)d left")
    }
}

// MARK: - Widget bundle

struct Seaso4Widget: Widget {
    let kind: String = "Seaso4Widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SeasonWidgetProvider()) { entry in
            SeasonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Season Progress")
        .description("Shows progress through the current season (astronomical or calendar).")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Widget bundle (entry point for extension)

@main
struct Seaso4WidgetBundle: WidgetBundle {
    var body: some Widget {
        Seaso4Widget()
    }
}

#Preview(as: .systemSmall) {
    Seaso4Widget()
} timeline: {
    let season = WidgetSeasonCalculator.shared.currentSeason()
    let progress = WidgetSeasonCalculator.shared.astronomicalProgress(for: season, date: Date())
    let daylight = SeasonWidgetProvider().makeDaylightStrings(for: Date())
    SeasonWidgetEntry(
        date: Date(),
        progress: progress,
        isCalendarDefinition: false,
        displayedSeason: season,
        showPercent: false,
        showDaylight: false,
        sunriseText: daylight.sunrise,
        sunsetText: daylight.sunset
    )
}
