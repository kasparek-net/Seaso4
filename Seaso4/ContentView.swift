import SwiftUI
import WidgetKit

// MARK: - App Group (shared with widget)

private enum AppGroup {
    static let suiteName = "group.jk.Seaso4"
    /// Jedna sdílená instance – stejný store pro @AppStorage i pro zápis před refresh widgetů.
    static let store: UserDefaults? = UserDefaults(suiteName: suiteName)
    
    static func refreshWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "Seaso4Widget")
    }
}


// MARK: - Model ročních období

enum Season: String, CaseIterable {
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

    var next: Season {
        let all = Season.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + 1) % all.count]
    }

    var previous: Season {
        let all = Season.allCases
        let i = all.firstIndex(of: self) ?? 0
        return all[(i + all.count - 1) % all.count]
    }

    var seasonColor: Color {
        switch self {
        case .winter: return .blue
        case .spring: return .green
        case .summer: return .yellow
        case .autumn: return .orange
        }
    }

    var lightSeasonColor: Color {
        switch self {
        case .winter: return Color(red: 0.55, green: 0.55, blue: 1.0)
        case .spring: return Color(red: 0.55, green: 1.0, blue: 0.55)
        case .summer: return Color(red: 1.0, green: 1.0, blue: 0.55)
        case .autumn: return Color(red: 1.0, green: 0.78, blue: 0.55)
        }
    }
}

struct SeasonProgress {
    let season: Season
    let progress: Double      // 0.0 – 1.0
    let startDate: Date
    let endDate: Date
    let elapsedDays: Int
    let remainingDays: Int
}

// MARK: - Main display: astronomical vs calendar (meteorological)

enum SeasonDefinition: String, CaseIterable, Identifiable {
    case astronomical
    case calendar

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .astronomical: return "Astronomical"
        case .calendar: return "Calendar"
        }
    }
}

// MARK: - Výpočet sezóny (zjednodušený)

final class SeasonCalculator {
    static let shared = SeasonCalculator()
    private init() {}
    
