import SwiftUI

/// Sélecteurs compacts distance / vitesse, partagés entre les onglets du dashboard.
struct UnitsPickerBar: View {
    @ObservedObject private var units = UnitPreferences.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Units")
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Distance", selection: $units.distanceUnit) {
                        ForEach(DistanceUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Speed", selection: $units.speedUnit) {
                        ForEach(SpeedUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }
}
