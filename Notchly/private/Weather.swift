//
//  Weather.swift
//  Notchly
//
//  Weather for a city from Open-Meteo (free, no API key): now plus the next hours.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import Defaults
import SwiftUI

extension Defaults.Keys {
    static let weatherCity = Key<String>("weatherCity", default: "")
    static let weatherFahrenheit = Key<Bool>("weatherFahrenheit", default: false)
    /// The place found for `weatherResolvedFor`, so it is looked up once per city typed.
    static let weatherResolvedFor = Key<String>("weatherResolvedFor", default: "")
    static let weatherLatitude = Key<Double?>("weatherLatitude", default: nil)
    static let weatherLongitude = Key<Double?>("weatherLongitude", default: nil)
    static let weatherPlaceName = Key<String>("weatherPlaceName", default: "")
}

struct WeatherPlace: Equatable {
    let name: String
    let region: String
    let latitude: Double
    let longitude: Double

    /// "Panvel, India"
    var title: String { region.isEmpty ? name : "\(name), \(region)" }
}

struct HourForecast: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let code: Int
    /// Chance of rain, 0...100.
    let rainChance: Int
}

@MainActor
final class WeatherManager: ObservableObject {
    static let shared = WeatherManager()

    @Published private(set) var place = ""
    @Published private(set) var temperature: Double?
    @Published private(set) var code = 0
    @Published private(set) var isDay = true
    @Published private(set) var feelsLike = 0.0
    @Published private(set) var humidity = 0
    @Published private(set) var wind = 0.0
    @Published private(set) var high = 0.0
    @Published private(set) var low = 0.0
    @Published private(set) var hours: [HourForecast] = []
    @Published private(set) var error: String?

    private var lastFetch = Date.distantPast

    private struct Geocode: Decodable {
        struct Result: Decodable {
            let name: String
            let latitude: Double
            let longitude: Double
            let country: String?
            let country_code: String?
            let admin1: String?
        }
        let results: [Result]?
    }

    /// Finds the place a user typed. The lookup only matches a bare place name, so "Panvel, India" or "Pune,
    /// Maharashtra" would find nothing as typed: it tries the name as typed, then the part before a comma (the
    /// rest picks between places of the same name), then the name without accents.
    nonisolated static func resolve(_ input: String) async throws -> WeatherPlace? {
        let cleaned = input.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let parts = cleaned.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard let first = parts.first else { return nil }
        let hint = parts.dropFirst().joined(separator: " ").lowercased()

        var seen = Set<String>()
        for name in [cleaned, first, first.folding(options: .diacriticInsensitive, locale: nil)]
        where name.count >= 2 && seen.insert(name.lowercased()).inserted {
            var query = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
            query.queryItems = [
                .init(name: "name", value: name), .init(name: "count", value: "10"),
                .init(name: "language", value: "en"), .init(name: "format", value: "json"),
            ]
            let (data, _) = try await URLSession.shared.data(from: query.url!)
            let results = try JSONDecoder().decode(Geocode.self, from: data).results ?? []
            let matching = results.first { result in
                [result.country, result.country_code, result.admin1].compactMap { $0?.lowercased() }
                    .contains { !hint.isEmpty && ($0.contains(hint) || hint.contains($0)) }
            }
            if let found = hint.isEmpty ? results.first : (matching ?? results.first) {
                return WeatherPlace(
                    name: found.name, region: found.country ?? found.admin1 ?? "",
                    latitude: found.latitude, longitude: found.longitude)
            }
        }
        return nil
    }

    /// Remembers a place found for `city`, so the first forecast doesn't look it up again.
    static func remember(_ place: WeatherPlace, for city: String) {
        Defaults[.weatherResolvedFor] = city
        Defaults[.weatherLatitude] = place.latitude
        Defaults[.weatherLongitude] = place.longitude
        Defaults[.weatherPlaceName] = place.name
    }

    /// The place for the typed city, looked up once and remembered until the text changes.
    private func place(for city: String) async throws -> WeatherPlace? {
        if Defaults[.weatherResolvedFor] == city, let latitude = Defaults[.weatherLatitude], let longitude = Defaults[.weatherLongitude] {
            return WeatherPlace(name: Defaults[.weatherPlaceName], region: "", latitude: latitude, longitude: longitude)
        }
        guard let found = try await Self.resolve(city) else { return nil }
        Defaults[.weatherResolvedFor] = city
        Defaults[.weatherLatitude] = found.latitude
        Defaults[.weatherLongitude] = found.longitude
        Defaults[.weatherPlaceName] = found.name
        return found
    }

