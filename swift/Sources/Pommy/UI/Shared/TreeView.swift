import SwiftUI

/// A stylized tree that grows from sapling to full canopy.
@MainActor
struct TreeView: View {
    var growth: Double
    var size: CGFloat = 90
    var variant: Int = 0
    var depthShade: Double = 0

    private var g: Double { min(1.0, max(0.0, growth)) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Subtle warm enchanted ground pool under the tree base.
            Ellipse()
                .fill(Color(hex: "#F8E89A").opacity(0.12 + depthShade * 0.06))
                .frame(width: size * 0.58, height: size * 0.14)
                .blur(radius: 3)
                .offset(y: size * 0.30)

            // Ground shadow keeps the tree visually anchored.
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: size * 0.52, height: size * 0.10)
                .blur(radius: 1.5)
                .offset(y: size * 0.28)

            trunk
            canopy
        }
        .frame(width: size, height: size)
    }

    private var trunk: some View {
        let trunkPalette: [[Color]] = [
            [Color(hex: "#7A4F36"), Color(hex: "#5E3C2B")],
            [Color(hex: "#6F4A34"), Color(hex: "#553829")],
            [Color(hex: "#84553A"), Color(hex: "#623F2C")]
        ]
        let palette = trunkPalette[variant % trunkPalette.count]
        return RoundedRectangle(cornerRadius: size * 0.04, style: .continuous)
            .fill(
                LinearGradient(
                    colors: palette,
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: max(3, size * 0.12 * CGFloat(0.3 + 0.7 * g)),
                   height: max(2, size * 0.34 * CGFloat(g)))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: size * 0.01, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: max(1, size * 0.018), height: max(2, size * 0.28 * CGFloat(g)))
                    .offset(x: size * 0.012)
            }
            .offset(y: size * 0.16)
            .opacity(0.85 + depthShade * 0.15)
            .animation(.easeInOut(duration: 0.35), value: g)
    }

    private var canopy: some View {
        let canopyPalette: [[Color]] = [
            [Color(hex: "#4D8A5B"), Color(hex: "#5D9A68"), Color(hex: "#3F7A4E")],
            [Color(hex: "#4B8559"), Color(hex: "#5A9564"), Color(hex: "#3C734A")],
            [Color(hex: "#538F60"), Color(hex: "#62A16D"), Color(hex: "#447D52")],
            [Color(hex: "#4A7F56"), Color(hex: "#598F63"), Color(hex: "#3A6F48")]
        ]
        let palette = canopyPalette[variant % canopyPalette.count]
        let canopyScale = CGFloat(0.25 + 0.75 * g)
        let fruitColor: [Color] = [
            Color(hex: "#E86E5E"),
            Color(hex: "#F2B45A"),
            Color(hex: "#D97A46")
        ]
        let fruit = fruitColor[variant % fruitColor.count]
        return ZStack {
            Circle()
                .fill(palette[0])
                .frame(width: size * 0.40, height: size * 0.40)
                .offset(x: -size * 0.16, y: -size * 0.10)
            Circle()
                .fill(palette[1])
                .frame(width: size * 0.48, height: size * 0.48)
                .offset(y: -size * 0.18)
            Circle()
                .fill(palette[2])
                .frame(width: size * 0.38, height: size * 0.38)
                .offset(x: size * 0.16, y: -size * 0.10)

            // Tiny fruit accents keep trees richer without changing silhouette.
            Circle()
                .fill(fruit.opacity(0.75))
                .frame(width: size * 0.06, height: size * 0.06)
                .offset(x: -size * 0.08, y: -size * 0.16)
            Circle()
                .fill(fruit.opacity(0.68))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: size * 0.03, y: -size * 0.24)
            Circle()
                .fill(fruit.opacity(0.62))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(x: size * 0.14, y: -size * 0.12)
        }
        .overlay(alignment: .top) {
            Circle()
                .fill(Color.white.opacity(0.05 + depthShade * 0.04))
                .frame(width: size * 0.24, height: size * 0.11)
                .blur(radius: 1.4)
                .offset(y: -size * 0.17)
        }
        .overlay(alignment: .topLeading) {
            Ellipse()
                .fill(Color.white.opacity(0.03 + depthShade * 0.03))
                .frame(width: size * 0.16, height: size * 0.07)
                .blur(radius: 1.1)
                .offset(x: size * 0.06, y: size * 0.00)
        }
        .shadow(color: Color(hex: "#92C8A3").opacity(0.05 + depthShade * 0.10), radius: size * 0.03, y: 1)
        .scaleEffect(canopyScale, anchor: .bottom)
        .opacity((0.25 + 0.75 * g) * (0.82 + depthShade * 0.18))
        .animation(.easeInOut(duration: 0.35), value: g)
    }
}

