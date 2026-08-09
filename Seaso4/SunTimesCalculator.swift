import Foundation

/// Přesný výpočet východu a západu slunce podle polohy a data (NOAA).
enum SunTimesCalculator {
    /// Unix epoch = JD 2440587.5
    private static let jdUnixEpoch = 2440587.5

    /// Vypočte časy východu a západu slunce pro dané datum a souřadnice.
    /// Vrácené Date jsou okamžiky v UTC; při formátování v lokální časové zóně vyjdou správné časy.
    static func sunriseSunset(latitude: Double, longitude: Double, date: Date) -> (sunrise: Date, sunset: Date)? {
        let calendar = Calendar.current
        let comp = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comp.year, let month = comp.month, let day = comp.day else { return nil }

        // JD pro poledne UTC daného dne (konvence J2000.0 = 2451545.0 je noon 2000-01-01)
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

        if cosOmega <= -1 { return nil }
        if cosOmega >= 1 { return nil }

        let omega = acos(cosOmega) * 180 / .pi
        let jRise = jTransit - omega / 360.0
        let jSet = jTransit + omega / 360.0

        let rise = Date(timeIntervalSince1970: (jRise - jdUnixEpoch) * 86400)
        let set = Date(timeIntervalSince1970: (jSet - jdUnixEpoch) * 86400)
        return (rise, set)
    }

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = y / 100
        let b = 2 - a + a / 4
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + Double(b) - 1524.5
    }
}