    private struct Forecast: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let apparent_temperature: Double
            let relative_humidity_2m: Int
            let wind_speed_10m: Double
            let weather_code: Int
            let is_day: Int
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double]
            let weather_code: [Int]
            let precipitation_probability: [Int?]
        }
        struct Daily: Decodable { let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
        let utc_offset_seconds: Int
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    func refresh(force: Bool = false) async {
        let city = Defaults[.weatherCity].trimmingCharacters(in: .whitespaces)
        guard !city.isEmpty else {
            error = "Set a city in Settings → Tools"
            return
        }
        guard force || Date().timeIntervalSince(lastFetch) > 900 else { return }
        do {
            guard let found = try await place(for: city) else {
                error = "Couldn't find \"\(city)\". Try the city name, or \"City, Country\"."
                return
            }
            var f = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            f.queryItems = [
                .init(name: "latitude", value: "\(found.latitude)"), .init(name: "longitude", value: "\(found.longitude)"),
                .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"),
                .init(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability"),
                .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
                .init(name: "wind_speed_unit", value: Defaults[.weatherFahrenheit] ? "mph" : "kmh"),
                .init(name: "forecast_days", value: "2"), .init(name: "timezone", value: "auto"),
                .init(name: "temperature_unit", value: Defaults[.weatherFahrenheit] ? "fahrenheit" : "celsius"),
            ]
            let (data, _) = try await URLSession.shared.data(from: f.url!)
            let forecast = try JSONDecoder().decode(Forecast.self, from: data)

            // Hourly times are local to the place, written without a zone
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            formatter.timeZone = TimeZone(secondsFromGMT: forecast.utc_offset_seconds)
            let cutoff = Date().addingTimeInterval(-1800)
            hours = forecast.hourly.time.indices
                .compactMap { i -> HourForecast? in
                    guard let date = formatter.date(from: forecast.hourly.time[i]) else { return nil }
                    return HourForecast(
                        date: date, temperature: forecast.hourly.temperature_2m[i], code: forecast.hourly.weather_code[i],
                        rainChance: forecast.hourly.precipitation_probability[i] ?? 0)
                }
                .filter { $0.date >= cutoff }
                .prefix(30).map { $0 }
            place = found.name
            temperature = forecast.current.temperature_2m
            code = forecast.current.weather_code
            isDay = forecast.current.is_day == 1
            feelsLike = forecast.current.apparent_temperature
            humidity = forecast.current.relative_humidity_2m
            wind = forecast.current.wind_speed_10m
            high = forecast.daily.temperature_2m_max.first ?? forecast.current.temperature_2m
            low = forecast.daily.temperature_2m_min.first ?? forecast.current.temperature_2m
            error = nil
            lastFetch = Date()
        } catch {
            self.error = "Couldn't load the weather"
        }
    }

    /// What the weather is, in words, for a WMO weather code.
    static func condition(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77, 85, 86: return "Snow"
        case 80...82: return "Showers"
        case 95...99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }

    /// The hero card's colours: the sky for this weather, by day or by night.
    static func sky(for code: Int, isDay: Bool) -> [Color] {
        switch code {
        case 0, 1: return isDay ? [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.95, green: 0.65, blue: 0.3)]
                                : [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.25, green: 0.2, blue: 0.5)]
        case 2, 3: return isDay ? [Color(red: 0.4, green: 0.5, blue: 0.65), Color(red: 0.6, green: 0.65, blue: 0.75)]
                                : [Color(red: 0.15, green: 0.17, blue: 0.25), Color(red: 0.3, green: 0.32, blue: 0.42)]
        case 45, 48: return [Color(white: 0.4), Color(white: 0.6)]
        case 51...67, 80...82: return [Color(red: 0.15, green: 0.3, blue: 0.55), Color(red: 0.35, green: 0.45, blue: 0.6)]
        case 71...77, 85, 86: return [Color(red: 0.5, green: 0.65, blue: 0.8), Color(red: 0.8, green: 0.87, blue: 0.95)]
        case 95...99: return [Color(red: 0.2, green: 0.15, blue: 0.4), Color(red: 0.4, green: 0.3, blue: 0.6)]
        default: return [Color(white: 0.3), Color(white: 0.5)]
        }
    }

    /// SF Symbol for a WMO weather code.
    static func symbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82: return "cloud.heavyrain.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