    /// Aktuální roční období podle astronomických hranic (jaro od 20.3., léto od 21.6., …).
    func currentSeasonAstronomical(date: Date = Date()) -> Season {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var comp = DateComponents()
            comp.year = y
            comp.month = m
            comp.day = d
            return calendar.date(from: comp)!
        }
        let winterStart = makeDate(year - 1, 12, 21)
        let springStart = makeDate(year, 3, 20)
        let summerStart = makeDate(year, 6, 21)
        let autumnStart = makeDate(year, 9, 23)
        let nextWinterStart = makeDate(year, 12, 21)
        switch date {
        case springStart..<summerStart: return .spring
        case summerStart..<autumnStart: return .summer
        case autumnStart..<nextWinterStart: return .autumn
        case winterStart..<springStart: return .winter
        default: return .winter
        }
    }
    
    /// Aktuální roční období podle kalendářních (meteorologických) hranic (jaro 1.3.–31.5., …).
    func currentSeasonCalendar(date: Date = Date()) -> Season {
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
    func currentSeason(useCalendarDefinition: Bool, date: Date = Date()) -> Season {
        useCalendarDefinition ? currentSeasonCalendar(date: date) : currentSeasonAstronomical(date: date)
    }
    
    func currentSeasonProgress(date: Date = Date()) -> SeasonProgress {
        let season = currentSeasonAstronomical(date: date)
        return seasonProgress(for: season, date: date)
    }
    
    /// Počet dní do začátku daného ročního období od zadaného data.
    func daysUntilSeasonStart(_ season: Season, from date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var comp = DateComponents()
            comp.year = y
            comp.month = m
            comp.day = d
            return calendar.date(from: comp)!
        }
        
        let targetStartThisYear: Date
        switch season {
        case .spring:
            targetStartThisYear = makeDate(year, 3, 20)
        case .summer:
            targetStartThisYear = makeDate(year, 6, 21)
        case .autumn:
            targetStartThisYear = makeDate(year, 9, 23)
        case .winter:
            targetStartThisYear = makeDate(year, 12, 21)
        }
        
        let startDate: Date
        if date <= targetStartThisYear {
            startDate = targetStartThisYear
        } else {
            // další rok
            let nextYearStart: Date
            switch season {
            case .spring:
                nextYearStart = makeDate(year + 1, 3, 20)
            case .summer:
                nextYearStart = makeDate(year + 1, 6, 21)
            case .autumn:
                nextYearStart = makeDate(year + 1, 9, 23)
            case .winter:
                nextYearStart = makeDate(year + 1, 12, 21)
            }
            startDate = nextYearStart
        }
        
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: startDate)).day ?? 0
        return max(diff, 0)
    }
    
    /// Výpočet průběhu pro konkrétní sezónu – používá stejná hraniční data.
    func seasonProgress(for season: Season, date: Date = Date()) -> SeasonProgress {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        
        func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var comp = DateComponents()
            comp.year = y
            comp.month = m
            comp.day = d
            return calendar.date(from: comp)!
        }
        
        let winterStart = makeDate(year - 1, 12, 21)
        let springStart = makeDate(year, 3, 20)
        let summerStart = makeDate(year, 6, 21)
        let autumnStart = makeDate(year, 9, 23)
        let nextWinterStart = makeDate(year, 12, 21)
        let nextSpringStart = makeDate(year + 1, 3, 20)
        
        let start: Date
        let end: Date
        
        switch season {
        case .spring:
            start = springStart; end = summerStart
        case .summer:
            start = summerStart; end = autumnStart
        case .autumn:
            start = autumnStart; end = nextWinterStart
        case .winter:
            // zima je přes rok
            if date < springStart {
                start = winterStart; end = springStart
            } else {
                start = nextWinterStart; end = nextSpringStart
            }
        }
        
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
        let elapsedRaw = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        let elapsed = min(max(elapsedRaw, 0), totalDays)
        let remaining = max(totalDays - elapsed, 0)
        let progress = Double(elapsed) / Double(totalDays)
        
        return SeasonProgress(
            season: season,
            progress: progress,
            startDate: start,
            endDate: end,
            elapsedDays: elapsed,
            remainingDays: remaining
        )
    }
    
    // MARK: - Calendar (meteorological) season dates
    // Calendar seasons: Winter Dec 1–Feb 28/29, Spring Mar 1–May 31, Summer Jun 1–Aug 31, Autumn Sep 1–Nov 30
    
    /// Returns calendar (meteorological) start and end for the same season instance as `seasonProgress(for:date:)`.
    func calendarSeasonDates(for season: Season, referenceDate: Date = Date()) -> (start: Date, end: Date) {
        let progress = seasonProgress(for: season, date: referenceDate)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: progress.startDate)
        
        func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
            var comp = DateComponents()
            comp.year = y
            comp.month = m
            comp.day = d
            return calendar.date(from: comp)!
        }
        
        func lastDayOfFebruary(year: Int) -> Date {
            var comp = DateComponents()
            comp.year = year
            comp.month = 3
            comp.day = 0 // day 0 of March = last day of February
            return calendar.date(from: comp)!
        }
        
        switch season {
        case .winter:
            return (makeDate(year, 12, 1), lastDayOfFebruary(year: year + 1))
        case .spring:
            return (makeDate(year, 3, 1), makeDate(year, 5, 31))
        case .summer:
            return (makeDate(year, 6, 1), makeDate(year, 8, 31))
        case .autumn:
            return (makeDate(year, 9, 1), makeDate(year, 11, 30))
        }
    }
    
    /// Progress for the given season using calendar (meteorological) boundaries.
    func calendarSeasonProgress(for season: Season, date: Date = Date()) -> SeasonProgress {
        let (start, end) = calendarSeasonDates(for: season, referenceDate: date)
        let calendar = Calendar.current
        let totalDays = max(calendar.dateComponents([.day], from: start, to: end).day ?? 1, 1)
        let elapsedRaw = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        let elapsed = min(max(elapsedRaw, 0), totalDays)
        let remaining = max(totalDays - elapsed, 0)
        let progress = Double(elapsed) / Double(totalDays)
        return SeasonProgress(
            season: season,
            progress: progress,
            startDate: start,
            endDate: end,
            elapsedDays: elapsed,
            remainingDays: remaining
        )
    }
    
    /// Days until the calendar (meteorological) start of the given season.
    func daysUntilCalendarSeasonStart(_ season: Season, from date: Date = Date()) -> Int {
        let (start, _) = calendarSeasonDates(for: season, referenceDate: date)
        let calendar = Calendar.current
        let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: start)).day ?? 0
        return max(diff, 0)
    }
}

