import Foundation
import SwiftUI

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case meters
    case steps

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .meters: return "Meters"
        case .steps:  return "Steps"
        }
    }

    /// Longueur moyenne d'un pas (m), utilisée pour la conversion pas ↔ mètres.
    static let metersPerStep = 0.762
}

enum SpeedUnit: String, CaseIterable, Identifiable, Codable {
    case kmh
    case mph

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kmh: return "km/h"
        case .mph: return "mph"
        }
    }
}

/// Préférences d'affichage des unités (persistées dans UserDefaults).
final class UnitPreferences: ObservableObject {
    static let shared = UnitPreferences()

    private enum Keys {
        static let distance = "distanceUnit"
        static let speed = "speedUnit"
    }

    @Published var distanceUnit: DistanceUnit {
        didSet { UserDefaults.standard.set(distanceUnit.rawValue, forKey: Keys.distance) }
    }

    @Published var speedUnit: SpeedUnit {
        didSet { UserDefaults.standard.set(speedUnit.rawValue, forKey: Keys.speed) }
    }

    private init() {
        let defaults = UserDefaults.standard
        distanceUnit = DistanceUnit(rawValue: defaults.string(forKey: Keys.distance) ?? "") ?? .meters
        speedUnit = SpeedUnit(rawValue: defaults.string(forKey: Keys.speed) ?? "") ?? .kmh
    }

    // MARK: - Formatage

    func formatDistance(cm: Double) -> String {
        switch distanceUnit {
        case .meters:
            let meters = cm / 100
            if meters >= 1_000 {
                return String(format: "%.2f km", meters / 1_000)
            }
            if meters >= 1 {
                return String(format: "%.2f m", meters)
            }
            return String(format: "%.1f cm", cm)
        case .steps:
            let steps = Self.steps(fromMeters: cm / 100)
            if steps >= 10_000 {
                return String(format: "%.1fk steps", steps / 1_000)
            }
            return String(format: "%.0f steps", steps)
        }
    }

    func formatSpeed(kmh: Double) -> String {
        switch speedUnit {
        case .kmh:
            return String(format: "%.1f km/h", kmh)
        case .mph:
            return String(format: "%.1f mph", Self.mph(fromKmh: kmh))
        }
    }

    /// Valeur Y pour les graphiques d'historique (distance).
    func chartDistanceValue(cm: Double) -> Double {
        switch distanceUnit {
        case .meters: return cm / 100
        case .steps:  return Self.steps(fromMeters: cm / 100)
        }
    }

    var chartDistanceLabel: String {
        switch distanceUnit {
        case .meters: return "m"
        case .steps:  return "steps"
        }
    }

    var chartDistanceSectionTitle: String {
        switch distanceUnit {
        case .meters: return "Mouse distance per day (m)"
        case .steps:  return "Mouse distance per day (steps)"
        }
    }

    /// Valeur Y pour les graphiques d'historique (vitesse).
    func chartSpeedValue(kmh: Double) -> Double {
        switch speedUnit {
        case .kmh: return kmh
        case .mph: return Self.mph(fromKmh: kmh)
        }
    }

    var chartSpeedLabel: String { speedUnit.displayName }

    // MARK: - Conversions

    static func steps(fromMeters meters: Double) -> Double {
        meters / DistanceUnit.metersPerStep
    }

    static func mph(fromKmh kmh: Double) -> Double {
        kmh / 1.609344
    }
}