struct WeatherTabView: View {
    @ObservedObject private var weather = WeatherManager.shared

    var body: some View {
        Group {
            if weather.temperature != nil {
                // Sized from the space the notch gives this tab, so it can't grow past it
                GeometryReader { geo in
                    HStack(spacing: 10) {
                        hero.frame(width: 150, height: geo.size.height)
                        stats.frame(width: 98, height: geo.size.height)
                        hourly.frame(height: geo.size.height)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill").font(.title).symbolRenderingMode(.multicolor)
                    Text(weather.error ?? "Loading weather…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task { await weather.refresh() }
    }

    private func degrees(_ value: Double) -> String { "\(Int(value.rounded()))°" }

    /// The sky, the temperature and the high and low.
    private var hero: some View {
        let sky = WeatherManager.sky(for: weather.code, isDay: weather.isDay)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                TimelineView(.animation) { context in
                    Image(systemName: WeatherManager.symbol(for: weather.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 30))
                        .offset(y: 2.5 * sin(context.date.timeIntervalSinceReferenceDate * 1.6))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Label(degrees(weather.high), systemImage: "arrow.up")
                    Label(degrees(weather.low), systemImage: "arrow.down")
                }
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            Text(degrees(weather.temperature ?? 0))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(WeatherManager.condition(for: weather.code))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text(weather.place)
                .font(.caption2)
                .lineLimit(1)
                .opacity(0.8)
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(LinearGradient(colors: sky, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 0) {
            stat("thermometer.medium", "Feels like", degrees(weather.feelsLike))
            Spacer(minLength: 0)
            stat("humidity.fill", "Humidity", "\(weather.humidity)%")
            Spacer(minLength: 0)
            stat("wind", "Wind", "\(Int(weather.wind.rounded())) \(Defaults[.weatherFahrenheit] ? "mph" : "km/h")")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .notchCard(padding: 10)
        .clipped()
    }

    private func stat(_ icon: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Color.effectiveAccent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 9)).lineLimit(1).foregroundStyle(.secondary)
                Text(value).font(.callout.weight(.semibold)).minimumScaleFactor(0.8).lineLimit(1)
            }
        }
    }

    /// The next hours, with the chance of rain as a small bar under each.
    private func hourLabel(_ date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        return "\(hour % 12 == 0 ? 12 : hour % 12)\(hour < 12 ? "a" : "p")"
    }

    /// The next day, hour by hour. Scrolls sideways.
    private var hourly: some View {
        ScrollView(.horizontal) {
        HStack(spacing: 0) {
            ForEach(Array(weather.hours.enumerated()), id: \.element.id) { index, hour in
                VStack(spacing: 5) {
                    Text(index == 0 ? "Now" : hourLabel(hour.date))
                        .font(.caption)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(index == 0 ? Color.white : .secondary)
                    Image(systemName: WeatherManager.symbol(for: hour.code))
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 16))
                    Text(degrees(hour.temperature))
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .fixedSize()
                    VStack(spacing: 1) {
                        Capsule()
                            .fill(.white.opacity(0.12))
                            .frame(width: 5, height: 22)
                            .overlay(alignment: .bottom) {
                                Capsule().fill(.cyan).frame(width: 5, height: 22 * CGFloat(hour.rainChance) / 100)
                            }
                        Text("\(hour.rainChance)%").font(.system(size: 8)).lineLimit(1).fixedSize().foregroundStyle(.secondary)
                    }
                }
                .frame(width: 42)
                .frame(maxHeight: .infinity)
                .background(index == 0 ? Color.white.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        }
        .scrollIndicators(.hidden)
        // Fades the columns at the right edge so it's clear there is more
        .mask(
            HStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 22)
            })
        .notchCard(padding: 5)
        .clipped()
    }
}
