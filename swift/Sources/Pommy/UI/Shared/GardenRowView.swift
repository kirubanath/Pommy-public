import SwiftUI

/// A row of plants that grows one new plant every 30 minutes.
///
/// - Completed cycles show a fully bloomed plant (growth = 1.0).
/// - The rightmost plant is the currently growing one.
/// - Plants shrink as the row fills so everything fits in the available width.
/// - After 6 plants the leftmost slides out as a new one enters (sliding window).
@MainActor
struct GardenRowView: View {
    var elapsedSeconds: Int

    private static let cycleSeconds: Int = 30 * 60
    private static let maxVisible:   Int = 6

    // How many complete 30-min cycles have passed.
    private var completedCycles: Int {
        elapsedSeconds / Self.cycleSeconds
    }

    // Progress within the current (incomplete) cycle.
    private var currentGrowth: Double {
        Double(elapsedSeconds % Self.cycleSeconds) / Double(Self.cycleSeconds)
    }

    // The IDs of plants currently shown (sliding window of maxVisible).
    // Each plant has a stable identity so SwiftUI can animate insertions/removals.
    private var visiblePlants: [PlantItem] {
        let totalCompleted = completedCycles
        let total = totalCompleted + 1   // +1 for the growing one

        // Window: show the latest maxVisible plants.
        let startIdx = max(0, total - Self.maxVisible)
        var items: [PlantItem] = []
        for i in startIdx..<total {
            let isGrowing = (i == totalCompleted)
            items.append(PlantItem(
                id:     i,
                growth: isGrowing ? currentGrowth : 1.0
            ))
        }
        return items
    }

    private var visibleCount: Int { visiblePlants.count }

    // Plant size scales down as the garden fills.
    private var plantSize: CGFloat {
        switch visibleCount {
        case 1:       return 160
        case 2:       return 110
        case 3:       return 85
        case 4:       return 70
        case 5:       return 62
        default:      return 56
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(visiblePlants) { item in
                PlantView(growth: item.growth, size: plantSize)
                    .transition(
                        .asymmetric(
                            insertion:  .move(edge: .trailing).combined(with: .opacity),
                            removal:    .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: visibleCount)
    }
}

// MARK: - Model

private struct PlantItem: Identifiable {
    let id:     Int
    var growth: Double
}