// MARK: - Date format for season dates (Calendar / Astronomical)

enum DateFormatStyle: String, CaseIterable, Identifiable {
    case european   // d. M. yyyy
    case american  // M/d/yyyy
    case iso       // yyyy-MM-dd
    case system    // Uses device locale (.medium)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .european: return "European (d. M. yyyy)"
        case .american: return "American (M/d/yyyy)"
        case .iso: return "ISO (yyyy-MM-dd)"
        case .system: return "System default"
        }
    }

    func apply(to formatter: DateFormatter) {
        formatter.locale = Locale.current
        switch self {
        case .european:
            formatter.dateFormat = "d. M. yyyy"
        case .american:
            formatter.dateFormat = "M/d/yyyy"
        case .iso:
            formatter.dateFormat = "yyyy-MM-dd"
        case .system:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
    }
}

// MARK: - Režim polohy (zatím jen UI)

enum LocationMode: String, CaseIterable, Identifiable {
    case automatic
    case manual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .manual:    return "Manual"
        }
    }
}

// MARK: - Přednastavené lokace pro sezóny (zatím jen UI)

struct PresetLocation: Identifiable, Hashable {
    let id: String
    let name: String
    let flag: String
    let latitude: Double
    let longitude: Double
    /// IANA time zone identifier for formatting sunrise/sunset in this location's local time.
    let timeZoneIdentifier: String
    let seasons: [Season]
    
    static let all: [PresetLocation] = [
        .init(id: "prague", name: "Prague, Czechia", flag: "🇨🇿", latitude: 50.0755, longitude: 14.4378, timeZoneIdentifier: "Europe/Prague", seasons: [.winter]),
        .init(id: "oslo", name: "Oslo, Norway", flag: "🇳🇴", latitude: 59.9139, longitude: 10.7522, timeZoneIdentifier: "Europe/Oslo", seasons: [.winter]),
        .init(id: "newyork", name: "New York, USA", flag: "🇺🇸", latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York", seasons: [.winter]),
        .init(id: "tokyo", name: "Tokyo, Japan", flag: "🇯🇵", latitude: 35.6762, longitude: 139.6503, timeZoneIdentifier: "Asia/Tokyo", seasons: [.spring]),
        .init(id: "paris", name: "Paris, France", flag: "🇫🇷", latitude: 48.8566, longitude: 2.3522, timeZoneIdentifier: "Europe/Paris", seasons: [.spring]),
        .init(id: "barcelona", name: "Barcelona, Spain", flag: "🇪🇸", latitude: 41.3851, longitude: 2.1734, timeZoneIdentifier: "Europe/Madrid", seasons: [.summer]),
        .init(id: "santorini", name: "Santorini, Greece", flag: "🇬🇷", latitude: 36.3932, longitude: 25.4615, timeZoneIdentifier: "Europe/Athens", seasons: [.summer]),
        .init(id: "kyoto", name: "Kyoto, Japan", flag: "🇯🇵", latitude: 35.0116, longitude: 135.7681, timeZoneIdentifier: "Asia/Tokyo", seasons: [.autumn]),
        .init(id: "vancouver", name: "Vancouver, Canada", flag: "🇨🇦", latitude: 49.2827, longitude: -123.1207, timeZoneIdentifier: "America/Vancouver", seasons: [.autumn]),
        .init(id: "sydney", name: "Sydney, Australia", flag: "🇦🇺", latitude: -33.8688, longitude: 151.2093, timeZoneIdentifier: "Australia/Sydney", seasons: [.summer, .winter]),
        .init(id: "buenosaires", name: "Buenos Aires, Argentina", flag: "🇦🇷", latitude: -34.6037, longitude: -58.3816, timeZoneIdentifier: "America/Argentina/Buenos_Aires", seasons: [.summer, .winter])
    ]
    
    static func presets(for season: Season) -> [PresetLocation] {
        let result = all.filter { $0.seasons.contains(season) }
        return result.isEmpty ? all : result
    }
}

// MARK: - Půlkruhový progress (SwiftUI trim = jen část tmavě, oba konce zakulacené)

struct SeasonProgressRing: View {
    let progress: Double
    let color: Color
    var lightColor: Color = .white