/// A clustered forest layout where one tree completes every hour.
@MainActor
struct TreeForestClusterView: View {
    var focusMinutes: Int

    private static let cycleMinutes: Int = 60
    private struct TreePlacement: Identifiable {
        let id: Int
        let growth: Double
        let point: CGPoint
        let scale: CGFloat
        let opacity: Double
        let variant: Int
        let depthShade: Double
        let ringIndex: Int
    }

    private struct TreeItem: Identifiable {
        let id: Int
        let growth: Double
    }

    private var completedTrees: Int {
        max(0, focusMinutes / Self.cycleMinutes)
    }

    private var currentGrowth: Double {
        Double(max(0, focusMinutes % Self.cycleMinutes)) / Double(Self.cycleMinutes)
    }

    /// Keep full history and place trees in an organic cluster.
    private var trees: [TreeItem] {
        let total = completedTrees + 1
        return (0..<total).map { idx in
            TreeItem(id: idx, growth: idx == completedTrees ? currentGrowth : 1.0)
        }
    }

    private var treeSize: CGFloat {
        switch trees.count {
        case 1: return 98
        case 2...3: return 90
        case 4...6: return 80
        case 7...10: return 70
        case 11...16: return 63
        default: return 56
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let placements = makePlacements(in: geo.size)

                ZStack(alignment: .bottom) {
                    forestFloor(size: geo.size, time: t)
                    depthHaze(size: geo.size, time: t)
                    enchantmentLights(placements: placements, treeSize: treeSize, size: geo.size, time: t)

                    ForEach(placements) { placement in
                        let phase = Double(placement.id) * 0.91
                        let sway = sin(t * 0.58 + phase) * (0.55 + placement.depthShade * 0.55)
                        let bob = cos(t * 0.44 + phase) * (0.6 + placement.depthShade * 0.5)
                        TreeView(
                            growth: placement.growth,
                            size: treeSize * placement.scale,
                            variant: placement.variant,
                            depthShade: placement.depthShade
                        )
                        .rotationEffect(.degrees(sway), anchor: .bottom)
                        .offset(y: bob)
                        .opacity(placement.opacity)
                        .position(placement.point)
                        .zIndex(Double(placement.point.y))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func forestFloor(size: CGSize, time: Double) -> some View {
        let breath = 0.92 + ((sin(time * 0.36) + 1.0) * 0.5) * 0.14
        ZStack {
            // Full-bottom ambience in the same style as firefly scene:
            // oversized, blurred ellipses anchored below the viewport.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#214032").opacity(0.24 * breath),
                            Color(hex: "#162D24").opacity(0.40 * breath),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: max(size.width * 0.95, 240)
                    )
                )
                .frame(width: size.width * 2.0, height: size.height * 1.05)
                .position(x: size.width * 0.5, y: size.height * 1.05)
                .blur(radius: 12)

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#2F5740").opacity(0.22 * breath),
                            Color(hex: "#1B3529").opacity(0.16 * breath),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: max(size.width * 0.72, 180)
                    )
                )
                .frame(width: size.width * 1.35, height: size.height * 0.64)
                .position(x: size.width * 0.5, y: size.height * 0.98)
                .blur(radius: 13)

            // Soft grass texture to avoid a flat "bar" floor look.
            grassTexture(size: size)
        }
    }

