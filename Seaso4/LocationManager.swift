import Foundation
import CoreLocation
import Combine

/// Ukládá reprezentativní polohu (stát/země) do App Group pro výpočet východu/západu slunce.
/// Z bezpečnostních důvodů neukládá přesné souřadnice, pouze zjištěnou zemi a její reprezentativní bod.
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private static let appGroupSuiteName = "group.jk.Seaso4"
    private var store: UserDefaults? { UserDefaults(suiteName: Self.appGroupSuiteName) }

    static let defaultLatitude = 50.0755
    static let defaultLongitude = 14.4378

    @Published private(set) var lastKnownCoordinate: CLLocationCoordinate2D?

    /// Reprezentativní souřadnice pro běžné země (střed/hlavní město) – používá se místo přesné polohy uživatele.
    private static let countryRepresentativeCoordinates: [String: (lat: Double, lon: Double)] = [
        "CZ": (50.0755, 14.4378),   // Praha
        "NO": (59.9139, 10.7522),   // Oslo
        "US": (39.8283, -98.5795),  // střed USA
        "JP": (35.6762, 139.6503), // Tokio
        "FR": (48.8566, 2.3522),    // Paříž
        "ES": (41.3851, 2.1734),    // Barcelona
        "GR": (37.9838, 23.7275),   // Athény
        "CA": (43.6532, -79.3832),  // Toronto
        "AU": (-33.8688, 151.2093), // Sydney
        "AR": (-34.6037, -58.3816), // Buenos Aires
        "DE": (52.5200, 13.4050),   // Berlín
        "GB": (51.5074, -0.1278),   // Londýn
        "IT": (41.9028, 12.4964),   // Řím
        "PL": (52.2297, 21.0122),   // Varšava
        "AT": (48.2082, 16.3738),   // Vídeň
        "CH": (46.9480, 7.4474),    // Bern
        "NL": (52.3676, 4.9041),   // Amsterdam
        "BE": (50.8503, 4.3517),   // Brusel
        "PT": (38.7223, -9.1393),  // Lisabon
        "SE": (59.3293, 18.0686),  // Stockholm
        "DK": (55.6761, 12.5683),  // Kodaň
        "FI": (60.1695, 24.9354),   // Helsinky
        "IE": (53.3498, -6.2603),   // Dublin
        "SK": (48.1486, 17.1077),   // Bratislava
        "HU": (47.4979, 19.0402),   // Budapešť
        "RO": (44.4268, 26.1025),   // Bukurešť
        "BG": (42.6977, 23.3219),   // Sofie
        "HR": (45.8150, 15.9819),   // Záhřeb
        "RS": (44.0165, 21.0059),   // Bělehrad
        "UA": (50.4501, 30.5234),   // Kyjev
        "RU": (55.7558, 37.6173),   // Moskva
        "TR": (39.9334, 32.8597),   // Ankara
        "IL": (32.0853, 34.7818),   // Tel Aviv
        "IN": (28.6139, 77.2090),   // Nové Dillí
        "CN": (39.9042, 116.4074),  // Peking
        "KR": (37.5665, 126.9780),  // Soul
        "TH": (13.7563, 100.5018),  // Bangkok
        "MX": (19.4326, -99.1332),  // Ciudad de México
        "BR": (-23.5505, -46.6333), // São Paulo
        "CL": (-33.4489, -70.6693), // Santiago
        "CO": (4.7110, -74.0721),   // Bogotá
        "ZA": (-33.9249, 18.4241),  // Kapské město
        "EG": (30.0444, 31.2357),   // Káhira
        "NZ": (-36.8485, 174.7633), // Auckland
    ]

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadStored()
    }

    func requestLocationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    /// Souřadnice pro výpočet: uložené (reprezentativní pro zemi) nebo výchozí (Praha).
    var coordinateForDaylight: (lat: Double, lon: Double) {
        if let c = lastKnownCoordinate {
            return (c.latitude, c.longitude)
        }
        let lat = store?.double(forKey: "daylightLat") ?? Self.defaultLatitude
        let lon = store?.double(forKey: "daylightLon") ?? Self.defaultLongitude
        if lat != 0 || lon != 0 {
            return (lat, lon)
        }
        return (Self.defaultLatitude, Self.defaultLongitude)
    }

    private func loadStored() {
        let lat = store?.double(forKey: "daylightLat") ?? 0
        let lon = store?.double(forKey: "daylightLon") ?? 0
        if lat != 0 || lon != 0 {
            lastKnownCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    /// Uloží reprezentativní souřadnice pro zjištěnou zemi – nikdy přesnou polohu uživatele.
    private func saveRepresentativeForCountry(_ coordinate: CLLocationCoordinate2D) {
        geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), preferredLocale: Locale(identifier: "en_US")) { [weak self] placemarks, _ in
            guard let self = self else { return }
            let toSave: (lat: Double, lon: Double)
            if let countryCode = placemarks?.first?.isoCountryCode, !countryCode.isEmpty,
               let rep = Self.countryRepresentativeCoordinates[countryCode] {
                toSave = rep
            } else {
                // Pro neznámé země: zaokrouhlení na ~55 km (0.5°) – nepřesná lokace
                toSave = (
                    (coordinate.latitude * 2).rounded(.toNearestOrAwayFromZero) / 2,
                    (coordinate.longitude * 2).rounded(.toNearestOrAwayFromZero) / 2
                )
            }
            DispatchQueue.main.async {
                self.store?.set(toSave.lat, forKey: "daylightLat")
                self.store?.set(toSave.lon, forKey: "daylightLon")
                self.lastKnownCoordinate = CLLocationCoordinate2D(latitude: toSave.lat, longitude: toSave.lon)
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        saveRepresentativeForCountry(loc.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}