    private let lineWidth: CGFloat = 20

    var body: some View {
        let progressClamped = min(max(progress, 0), 1)
        Circle()
            .trim(from: 0.5, to: 0.5 + 0.5 * progressClamped)
            .stroke(
                LinearGradient(colors: [lightColor, color], startPoint: .bottom, endPoint: .topLeading),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
    }
}

struct SeasonProgressRingTrack: View {
    let color: Color
    
    private let lineWidth: CGFloat = 20
    
    var body: some View {
        Circle()
            .trim(from: 0.5, to: 1.0)
            .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}

// MARK: - Calendar vs astronomical dates (starts + ends; for future seasons shows when they start)

struct SeasonDatesBlock: View {
    @Environment(\.colorScheme) private var colorScheme
    let season: Season
    let seasonProgress: SeasonProgress
    let endDateFormatter: DateFormatter
    /// Which definition is currently used for the main display – this line will be shown bold.
    let activeDefinition: SeasonDefinition
    
    private var calendarDates: (start: Date, end: Date) {
        SeasonCalculator.shared.calendarSeasonDates(for: season, referenceDate: Date())
    }
    
    var body: some View {
        let now = Date()
        let calendarText: String = {
            if now < calendarDates.start {
                // Období ještě nezačalo – zobraz "starts …, ends …"
                return "Calendar \(season.displayName) starts \(endDateFormatter.string(from: calendarDates.start)), ends \(endDateFormatter.string(from: calendarDates.end))"
            } else if now < calendarDates.end {
                // Období právě běží – pro kalendářní zobrazení ukaž jen kdy končí
                return "Calendar \(season.displayName) ends \(endDateFormatter.string(from: calendarDates.end))"
            } else {
                // Období už skončilo – ukaž, kdy skončilo
                return "Calendar \(season.displayName) ended \(endDateFormatter.string(from: calendarDates.end))"
            }
        }()
        let astroText: String = {
            if now < seasonProgress.startDate {
                return "Astronomical \(season.displayName) starts \(endDateFormatter.string(from: seasonProgress.startDate)), ends \(endDateFormatter.string(from: seasonProgress.endDate))"
            } else if now < seasonProgress.endDate {
                return "Astronomical \(season.displayName) ends \(endDateFormatter.string(from: seasonProgress.endDate))"
            } else {
                return "Astronomical \(season.displayName) ended \(endDateFormatter.string(from: seasonProgress.endDate))"
            }
        }()
        let calendarRow = HStack(alignment: .top, spacing: 8) {
            Image(systemName: "calendar")
                .foregroundColor(.secondary)
            Text(calendarText)
                .font(.subheadline.weight(activeDefinition == .calendar ? .semibold : .regular))
                .foregroundColor(.secondary)
        }
        let astroRow = HStack(alignment: .top, spacing: 8) {
            Image(systemName: "globe.americas.fill")
                .foregroundColor(.secondary)
            Text(astroText)
                .font(.subheadline.weight(activeDefinition == .astronomical ? .semibold : .regular))
                .foregroundColor(.secondary)
        }
        VStack(alignment: .leading, spacing: 10) {
            if activeDefinition == .calendar {
                calendarRow
                astroRow
            } else {
                astroRow
                calendarRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Hlavní obsah aplikace

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var selectedSeason: Season = .winter
    @State private var selectedTab: Int = 0
    @State private var showFullLocationList = false
    @AppStorage("locationMode", store: AppGroup.store) private var locationMode: String = LocationMode.automatic.rawValue
    @AppStorage("daylightPresetId", store: AppGroup.store) private var daylightPresetId: String = "prague"
    @AppStorage("mainSeasonDefinition", store: AppGroup.store) private var mainSeasonDefinition: String = SeasonDefinition.calendar.rawValue
    @AppStorage("widgetSeason", store: AppGroup.store) private var widgetSeason: String = "current"
    /// "percent" or "days" – main card and widget show either % or days prominently
    @AppStorage("displayMode", store: AppGroup.store) private var displayMode: String = "percent"
    /// Show sunrise & sunset info in the app and widgets.
    @AppStorage("showDaylight", store: AppGroup.store) private var showDaylight: Bool = false
    @AppStorage("dateFormatStyle", store: AppGroup.store) private var dateFormatStyle: String = DateFormatStyle.system.rawValue

    @StateObject private var locationManager = LocationManager.shared
    private var currentSeason: Season {
        SeasonCalculator.shared.currentSeason(useCalendarDefinition: effectiveDefinition == .calendar)
    }
    
    private var seasonProgress: SeasonProgress {
        SeasonCalculator.shared.seasonProgress(for: selectedSeason)
    }
    
    private var effectiveDefinition: SeasonDefinition {
        SeasonDefinition(rawValue: mainSeasonDefinition) ?? .calendar
    }
    
    /// Main progress shown in the card (astronomical or calendar based on settings).
    private var mainProgress: SeasonProgress {
        switch effectiveDefinition {
        case .astronomical: return seasonProgress
        case .calendar: return SeasonCalculator.shared.calendarSeasonProgress(for: selectedSeason)
        }
    }
    
    private var endDateFormatter: DateFormatter {
        Self.cachedEndDateFormatter(for: DateFormatStyle(rawValue: dateFormatStyle) ?? .system)
    }

    private static var _endDateFormatterCache: (style: DateFormatStyle, formatter: DateFormatter)?
    private static func cachedEndDateFormatter(for style: DateFormatStyle) -> DateFormatter {
        if let cached = _endDateFormatterCache, cached.style == style {
            return cached.formatter
        }
        let f = DateFormatter()
        style.apply(to: f)
        _endDateFormatterCache = (style, f)
        return f
    }
    
    private var effectiveLocationMode: LocationMode {
        LocationMode(rawValue: locationMode) ?? .automatic
    }

    private var selectedPresetLocation: PresetLocation? {
        PresetLocation.all.first { $0.id == daylightPresetId } ?? PresetLocation.all.first { $0.id == "prague" }
    }

    /// Souřadnice pro východ/západ podle nastavení Location (Automatic / Manual / Off).
    private var effectiveCoordinateForDaylight: (lat: Double, lon: Double) {
        switch effectiveLocationMode {
        case .automatic:
            return locationManager.coordinateForDaylight
        case .manual:
            if let p = selectedPresetLocation { return (p.latitude, p.longitude) }
            return (50.0755, 14.4378)
        }
    }

    /// Přesné časy východu a západu slunce pro dnešek podle polohy (NOAA).
    /// Formátuje v časové zóně vybrané lokace (u manuální předvolby), jinak v časové zóně zařízení.
    private static var _timeFormatterCache: (tzId: String?, formatter: DateFormatter)?
    private static func cachedTimeFormatter(timeZoneId: String?) -> DateFormatter {
        if let cached = _timeFormatterCache, cached.tzId == timeZoneId { return cached.formatter }
        let tf = DateFormatter()
        tf.locale = Locale.current
        tf.timeStyle = .short
        if let id = timeZoneId, let tz = TimeZone(identifier: id) { tf.timeZone = tz }
        _timeFormatterCache = (timeZoneId, tf)
        return tf
    }

    private var daylightTimes: (sunrise: String, sunset: String)? {
        guard showDaylight else { return nil }
        let (lat, lon) = effectiveCoordinateForDaylight
        let today = Calendar.current.startOfDay(for: Date())
        guard let times = SunTimesCalculator.sunriseSunset(latitude: lat, longitude: lon, date: today) else { return nil }
        let tzId = (effectiveLocationMode == .manual) ? selectedPresetLocation?.timeZoneIdentifier : nil
        let tf = Self.cachedTimeFormatter(timeZoneId: tzId)
        return (tf.string(from: times.sunrise), tf.string(from: times.sunset))
    }
    
    private var daysUntilSelectedSeasonStarts: Int {
        switch effectiveDefinition {
        case .astronomical: return SeasonCalculator.shared.daysUntilSeasonStart(selectedSeason)
        case .calendar: return SeasonCalculator.shared.daysUntilCalendarSeasonStart(selectedSeason)
        }
    }

    /// Zapíše všechna nastavení viditelná ve widgetu do App Group a vynutí zápis na disk (klíče musí odpovídat widgetu).
    /// Volitelně lze předat právě změněnou hodnotu (kvůli timing @AppStorage), aby se nezapsala stará.
    private func syncWidgetSettingsToStore(mainSeasonDefinitionOverride: String? = nil, displayModeOverride: String? = nil, showDaylightOverride: Bool? = nil, widgetSeasonOverride: String? = nil) {
        guard let store = AppGroup.store else { return }
        store.set(mainSeasonDefinitionOverride ?? mainSeasonDefinition, forKey: "mainSeasonDefinition")
        store.set(widgetSeasonOverride ?? widgetSeason, forKey: "widgetSeason")
        store.set(displayModeOverride ?? displayMode, forKey: "displayMode")
        store.set(showDaylightOverride ?? showDaylight, forKey: "showDaylight")
        store.set(dateFormatStyle, forKey: "dateFormatStyle")
        store.set(locationMode, forKey: "locationMode")
        store.set(daylightPresetId, forKey: "daylightPresetId")
        if effectiveLocationMode == .manual, let preset = selectedPresetLocation {
            store.set(preset.timeZoneIdentifier, forKey: "daylightTimeZoneId")
        } else {
            store.removeObject(forKey: "daylightTimeZoneId")
        }
    }

    private func selectPresetLocation(_ preset: PresetLocation) {
        locationMode = LocationMode.manual.rawValue
        daylightPresetId = preset.id
        AppGroup.store?.set(preset.latitude, forKey: "daylightLat")
        AppGroup.store?.set(preset.longitude, forKey: "daylightLon")
        AppGroup.store?.set(preset.timeZoneIdentifier, forKey: "daylightTimeZoneId")
        syncWidgetSettingsToStore()
        AppGroup.refreshWidgets()
    }

    /// Obnoví všechna nastavení (včetně sdílených s widgetem) na výchozí a vynutí aktualizaci widgetů.
    private func resetAllSettings() {
        locationMode = LocationMode.automatic.rawValue
        daylightPresetId = "prague"
        mainSeasonDefinition = SeasonDefinition.astronomical.rawValue
        widgetSeason = "current"
        displayMode = "percent"
        showDaylight = false
        dateFormatStyle = DateFormatStyle.system.rawValue
        AppGroup.store?.set(50.0755, forKey: "daylightLat")
        AppGroup.store?.set(14.4378, forKey: "daylightLon")
        syncWidgetSettingsToStore()
        AppGroup.refreshWidgets()
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Season", systemImage: "circle.dashed.inset.filled", value: 0) {
                ScrollView {
                    VStack {
                        mainCard
                            .padding(.horizontal, 8)
                            .padding(.top, 16)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 40)
                                    .onEnded { value in
                                        let w = value.translation.width
                                        let h = value.translation.height
                                        guard abs(w) > abs(h), abs(w) > 60 else { return }
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if w < 0 {
                                                selectedSeason = selectedSeason.next
                                            } else {
                                                selectedSeason = selectedSeason.previous
                                            }
                                        }
                                    }
                            )

                        Spacer(minLength: 20)
                    }
                }
                .background(seasonMeshGradient.ignoresSafeArea())
            }