    @ViewBuilder
    private func depthHaze(size: CGSize, time: Double) -> some View {
        let haze = 0.9 + ((sin(time * 0.28 + 1.4) + 1.0) * 0.5) * 0.16
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hex: "#A9C7B5").opacity(0.05 * haze),
                        Color(hex: "#6B8F7A").opacity(0.03 * haze),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 12,
                    endRadius: max(size.width * 0.40, 130)
                )
            )
            .frame(width: size.width * 0.92, height: size.height * 0.20)
            .position(x: size.width * 0.50, y: size.height * 0.60)
            .blur(radius: 10)
    }

    @ViewBuilder
    private func grassTexture(size: CGSize) -> some View {
        let rows = 3
        let cols = 14
        ForEach(0..<rows, id: \.self) { row in
            ForEach(0..<cols, id: \.self) { col in
                let idx = row * cols + col
                let xBase = size.width * (0.08 + 0.84 * Double(col) / Double(max(1, cols - 1)))
                let yBase = size.height * (0.76 + Double(row) * 0.08)
                let x = xBase + pseudoNoise(Double(idx) * 1.31) * size.width * 0.018
                let y = yBase + pseudoNoise(Double(idx) * 2.07) * size.height * 0.012
                let h = size.height * (0.008 + 0.004 * abs(pseudoNoise(Double(idx) * 2.71)))
                let w = h * 0.45
                Capsule(style: .continuous)
                    .fill(Color(hex: "#6EA37A").opacity(0.11))
                    .frame(width: w, height: h)
                    .rotationEffect(.degrees(pseudoNoise(Double(idx) * 3.19) * 16))
                    .position(x: x, y: y)
                    .blur(radius: 0.6)
            }
        }
    }

    @ViewBuilder
    private func enchantmentLights(placements: [TreePlacement], treeSize: CGFloat, size: CGSize, time: Double) -> some View {
        if placements.isEmpty {
            EmptyView()
        } else {
            let sorted = placements.sorted { $0.point.y > $1.point.y }
            let pickIndices: [Int] = {
                let n = sorted.count
                if n >= 3 { return [0, n / 2, n - 1] }
                if n == 2 { return [0, 1] }
                return [0]
            }()
            ForEach(pickIndices, id: \.self) { idx in
                let p = sorted[idx]
                let half = treeSize * p.scale * 0.42
                let ox = pseudoNoise(Double(p.id) * 2.1 + 0.5) * treeSize * p.scale * 0.15
                let oy = half + treeSize * p.scale * 0.06
                let r = size.width * 0.008 + abs(pseudoNoise(Double(p.id))) * size.width * 0.004
                let pulse = 0.78 + ((sin(time * 1.2 + Double(p.id) * 0.9) + 1.0) * 0.5) * 0.35
                Circle()
                    .fill(Color(hex: "#F8E89A").opacity(0.12 * pulse))
                    .frame(width: r * (2.8 + pulse), height: r * (2.8 + pulse))
                    .blur(radius: r * 1.0)
                    .position(x: p.point.x + CGFloat(ox), y: p.point.y + CGFloat(oy))
            }
        }
    }

    private func makePlacements(in size: CGSize) -> [TreePlacement] {
        let layout = softRingLayout(count: trees.count, in: size)
        let maxRing = layout.map(\.ring).max() ?? 0

        var placements: [TreePlacement] = []
        placements.reserveCapacity(trees.count)

        for (idx, item) in trees.enumerated() {
            let entry = layout[safe: idx]
            let point = entry?.point ?? CGPoint(x: size.width * 0.5, y: size.height * 0.66)
            let ring = entry?.ring ?? 0
            let ri = CGFloat(ring)
            let scale = max(0.66, 0.92 - ri * 0.06)
            let opacity = max(0.78, 1.0 - Double(ring) * 0.07)
            let depthShade = maxRing > 0 ? Double(ring) / Double(maxRing) : 1.0
            placements.append(
                TreePlacement(
                    id: item.id,
                    growth: item.growth,
                    point: point,
                    scale: scale,
                    opacity: opacity,
                    variant: idx,
                    depthShade: depthShade,
                    ringIndex: ring
                )
            )
        }
        return placements.sorted { $0.point.y < $1.point.y }
    }

    private struct RingCell {
        let point: CGPoint
        let ring: Int
    }

    /// Soft elliptical rings with jitter, perspective bias, and minimum separation.
    private func softRingLayout(count: Int, in size: CGSize) -> [RingCell] {
        guard count > 0 else { return [] }

        // Stronger left bias to offset perceived right-heavy composition.
        let center = CGPoint(x: size.width * 0.44, y: size.height * 0.71)
        let ringStepX = max(treeSize * 1.05, size.width * 0.13)
        let ringStepY = max(treeSize * 0.90, size.height * 0.12)
        let maxRadiusX = size.width * 0.42
        let maxRadiusY = size.height * 0.34
        let minDist = treeSize * 0.78
        let yMin = size.height * 0.44
        let yMax = size.height * 0.94
        let leftPad = max(treeSize * 0.45, 18)
        let rightPad = max(treeSize * 0.55, 24)

        var cells: [RingCell] = []
        cells.reserveCapacity(count)

        cells.append(RingCell(point: center, ring: 0))
        if count == 1 { return cells }

        var placed = 1
        var ring = 1
        while placed < count {
            let spots = max(6, ring * 6)
            for s in 0..<spots where placed < count {
                let baseAngle = (Double(s) / Double(spots)) * .pi * 2.0
                let angle = baseAngle + pseudoNoise(Double(placed) * 0.71) * 0.14
                let rx = min(maxRadiusX, ringStepX * CGFloat(ring))
                let ry = min(maxRadiusY, ringStepY * CGFloat(ring))
                let jitterX = pseudoNoise(Double(placed) * 1.17 + 0.9) * treeSize * 0.10
                let jitterY = pseudoNoise(Double(placed) * 1.91 + 2.4) * treeSize * 0.07
                let perspective = CGFloat(ring) * size.height * 0.03

                var x = center.x + cos(angle) * rx + jitterX
                var y = center.y + sin(angle) * ry + jitterY - perspective

                x = clamp(x, leftPad, size.width - rightPad)
                y = clamp(y, yMin, yMax)

                cells.append(RingCell(point: CGPoint(x: x, y: y), ring: ring))
                placed += 1
            }
            ring += 1
        }

        // Minimum-distance separation (several passes).
        var pts = cells.map { $0.point }
        let rings = cells.map { $0.ring }
        for _ in 0..<5 {
            for i in pts.indices {
                for j in (i + 1)..<pts.count {
                    var dx = pts[j].x - pts[i].x
                    var dy = pts[j].y - pts[i].y
                    var d = sqrt(dx * dx + dy * dy)
                    if d < 0.001 { d = 0.001 }
                    if d < minDist {
                        let push = (minDist - d) * 0.55
                        dx /= d
                        dy /= d
                        pts[i].x -= dx * push
                        pts[i].y -= dy * push
                        pts[j].x += dx * push
                        pts[j].y += dy * push
                        pts[i].x = clamp(pts[i].x, leftPad, size.width - rightPad)
                        pts[i].y = clamp(pts[i].y, yMin, yMax)
                        pts[j].x = clamp(pts[j].x, leftPad, size.width - rightPad)
                        pts[j].y = clamp(pts[j].y, yMin, yMax)
                    }
                }
            }
        }

        return zip(pts, rings).map { RingCell(point: $0, ring: $1) }
    }

    private func pseudoNoise(_ x: Double) -> Double {
        let raw = sin(x * 12.9898 + 78.233) * 43758.5453
        let fract = raw - floor(raw)
        return fract * 2.0 - 1.0
    }

    private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