            Tab("Settings", systemImage: "gearshape", value: 1) {
                settingsFormView
                    .background(seasonMeshGradient.ignoresSafeArea())
            }
        }
        .onChange(of: mainSeasonDefinition) { _, newValue in
            selectedSeason = SeasonCalculator.shared.currentSeason(useCalendarDefinition: SeasonDefinition(rawValue: newValue) == .calendar)
            syncWidgetSettingsToStore(mainSeasonDefinitionOverride: newValue)
            AppGroup.refreshWidgets()
        }
        .onChange(of: widgetSeason) { _, newValue in
            syncWidgetSettingsToStore(widgetSeasonOverride: newValue)
            AppGroup.refreshWidgets()
        }
        .onChange(of: displayMode) { _, newValue in
            syncWidgetSettingsToStore(displayModeOverride: newValue)
            AppGroup.refreshWidgets()
        }
        .onChange(of: showDaylight) { _, newValue in
            syncWidgetSettingsToStore(showDaylightOverride: newValue)
            AppGroup.refreshWidgets()
        }
        .onAppear {
            selectedSeason = currentSeason
            if showDaylight { locationManager.requestLocationIfNeeded() }
        }
        .sheet(isPresented: $showFullLocationList) {
            NavigationStack {
                List(PresetLocation.all) { preset in
                    Button {
                        selectPresetLocation(preset)
                        showFullLocationList = false
                    } label: {
                        HStack(spacing: 12) {
                            Text(preset.flag)
                                .font(.title2)
                            Text(preset.name)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .navigationTitle("Choose location")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showFullLocationList = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Podklady UI

    private var seasonColor: Color {
        seasonProgress.season.seasonColor
    }

    private static let meshPoints: [SIMD2<Float>] = [
        [0, 0], [0.5, 0], [1, 0],
        [0, 0.5], [0.5, 0.5], [1, 0.5],
        [0, 1], [0.5, 1], [1, 1]
    ]

    private var seasonMeshGradient: some View {
        let base: Color = colorScheme == .dark ? Color(white: 0.06) : Color(white: 0.96)
        let tint = seasonColor.opacity(colorScheme == .dark ? 0.25 : 0.15)
        let tint2 = seasonColor.opacity(colorScheme == .dark ? 0.12 : 0.08)
        return MeshGradient(width: 3, height: 3, points: Self.meshPoints, colors: [
            base, tint2, base,
            tint2, tint, tint2,
            base, tint2, base
        ])
        .animation(.easeInOut(duration: 0.8), value: selectedSeason)
    }

    // MARK: - Glass modifier

    
    private var mainCard: some View {
        VStack(spacing: 24) {
            // Přepínač ročních období – bez rámečku, na okrajích dozní gradientem
            let isLandscape = verticalSizeClass == .compact
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            if isLandscape { Spacer(minLength: 0) }
                            HStack(spacing: 8) {
                                ForEach(Season.allCases.filter { $0 != selectedSeason }, id: \.self) { season in
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            selectedSeason = season
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(season.emoji)
                                            Text(season.displayName)
                                                .font(.subheadline.weight(.semibold))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .glassEffect(.regular.interactive(), in: .capsule)
                                        .foregroundColor(.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minWidth: isLandscape ? geo.size.width : nil)
                        .padding(.horizontal, 16)
                    }
                }
            }
            .frame(height: 44)
            .padding(.vertical, 4)
            
            // Ikona + název sezóny
            VStack(spacing: 8) {
                Text(seasonProgress.season.emoji)
                    .font(.system(size: 32))
                
                Text(seasonProgress.season.displayName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(seasonColor)
            }
            .padding(.top, 8)
            
            // Půlkruhový progress – procenta přímo pod obloukem „do zákrytu"
            ZStack(alignment: .bottom) {
                Color.clear
                    .frame(width: 250, height: 165)
                    .overlay(alignment: .top) {
                        ZStack(alignment: .top) {
                            SeasonProgressRingTrack(color: seasonColor)
                                .frame(width: 220, height: 280)
                            SeasonProgressRing(progress: mainProgress.progress, color: seasonColor, lightColor: seasonProgress.season.lightSeasonColor)
                                .frame(width: 220, height: 280)
                        }
                        .offset(y: -8)
                    }
                    .clipped()
                VStack(spacing: 4) {
                    if displayMode == "days" {
                        Text("\(selectedSeason == currentSeason ? mainProgress.remainingDays : daysUntilSelectedSeasonStarts)")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.primary)
                        Text(selectedSeason == currentSeason ? "days left" : "days until start")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(Int(mainProgress.progress * 100))%")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.primary)
                        Text("complete")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(height: 145)
            .padding(.vertical, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(seasonProgress.season.displayName) season, \(Int(mainProgress.progress * 100)) percent complete, \(mainProgress.remainingDays) days remaining")
            
            // Days info – current season vs future (main = astronomical or calendar from settings)
            if selectedSeason == currentSeason {
                HStack(spacing: 16) {
                    smallStatCard(
                        title: "Days Elapsed",
                        value: mainProgress.elapsedDays,
                        systemImage: "clock"
                    )
                    smallStatCard(
                        title: "Days Left",
                        value: mainProgress.remainingDays,
                        systemImage: "hourglass"
                    )
                }
            } else {
                HStack(spacing: 16) {
                    smallStatCard(
                        title: "Starts in",
                        value: daysUntilSelectedSeasonStarts,
                        systemImage: "forward.end"
                    )
                    smallStatCard(
                        title: "Season length",
                        value: mainProgress.elapsedDays + mainProgress.remainingDays,
                        systemImage: "calendar"
                    )
                }
            }
            
            Divider()
                .padding(.horizontal, 8)
            
            if let daylight = daylightTimes {
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sunrise.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sunrise")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(daylight.sunrise)
                                .font(.subheadline)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Image(systemName: "sunset.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sunset")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(daylight.sunset)
                                .font(.subheadline)
                        }
                    }
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sunrise \(daylight.sunrise), Sunset \(daylight.sunset)")
            }

            // Calendar vs astronomical: starts and ends (different dates)
            SeasonDatesBlock(
                season: seasonProgress.season,
                seasonProgress: seasonProgress,
                endDateFormatter: endDateFormatter,
                activeDefinition: effectiveDefinition
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .padding(24)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 28))
    }
    
    private func smallStatCard(title: String, value: Int, systemImage: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value) days")
    }

    // MARK: - Settings (Form with native glass)

    private var settingsFormView: some View {
        Form {
            Section {
                Picker("Season definition", selection: $mainSeasonDefinition) {
                    ForEach(SeasonDefinition.allCases) { definition in
                        Text(definition.displayName).tag(definition.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Main season display")
            } footer: {
                Text("Choose how season progress is calculated.")
            }

            Section {
                Picker("Primary display", selection: $displayMode) {
                    Text("Percentage").tag("percent")
                    Text("Days").tag("days")
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Primary display")
            } footer: {
                Text("Shown prominently on the Season tab and widget.")
            }

            Section {
                Picker("Date format", selection: $dateFormatStyle) {
                    ForEach(DateFormatStyle.allCases) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
            } header: {
                Text("Date format")
            }

            Section {
                Toggle("Show sunrise & sunset", isOn: $showDaylight)
                    .tint(seasonColor)

                Picker("Location", selection: Binding(
                    get: { effectiveLocationMode },
                    set: { new in
                        locationMode = new.rawValue
                        if new == .automatic, showDaylight {
                            locationManager.requestLocationIfNeeded()
                        }
                        syncWidgetSettingsToStore()
                        AppGroup.refreshWidgets()
                    }
                )) {
                    ForEach(LocationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if effectiveLocationMode == .manual {
                    if let preset = selectedPresetLocation {
                        HStack {
                            Text(preset.flag)
                            Text(preset.name)
                            Spacer()
                        }
                        .foregroundColor(.secondary)
                    }

                    Button {
                        showFullLocationList = true
                    } label: {
                        Label("Choose location", systemImage: "mappin.and.ellipse")
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PresetLocation.presets(for: selectedSeason)) { preset in
                                Button {
                                    selectPresetLocation(preset)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(preset.flag)
                                        Text(preset.name)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .glassEffect(.regular, in: .capsule)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            } header: {
                Text("Daylight")
            }

            Section {
                Picker("Widget season", selection: $widgetSeason) {
                    Text("Current season").tag("current")
                    ForEach(Season.allCases, id: \.rawValue) { season in
                        Text(season.displayName).tag(season.rawValue)
                    }
                }

                Button {
                    syncWidgetSettingsToStore()
                    AppGroup.refreshWidgets()
                } label: {
                    Label("Refresh widget now", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Widget")
            } footer: {
                Text("iOS may delay widget updates to save battery.")
            }

            KasparekSignatureSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.light)
}

