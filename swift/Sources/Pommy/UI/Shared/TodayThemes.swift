import SwiftUI

@MainActor
struct TodayThemeRenderer: View {
    let theme: StatsTodayTheme
    let focusMinutes: Int
    var dailyGoalMet: Bool = false
    var dailyGoalMetAt: Date? = nil
    var weeklyGoalMet: Bool = false
    var weeklyGoalMetAt: Date? = nil

    var body: some View {
        FireflyJarView(
            focusMinutes: focusMinutes,
            dailyGoalMet: dailyGoalMet,
            dailyGoalMetAt: dailyGoalMetAt,
            weeklyGoalMet: weeklyGoalMet,
            weeklyGoalMetAt: weeklyGoalMetAt
        )
    }
}

extension StatsTodayTheme {
    private var singular: String {
        switch self {
        case .fireflyJar: return "firefly"
        }
    }

    private var plural: String {
        switch self {
        case .fireflyJar: return "fireflies"
        }
    }

    func countLabel(_ count: Int) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }

    var helperText: String {
        switch self {
        case .fireflyJar:
            return "A new firefly gathers at your camp every hour of focus."
        }
    }
}

private enum TodayThemeMath {
    static let cycleMinutes = 60
}

@MainActor
private struct FireflyJarView: View {
    @Environment(AppState.self) private var appState

    let focusMinutes: Int
    let dailyGoalMet: Bool
    let dailyGoalMetAt: Date?
    let weeklyGoalMet: Bool
    let weeklyGoalMetAt: Date?

    @State private var lastSeenCount: Int = -1
    @State private var arrivalIndex: Int? = nil
    @State private var arrivalAt: Date? = nil

    private var completed: Int {
        max(0, focusMinutes / TodayThemeMath.cycleMinutes)
    }

    private var partial: Double {
        Double(max(0, focusMinutes % TodayThemeMath.cycleMinutes)) / Double(TodayThemeMath.cycleMinutes)
    }

    private var countForAnimation: Int { completed }

    private var timelineMinimumInterval: Double {
        switch appState.effectiveAnimationMode {
        case .full: return 1.0 / 20.0
        case .throttled: return 1.0 / 8.0
        case .frozen: return 60.0
        }
    }

    /// Cozy campfire curve: more fireflies gently enrich fire glow.
    private var campGlowProgress: Double {
        let raw = Double(completed) + partial
        let linear = min(1.0, raw / 10.0)
        return sqrt(linear)
    }

    var body: some View {
        // When frozen, render a single static frame and skip TimelineView entirely.
        // TimelineView at any minimumInterval still wakes the SwiftUI graph + CA
        // transaction loop on every tick; the only way to truly idle is to not
        // schedule a timeline at all.
        Group {
            if appState.effectiveAnimationMode == .frozen {
                sceneBody(at: Date().timeIntervalSinceReferenceDate)
            } else {
                TimelineView(.animation(minimumInterval: timelineMinimumInterval)) { context in
                    sceneBody(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .onAppear {
            if lastSeenCount < 0 {
                lastSeenCount = countForAnimation
            }
        }
        .onChange(of: focusMinutes) { _, _ in
            let now = countForAnimation
            if now > lastSeenCount {
                arrivalIndex = now - 1
                arrivalAt = Date()
            }
            lastSeenCount = now
        }
    }

    @ViewBuilder
    private func sceneBody(at t: Double) -> some View {
        GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                // Match CampfireSceneLayer: place fireflies relative to the camp ground line, not the GeometryReader origin.
                let sceneScale = max(0.76, min(1.0, min(w, h) / 260))
                let campLift = (1.0 - sceneScale) * 62
                let campY = h * 0.70 - campLift
                // Fireflies hover around the camp itself — over the tent, fire, and clearing —
                // not up in the sky. Tent middle is at campY ~+13, fire at campY ~+86.
                let hoverY = campY + 20 * sceneScale
                // Convert to a .offset value relative to the ZStack center.
                let yAnchorOffset = hoverY - h / 2

                let choreographyT = dailyGoalMetAt.map { Date().timeIntervalSince($0) } ?? -1
                let lampStrength: Double = {
                    guard focusMinutes > 0 else { return 0.0 }
                    if !dailyGoalMet { return 1.0 }
                    // Fade lamp out over the first second of the completion choreography.
                    let fade = max(0.0, min(1.0, choreographyT))
                    let eased = fade * fade * (3 - 2 * fade)
                    return 1.0 - eased
                }()

                ZStack {
                    CampfireSceneLayer(
                        width: w,
                        height: h,
                        time: t,
                        activityMode: appState.effectiveAnimationMode,
                        glowProgress: campGlowProgress,
                        lampStrength: lampStrength,
                        dailyGoalMet: dailyGoalMet,
                        dailyGoalMetAt: dailyGoalMetAt,
                        choreographyElapsed: choreographyT,
                        weeklyGoalMet: weeklyGoalMet,
                        weeklyGoalMetAt: weeklyGoalMetAt
                    )

                    ForEach(0..<countForAnimation, id: \.self) { i in
                        let seed = Double(i) * 0.79
                        let lane = Double(i % 7)
                        let orbitX = w * (0.10 + lane * 0.022)
                        let orbitY = h * (0.05 + lane * 0.010)
                        let anchorX = sin(seed * 2.1) * w * 0.15
                        let verticalSpread = h * (0.020 + Double((i * 3) % 5) * 0.012)
                        let angle = t * (0.24 + seed * 0.014) + seed * 2.4
                        let driftX = cos(angle) * orbitX
                        let driftY = sin(angle * 1.08) * orbitY
                        let wiggleX = sin(t * (1.2 + seed * 0.03) + seed * 3.3) * w * 0.012
                        let wiggleY = cos(t * (1.1 + seed * 0.04) + seed * 2.8) * h * 0.010
                        let naturalX = CGFloat(anchorX + driftX + wiggleX)
                        let naturalY = yAnchorOffset + CGFloat(driftY + wiggleY - verticalSpread)
                        // Arrival animation: most recently earned firefly flies in from off-screen left.
                        let arrivalT: Double = {
                            guard let at = arrivalAt, arrivalIndex == i else { return 1.0 }
                            return max(0.0, min(1.0, Date().timeIntervalSince(at) / 2.0))
                        }()
                        let easedT = arrivalT * arrivalT * (3 - 2 * arrivalT)
                        let entryX = -w * 0.6
                        let entryY = -h * 0.25
                        let x = entryX + (naturalX - entryX) * CGFloat(easedT)
                        let y = entryY + (naturalY - entryY) * CGFloat(easedT)
                        let pulse = (sin(t * (1.7 + seed * 0.05) + seed * 1.2) + 1) / 2
                        let depth = Double((i % 3) + 1) / 3.0
                        let glow = 0.26 + pulse * (0.42 + depth * 0.12)
                        let tilt = Angle.degrees(sin(t * (0.95 + seed * 0.025) + seed) * 4)
                        let baseScale = countForAnimation <= 2 ? 1.0 : (countForAnimation <= 5 ? 0.88 : 0.74)
                        let scale = baseScale * (0.88 + depth * 0.16)
                        let alpha = 0.72 + depth * 0.28

                        FireflyGlyph(styleSeed: i, time: t, glow: glow, opacity: alpha)
                            .scaleEffect(scale)
                            .rotationEffect(tilt)
                            .blur(radius: (1 - depth) * 0.35)
                            .offset(x: x, y: y)
                    }

                    if partial > 0.01 {
                        let hatchPulse = (sin(t * 2.2) + 1) * 0.5
                        FireflyGlyph(
                            styleSeed: max(1, countForAnimation + 1),
                            time: t,
                            glow: 0.22 + hatchPulse * 0.20,
                            opacity: partial * (0.45 + hatchPulse * 0.35)
                        )
                        .scaleEffect(0.64 + partial * 0.30)
                        .offset(x: -w * 0.06, y: yAnchorOffset - h * 0.02)
                    }
                }
                .frame(width: w, height: h)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
private struct CampfireSceneLayer: View {
    let width: CGFloat
    let height: CGFloat
    let time: Double
    let activityMode: AnimationActivityMode
    let glowProgress: Double
    let lampStrength: Double
    let dailyGoalMet: Bool
    let dailyGoalMetAt: Date?
    let choreographyElapsed: Double
    let weeklyGoalMet: Bool
    let weeklyGoalMetAt: Date?

    private var slowPhase: Double { time * 0.35 }

    private var flicker: Double {
        let fast = sin(time * 7.3) * 0.08
        let mid = sin(time * 3.1 + 1.2) * 0.12
        let slow = sin(time * 1.4 + 0.6) * 0.06
        return 0.78 + fast + mid + slow
    }

    var body: some View {
        let sceneScale = max(0.76, min(1.0, min(width, height) / 260))
        let campLift = (1.0 - sceneScale) * 62
        // Camp sits on the ground line shared with the surrounding tree bases.
        let campY = height * 0.70 - campLift
        // Fire sits in front of the tent (toward the viewer), not directly under it.
        let logY = campY + 86 * sceneScale
        let fire = max(0.55, flicker)
        // Gentle breeze — slow, layered sines for natural sway.
        let breezeFast = sin(time * 0.45) * 0.7
        let breezeSlow = sin(time * 0.18 + 1.2) * 0.4
        let breeze = breezeFast + breezeSlow

        ZStack {
            // Sky — deeper and richer as the user accumulates focus minutes.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#131722"),
                            Color(hex: "#141826"),
                            Color(hex: "#111622"),
                            Color(hex: "#0D111A")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)

            // Early-session lift: lighter top wash that fades out as focus accumulates.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#27314A").opacity(0.45),
                            Color(hex: "#1E2638").opacity(0.20),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .opacity(1.0 - glowProgress)

            // Keep ember glow close to the clearing, not across the whole sky.
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#2C2024").opacity(0.18),
                            Color(hex: "#221A1E").opacity(0.08),
                            .clear
                        ],
                        center: UnitPoint(x: 0.5, y: 0.78),
                        startRadius: 30,
                        endRadius: max(width * 0.30, 150)
                    )
                )
                .frame(width: width, height: height)

            // Faint moonlight wash adds depth to the upper sky.
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#B3C1E6").opacity(0.07),
                            Color(hex: "#7D8DAF").opacity(0.03),
                            .clear
                        ],
                        startPoint: UnitPoint(x: 0.84, y: 0.03),
                        endPoint: UnitPoint(x: 0.54, y: 0.55)
                    )
                )
                .frame(width: width, height: height)
                .blendMode(.screen)

            // Gentle vignette — subtle.
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.30)
                        ],
                        center: .center,
                        startRadius: max(width, height) * 0.40,
                        endRadius: max(width, height) * 1.0
                    )
                )
                .frame(width: width, height: height)

            // Moon — generous halo, layered for atmospheric presence.
            let moonX = width * 0.84
            let moonY = height * 0.20
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#C8D2E4").opacity(0.10),
                            Color(hex: "#8A94AC").opacity(0.05),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 130
                    )
                )
                .frame(width: 240, height: 240)
                .position(x: moonX, y: moonY)
                .blur(radius: 8)
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#D7E2F8").opacity(0.12),
                            Color(hex: "#9AA7C6").opacity(0.07),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 86
                    )
                )
                .frame(width: 156, height: 156)
                .position(x: moonX, y: moonY)
                .blur(radius: 5)
                .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#E8ECF4").opacity(0.30),
                            Color(hex: "#A8B2C8").opacity(0.10),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 60
                    )
                )
                .frame(width: 110, height: 110)
                .position(x: moonX, y: moonY)
                .blur(radius: 3)
                .blendMode(.plusLighter)

            // Moon body.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#F2F5FB").opacity(0.96),
                            Color(hex: "#D6DCEA").opacity(0.92),
                            Color(hex: "#9AA3B8").opacity(0.85)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.36),
                        startRadius: 2,
                        endRadius: 32
                    )
                )
                .frame(width: 50, height: 50)
                .position(x: moonX, y: moonY)
                .overlay(
                    // Subtle craters for character.
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#7E869C").opacity(0.20))
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -3)
                        Circle()
                            .fill(Color(hex: "#7E869C").opacity(0.16))
                            .frame(width: 4, height: 4)
                            .offset(x: -5, y: 2)
                        Circle()
                            .fill(Color(hex: "#7E869C").opacity(0.14))
                            .frame(width: 3, height: 3)
                            .offset(x: 6, y: 7)
                        Circle()
                            .fill(Color(hex: "#7E869C").opacity(0.12))
                            .frame(width: 2.5, height: 2.5)
                            .offset(x: -2, y: -7)
                    }
                    .frame(width: 50, height: 50)
                    .blur(radius: 0.4)
                    .position(x: moonX, y: moonY)
                )

            // Faint shadow on the bottom-right for dimensionality.
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .clear, Color(hex: "#3D4458").opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .position(x: moonX, y: moonY)
                .blendMode(.multiply)

            // Stars — all 44 always visible. Focus accumulation makes them subtly brighter,
            // never hides them. The night sky is the brand, not a reward to be earned.
            let starBoost = 0.85 + 0.15 * glowProgress
            ForEach(0..<44, id: \.self) { i in
                let seed = Double(i) * 0.617
                let twinkle = (sin(slowPhase * 0.85 + seed * 6.3) + 1) * 0.5
                let xFrac = 0.02 + (seed * 1.73).truncatingRemainder(dividingBy: 1.0) * 0.96
                let yFrac = 0.03 + (seed * 2.07).truncatingRemainder(dividingBy: 1.0) * 0.42
                let isBright = i % 7 == 0
                let baseSize = isBright ? 1.8 : 0.9
                let size = baseSize + twinkle * (isBright ? 1.6 : 1.0)
                Circle()
                    .fill(Color(hex: "#F4ECDA").opacity(((isBright ? 0.30 : 0.12) + twinkle * 0.22) * starBoost))
                    .frame(width: size, height: size)
                    .position(x: width * CGFloat(xFrac), y: height * CGFloat(yFrac))
                    .blur(radius: isBright ? 0.4 : 0)

                if isBright {
                    Capsule()
                        .fill(Color(hex: "#DFE7FA").opacity((0.16 + twinkle * 0.14) * starBoost))
                        .frame(width: 6 + twinkle * 3, height: 0.8)
                        .position(x: width * CGFloat(xFrac), y: height * CGFloat(yFrac))
                        .blur(radius: 0.3)
                    Capsule()
                        .fill(Color(hex: "#DFE7FA").opacity((0.16 + twinkle * 0.14) * starBoost))
                        .frame(width: 0.8, height: 6 + twinkle * 3)
                        .position(x: width * CGFloat(xFrac), y: height * CGFloat(yFrac))
                        .blur(radius: 0.3)
                }
            }

            // Keep cloud wisps very faint so the sky stays mostly dark.
            let wispShift = sin(slowPhase * 0.18) * 12
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(hex: "#2A2E3C").opacity(0.12),
                            Color(hex: "#22252F").opacity(0.07),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.7, height: height * 0.10)
                .position(x: width * 0.35 + CGFloat(wispShift), y: height * 0.32)
                .blur(radius: 18)

            // Edge clouds — soft puffs drifting along the upper corners.
            // Top-left cluster.
            Group {
                Ellipse()
                    .fill(Color(hex: "#2C3040").opacity(0.24))
                    .frame(width: width * 0.32, height: height * 0.10)
                    .position(x: width * 0.04 + CGFloat(sin(slowPhase * 0.12) * 6), y: height * 0.10)
                    .blur(radius: 22)
                Ellipse()
                    .fill(Color(hex: "#363A4C").opacity(0.16))
                    .frame(width: width * 0.22, height: height * 0.07)
                    .position(x: width * 0.14 + CGFloat(sin(slowPhase * 0.15 + 1) * 5), y: height * 0.16)
                    .blur(radius: 14)
                Ellipse()
                    .fill(Color(hex: "#2A2E3E").opacity(0.18))
                    .frame(width: width * 0.18, height: height * 0.06)
                    .position(x: width * 0.26 + CGFloat(sin(slowPhase * 0.1 + 2) * 4), y: height * 0.08)
                    .blur(radius: 12)
            }

            // Top-right cluster — very faint.
            Group {
                Ellipse()
                    .fill(Color(hex: "#2C3040").opacity(0.14))
                    .frame(width: width * 0.28, height: height * 0.09)
                    .position(x: width * 0.96 + CGFloat(sin(slowPhase * 0.11 + 0.7) * 5), y: height * 0.06)
                    .blur(radius: 20)
                Ellipse()
                    .fill(Color(hex: "#323748").opacity(0.12))
                    .frame(width: width * 0.20, height: height * 0.06)
                    .position(x: width * 0.66 + CGFloat(sin(slowPhase * 0.14 + 1.4) * 6), y: height * 0.13)
                    .blur(radius: 14)
            }

            // Shooting star — bright streak across the upper sky every ~25s. Drawn AFTER clouds
            // so wisps don't dim it, with a tail that's always visible (not zero-width at edges).
            let shootCycle: Double = 25
            let shootCyclePhase = time.truncatingRemainder(dividingBy: shootCycle)
            let shootDayKey = Double(Int(time / 86400))
            let shootSeed = (shootDayKey * 1.137 + (time / shootCycle).rounded(.down) * 0.073)
                .truncatingRemainder(dividingBy: 1.0)
            let shootStart = shootSeed * (shootCycle - 2.5)
            let shootElapsed = shootCyclePhase - shootStart
            if shootElapsed >= 0 && shootElapsed <= 1.8 {
                let shootT = shootElapsed / 1.8
                let startX = -width * 0.10
                let endX = width * 1.10
                let startY = height * (0.05 + shootSeed * 0.08)
                let endY = startY + height * 0.20
                let headX = startX + (endX - startX) * CGFloat(shootT)
                let headY = startY + (endY - startY) * CGFloat(shootT)
                // Always-visible tail: short at the edges, long at the apex.
                let envelope = sin(shootT * .pi)
                let tailLen: CGFloat = 28 + 48 * CGFloat(envelope)
                let dirLen = hypot(endX - startX, endY - startY)
                let dirX = (endX - startX) / dirLen
                let dirY = (endY - startY) / dirLen
                let tailX = headX - dirX * tailLen
                let tailY = headY - dirY * tailLen
                let alpha = 0.55 + 0.45 * envelope
                let midX = (headX + tailX) / 2
                let midY = (headY + tailY) / 2
                let angle = atan2(headY - tailY, headX - tailX) * 180 / .pi
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                Color(hex: "#FBF1D2").opacity(alpha * 0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: tailLen, height: 2.0)
                    .rotationEffect(.degrees(Double(angle)))
                    .position(x: midX, y: midY)
                    .blur(radius: 0.6)
                    .blendMode(.plusLighter)
                Circle()
                    .fill(Color(hex: "#FFFCEC").opacity(alpha))
                    .frame(width: 5.0, height: 5.0)
                    .position(x: headX, y: headY)
                    .blur(radius: 0.4)
                    .blendMode(.plusLighter)
            }

            // Ground plane — warm earthy base so elements sit on something visible, not a black void.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#6A5946").opacity(0.36),
                            Color(hex: "#554637").opacity(0.42),
                            Color(hex: "#3A2F28").opacity(0.54)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 1.95, height: height * 0.42)
                .position(x: width * 0.5, y: height * 0.95)
                .blur(radius: 12)

            // Land foundation under foothills — subtle blue bridge so mountains and camp share a plane.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#2D3A50").opacity(0.30),
                            Color(hex: "#22304A").opacity(0.27),
                            Color(hex: "#182338").opacity(0.22)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 1.62, height: height * 0.33)
                .position(x: width * 0.5, y: height * 0.89)
                .blur(radius: 12)

            // Forest floor — warm undertone radiating from the camp so the clearing feels lit.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#4A392C").opacity(0.28),
                            Color(hex: "#342922").opacity(0.18),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: max(width * 0.6, 200)
                    )
                )
                .frame(width: width * 1.62, height: height * 0.46)
                .position(x: width * 0.5, y: height * 0.95)
                .blur(radius: 11)

            // Snowcap overlay used on the tall back ridges — bright at the peaks, clears below.
            let snowCapMask = LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.95), location: 0.00),
                    .init(color: .white.opacity(0.55), location: 0.04),
                    .init(color: .white.opacity(0.18), location: 0.09),
                    .init(color: .clear, location: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Far back ridges — almost-black silhouettes (darker than the sky), sharp, snowcapped.
            Group {
                LeftMountainRidgeShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#080B14").opacity(0.96),
                                Color(hex: "#04060C").opacity(0.99)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        LeftMountainRidgeShape()
                            .fill(Color(hex: "#E8EEF8"))
                            .mask(snowCapMask)
                            .blendMode(.screen)
                    )
                    .frame(width: width * 1.58, height: height * 0.56)
                    .position(x: width * 0.42, y: height * 0.58)
                    .blur(radius: 0.6)

                SmallTrailingMountainShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#070A12").opacity(0.96),
                                Color(hex: "#03050A").opacity(0.99)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        SmallTrailingMountainShape()
                            .fill(Color(hex: "#E0E6F2"))
                            .mask(snowCapMask)
                            .blendMode(.screen)
                    )
                    .frame(width: width * 0.88, height: height * 0.42)
                    .position(x: width * 0.80, y: height * 0.61)
                    .blur(radius: 0.6)
            }

            // Foothills (closer): solid black silhouettes, very sharp. No snow at this elevation.
            Group {
                LeftMountainRidgeShape()
                    .fill(Color(hex: "#03050A").opacity(0.98))
                    .frame(width: width * 1.48, height: height * 0.32)
                    .position(x: width * 0.36, y: height * 0.82)
                    .blur(radius: 0.6)

                SmallTrailingMountainShape()
                    .fill(Color(hex: "#03050A").opacity(0.98))
                    .frame(width: width * 1.28, height: height * 0.30)
                    .position(x: width * 0.72, y: height * 0.84)
                    .blur(radius: 0.6)

                LeftMountainRidgeShape()
                    .fill(Color(hex: "#02030A").opacity(0.98))
                    .frame(width: width * 1.72, height: height * 0.22)
                    .position(x: width * 0.53, y: height * 0.88)
                    .blur(radius: 0.6)
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.00),
                        .init(color: .white, location: 0.72),
                        .init(color: .white.opacity(0.62), location: 0.84),
                        .init(color: .clear, location: 1.00)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Forest layout: trees ringed all around with a clearing carved out for the camp.
            // Four depth bands establish perspective — distant trees small/hazy, near trees large/sharp.

            // Density inverts with depth: dense deep forest at the back, sparse near the camp,
            // bare in the front (only corner anchors). Mimics a real clearing.

            // Horizon forest — densest layer, ~1.2% xFrac spacing for a continuous treeline.
            let horizonForestX: [Double] = [
                0.005, 0.018, 0.030, 0.043, 0.056, 0.069, 0.082, 0.095, 0.108,
                0.121, 0.134, 0.147, 0.160, 0.173, 0.186, 0.199, 0.212, 0.225,
                0.238, 0.251, 0.264, 0.277, 0.290, 0.303, 0.316, 0.329, 0.342,
                0.355, 0.368, 0.381, 0.394, 0.407, 0.420, 0.433, 0.446, 0.459,
                0.472, 0.485, 0.498, 0.511, 0.524, 0.537, 0.550, 0.563, 0.576,
                0.589, 0.602, 0.615, 0.628, 0.641, 0.654, 0.667, 0.680, 0.693,
                0.706, 0.719, 0.732, 0.745, 0.758, 0.771, 0.784, 0.797, 0.810,
                0.823, 0.836, 0.849, 0.862, 0.875, 0.888, 0.901, 0.914, 0.927,
                0.940, 0.953, 0.966, 0.979, 0.992
            ]
            // Back grove — frames the clearing on each side, plus one inset tree per side
            // so the immediate gaps don't read as empty without crowding the tent.
            let backGroveX: [Double] = [
                0.050, 0.105, 0.165, 0.225, 0.280, 0.318, 0.358,
                0.642, 0.682, 0.720, 0.775, 0.835, 0.895, 0.950
            ]
            // Mid grove — sparser still, just enough to define the inner clearing edge.
            let midGroveX: [Double] = [
                0.075, 0.155, 0.235, 0.305,
                0.695, 0.765, 0.845, 0.925
            ]
            // Tall foreground anchors framing both edges — the closest trees, biggest silhouettes.
            let foregroundAnchorX: [Double] = [0.028, 0.082, 0.918, 0.972]

            // Horizon forest — drawn first so everything else renders on top, including the tent.
            // Small, hazy, mostly hidden behind tent in the center band but visible elsewhere.
            ForEach(Array(horizonForestX.enumerated()), id: \.offset) { i, xFrac in
                let seed = Double(i) * 0.31 + 0.05
                let heightJitter = (seed * 1.7).truncatingRemainder(dividingBy: 1.0)
                let xJitter = ((seed * 2.1).truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.014
                let yJitter = sin(seed * 7.4) * 3.5
                let treeH = height * (0.075 + heightJitter * 0.060)
                let treeW = treeH * 0.55
                let sway = (breeze * 0.30 + sin(time * 0.36 + seed * 4.1) * 0.10) * 0.55
                // Higher up the panel = further away in perspective.
                let baseY = height * 0.760 + CGFloat(yJitter)
                PineTreeShape(seed: seed * 1.7)
                    .fill(Color(hex: "#0E1525").opacity(0.82))
                    .frame(width: treeW, height: treeH)
                    .blur(radius: 0.9)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                    .position(x: width * CGFloat(xFrac + xJitter), y: baseY)
            }

            // Back grove: framing trees on both sides, slightly larger and clearer than horizon.
            ForEach(Array(backGroveX.enumerated()), id: \.offset) { i, xFrac in
                let seed = Double(i) * 0.27 + 0.16
                let heightJitter = (seed * 1.8).truncatingRemainder(dividingBy: 1.0)
                let xJitter = ((seed * 2.3).truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.010
                let yJitter = sin(seed * 9.1) * 1.5
                let treeH = height * (0.18 + heightJitter * 0.06)
                let treeW = treeH * 0.54
                let sway = (breeze * 0.42 + sin(time * 0.42 + seed * 5.2) * 0.14) * 0.80
                let baseY = height * (0.816 + abs(0.5 - xFrac) * 0.020)
                PineTreeShape(seed: seed * 2.1)
                    .fill(Color(hex: "#172031").opacity(0.72))
                    .frame(width: treeW, height: treeH)
                    .blur(radius: 0.7)
                    .rotationEffect(.degrees(sway), anchor: .bottom)
                    .position(
                        x: width * CGFloat(xFrac + xJitter),
                        y: baseY + CGFloat(yJitter)
                    )
            }

            // Mid grove: the primary framing mass around the camp clearing — bigger than back, smaller than foreground.
            ForEach(Array(midGroveX.enumerated()), id: \.offset) { i, xFrac in
                let seed = Double(i) * 0.33 + 1.1
                let heightJitter = (seed * 1.6).truncatingRemainder(dividingBy: 1.0)
                let xJitter = ((seed * 2.0).truncatingRemainder(dividingBy: 1.0) - 0.5) * 0.012
                let yJitter = sin(seed * 8.2) * 1.9
                let treeH = height * (0.30 + heightJitter * 0.10)
                let treeW = treeH * 0.53
                let sway = (breeze * 0.72 + sin(time * 0.54 + seed * 4.6) * 0.21) * 1.45
                let baseY = height * (0.848 + abs(0.5 - xFrac) * 0.015)
                let rimBoost = max(0.0, (xFrac - 0.72) * 1.8)
                ZStack {
                    PineTreeShape(seed: seed * 1.9)
                        .fill(Color(hex: "#0C141F").opacity(0.76))
                    PineTreeShape(seed: seed * 1.9)
                        .fill(Color(hex: "#A9BDD8").opacity(0.045 + rimBoost * 0.035))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .clear, location: 0.57),
                                    .init(color: .white, location: 0.92),
                                    .init(color: .white, location: 1.00)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .frame(width: treeW, height: treeH)
                .blur(radius: 0.42)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .position(
                    x: width * CGFloat(xFrac + xJitter),
                    y: baseY + CGFloat(yJitter)
                )
                .zIndex(1.2)
            }

            // Foreground anchors: tallest trees on the panel — taller than the mountains so the
            // viewer reads them as much closer than the back range. Establishes real perspective.
            ForEach(Array(foregroundAnchorX.enumerated()), id: \.offset) { i, xFrac in
                let seed = Double(i) * 0.39 + 2.2
                let heightJitter = (seed * 1.5).truncatingRemainder(dividingBy: 1.0)
                let treeH = height * (0.78 + heightJitter * 0.20)
                let treeW = treeH * 0.46
                let sway = (breeze + sin(time * 0.66 + seed * 5.9) * 0.30) * 2.1
                let baseY = height * (0.985 + abs(0.5 - xFrac) * 0.01)
                ZStack {
                    PineTreeShape(seed: seed * 2.4)
                        .fill(Color(hex: "#060A11").opacity(0.95))
                    PineTreeShape(seed: seed * 2.4)
                        .fill(Color(hex: "#A9BDD8").opacity(xFrac > 0.9 ? 0.07 : 0.03))
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.00),
                                    .init(color: .clear, location: 0.60),
                                    .init(color: .white, location: 0.94),
                                    .init(color: .white, location: 1.00)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .frame(width: treeW, height: treeH)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .position(x: width * CGFloat(xFrac), y: baseY)
                .zIndex(1.8)
            }

            // Earthy clearing where the camp sits — warmed by the fire.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#5A3E2E").opacity(0.18 + fire * 0.10),
                            Color(hex: "#3A2A20").opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 200
                    )
                )
                .frame(width: width * 0.88, height: height * 0.25)
                .position(x: width * 0.5, y: campY + 74)
                .blur(radius: 11)

            // Visible clearing patch so the camp reads as a carved-out area.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#6B4A33").opacity(0.22 + fire * 0.06),
                            Color(hex: "#4B3526").opacity(0.28),
                            Color(hex: "#34271F").opacity(0.30)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width * 0.56, height: height * 0.125)
                .position(x: width * 0.5, y: campY + 66)
                .blur(radius: 3.2)

            // Slightly brighter center band keeps the clearing distinct from forest floor.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#8A613F").opacity(0.10 + fire * 0.04),
                            Color(hex: "#5D4331").opacity(0.06),
                            .clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 120
                    )
                )
                .frame(width: width * 0.48, height: height * 0.09)
                .position(x: width * 0.5, y: campY + 63)
                .blur(radius: 3.0)

            // Soft edge falloff to blend clearing into surrounding ground.
            Ellipse()
                .stroke(Color(hex: "#2B211A").opacity(0.16), lineWidth: 36)
                .frame(width: width * 0.68, height: height * 0.20)
                .position(x: width * 0.5, y: campY + 69)
                .blur(radius: 12)

            // Removed rectangular cool haze pass to avoid horizontal seam artifacts.

            let tentScale: CGFloat = 0.85 * sceneScale

            // Tent base shadow.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#06070B").opacity(0.58),
                            Color(hex: "#0A0D15").opacity(0.20),
                            .clear
                        ],
                        center: .center,
                        startRadius: 8,
                        endRadius: 62
                    )
                )
                .frame(width: 188 * tentScale, height: 46 * tentScale)
                .position(x: width * 0.5, y: campY + 58 * sceneScale)
                .blur(radius: 1.0)

            // Tight contact shadow directly under tent edge to remove "floating" look.
            Ellipse()
                .fill(Color.black.opacity(0.36))
                .frame(width: 142 * tentScale, height: 12 * tentScale)
                .position(x: width * 0.5, y: campY + 62 * sceneScale)
                .blur(radius: 1.2)

            // Tent — clean dome silhouette with light source passes (lamp inside, fire spill, moon rim).
            let lampPulse = 0.85 + 0.15 * sin(time * 0.9)
            let lampIntensity = lampStrength * lampPulse
            let fireSpill = max(0.2, glowProgress) * fire
            // Tent sits at the visual center of the camp.
            let tentX = width * 0.5
            ZStack {
                // Soft drop shadow.
                TentShape()
                    .fill(Color(hex: "#070910").opacity(0.40))
                    .offset(x: 0, y: 5)
                    .blur(radius: 5)

                // Main fabric — sits inside night palette so it doesn't out-bright the mountains.
                TentShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#3A4358"),
                                Color(hex: "#2A3146")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Soft cool tint so tent integrates with night palette.
                TentShape()
                    .fill(Color(hex: "#A7B7D6").opacity(0.08))
                    .blendMode(.softLight)

                // Lamp glow from inside — warm, pulsing while Pommy is "working" inside.
                TentShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFB060").opacity(0.30 * lampIntensity),
                                Color(hex: "#E8893A").opacity(0.16 * lampIntensity),
                                .clear
                            ],
                            center: UnitPoint(x: 0.5, y: 0.62),
                            startRadius: 8,
                            endRadius: 80
                        )
                    )
                    .blendMode(.plusLighter)

                // Fire → tent warm spill. Real lighting pass, not just a rim.
                TentShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#C46838").opacity(0.22 * fireSpill),
                                Color(hex: "#A04A20").opacity(0.12 * fireSpill),
                                .clear
                            ],
                            center: UnitPoint(x: 0.5, y: 1.05),
                            startRadius: 8,
                            endRadius: 110
                        )
                    )
                    .blendMode(.screen)

                // Moon → cool rim along the back/right edge of the tent.
                TentShape()
                    .fill(Color(hex: "#A9BDD8").opacity(0.18))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.00),
                                .init(color: .clear, location: 0.65),
                                .init(color: .white.opacity(0.7), location: 0.92),
                                .init(color: .white, location: 1.00)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blendMode(.plusLighter)

                // Apex stroke — soft white-to-clear along the ridge curve.
                TentShape()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.9
                    )
                    .blendMode(.plusLighter)
            }
            .frame(width: 180 * tentScale, height: 120 * tentScale)
            .scaleEffect(x: 1.0, y: 1.0 + sin(time * 0.4) * 0.005, anchor: .bottom)
            .position(x: tentX, y: campY + 13 * sceneScale)

            // Door — sits in front of the tent. Solid base + warm interior glow when lamp is on.
            ZStack {
                TentDoorShape()
                    .fill(Color(hex: "#0E1220").opacity(0.96))
                TentDoorShape()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFB060").opacity(0.55 * lampIntensity),
                                Color(hex: "#A05A20").opacity(0.30 * lampIntensity),
                                .clear
                            ],
                            center: UnitPoint(x: 0.5, y: 0.55),
                            startRadius: 2,
                            endRadius: 22
                        )
                    )
                    .blendMode(.plusLighter)
                TentDoorShape()
                    .stroke(Color(hex: "#7D849A").opacity(0.16), lineWidth: 1)
            }
            .frame(width: 56 * tentScale, height: 57 * tentScale)
            .rotationEffect(.degrees(breeze * 0.18), anchor: .bottom)
            .position(x: tentX, y: campY + 35 * sceneScale)

            // Door contact shadow grounds the entrance flap.
            Ellipse()
                .fill(Color.black.opacity(0.30))
                .frame(width: 44 * tentScale, height: 8 * tentScale)
                .position(x: tentX, y: campY + 61 * sceneScale)
                .blur(radius: 0.8)

            // Guy-lines + pegs with proper tie-point and ground embed so the rig feels planted.
            ForEach([-1.0, 1.0], id: \.self) { side in
                let direction = CGFloat(side)
                let lineStart = CGPoint(
                    x: tentX + direction * 75 * tentScale,
                    y: campY + 57 * sceneScale
                )
                let lineEnd = CGPoint(
                    x: tentX + direction * 112 * tentScale,
                    y: campY + 67 * sceneScale
                )

                Path { path in
                    path.move(to: lineStart)
                    path.addLine(to: lineEnd)
                }
                .stroke(
                    Color(hex: "#CDBA97").opacity(0.40),
                    style: StrokeStyle(lineWidth: max(0.9, 1.15 * sceneScale), lineCap: .round)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 0.9, y: 0.5)

                Circle()
                    .fill(Color(hex: "#BDA782").opacity(0.55))
                    .frame(width: 2.6 * sceneScale, height: 2.6 * sceneScale)
                    .position(x: lineStart.x, y: lineStart.y)
                    .shadow(color: Color.black.opacity(0.22), radius: 0.8, y: 0.4)

                Capsule()
                    .fill(Color(hex: "#9C845F").opacity(0.65))
                    .frame(width: 11 * sceneScale, height: 3.6 * sceneScale)
                    .rotationEffect(.degrees(side * 26))
                    .position(x: lineEnd.x, y: lineEnd.y - 0.4 * sceneScale)

                Circle()
                    .fill(Color(hex: "#2A1F17").opacity(0.28))
                    .frame(width: 9 * sceneScale, height: 3.1 * sceneScale)
                    .position(x: lineEnd.x, y: lineEnd.y + 1.4 * sceneScale)
                    .blur(radius: 0.7)

                Ellipse()
                    .fill(Color(hex: "#241A13").opacity(0.32))
                    .frame(width: 6 * sceneScale, height: 2.0 * sceneScale)
                    .position(x: lineEnd.x, y: lineEnd.y + 2.2 * sceneScale)
                    .blur(radius: 0.5)
            }

            // Fire scales with focus accumulated. Tiny embers early, full flame at goal.
            // Empty-state floor at 0.30 so a no-focus camp reads as "asleep, waiting" rather than dead.
            let fireScale = 0.30 + 0.70 * glowProgress
            // Periodic ember pop — every 25s, a brief brightness spike that mimics a crackle.
            let popPhase = time.truncatingRemainder(dividingBy: 25)
            let popBoost = popPhase < 0.4 ? (1.0 - popPhase / 0.4) * 0.6 : 0.0
            // Soft warm ember halo on the ground — radius and brightness grow with progress.
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#C8542A").opacity(0.16 * fire * fireScale * (1 + popBoost)),
                            Color(hex: "#8C3818").opacity(0.08 * fire * fireScale * (1 + popBoost)),
                            .clear
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: 60
                    )
                )
                .frame(width: 130 * sceneScale * (0.7 + 0.4 * fireScale),
                       height: 46 * sceneScale * (0.7 + 0.4 * fireScale))
                .position(x: width * 0.5, y: logY + 3 * sceneScale)
                .blur(radius: 6 * sceneScale)

            // Charred logs.
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#2A1E18").opacity(0.98),
                                Color(hex: "#100A08").opacity(0.99)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 60 * sceneScale, height: 10 * sceneScale)
                    .rotationEffect(.degrees(18))
                    .shadow(color: Color.black.opacity(0.22), radius: 1.5, y: 1)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#26190E").opacity(0.98),
                                Color(hex: "#0E0905").opacity(0.99)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 56 * sceneScale, height: 10 * sceneScale)
                    .rotationEffect(.degrees(-17))
                    .shadow(color: Color.black.opacity(0.20), radius: 1.5, y: 1)

                // Ash dusting across the wood.
                Capsule()
                    .fill(Color(hex: "#6E6862").opacity(0.22))
                    .frame(width: 34 * sceneScale, height: 1.8 * sceneScale)
                    .rotationEffect(.degrees(18))
                    .offset(x: -4 * sceneScale, y: -1 * sceneScale)
                Capsule()
                    .fill(Color(hex: "#6A645E").opacity(0.20))
                    .frame(width: 30 * sceneScale, height: 1.6 * sceneScale)
                    .rotationEffect(.degrees(-17))
                    .offset(x: 4 * sceneScale, y: 1 * sceneScale)
            }
            .position(x: width * 0.5, y: logY)

            // Smoldering ember bed — heart of the fire. Bed size scales with progress.
            ZStack {
                // Soft inner glow under the ember cluster.
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FF6020").opacity(0.45 * fire * fireScale),
                                Color(hex: "#A02810").opacity(0.22 * fire * fireScale),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 18
                        )
                    )
                    .frame(width: 44 * sceneScale * (0.6 + 0.5 * fireScale),
                           height: 16 * sceneScale * (0.6 + 0.5 * fireScale))
                    .blur(radius: 3 * sceneScale)

                // Hot pulsing coals — different phases so they breathe independently.
                ForEach(0..<9, id: \.self) { i in
                    let seed = Double(i) * 0.37
                    let pulse = (sin(time * (1.6 + seed * 0.4) + seed * 5) + 1) * 0.5
                    let heatColor = i.isMultiple(of: 3)
                        ? Color(hex: "#FFB060")
                        : Color(hex: "#FF6028")
                    Circle()
                        .fill(heatColor.opacity(0.55 + pulse * 0.40 * fire))
                        .frame(width: (1.8 + seed * 1.2) * sceneScale, height: (1.8 + seed * 1.2) * sceneScale)
                        .offset(
                            x: (-16 + (seed * 1.7).truncatingRemainder(dividingBy: 1.0) * 32) * sceneScale,
                            y: (-2 + sin(seed * 4) * 3) * sceneScale
                        )
                        .blur(radius: 0.4)
                }

                // Occasional bright pulsing coal — the last hot spot.
                Circle()
                    .fill(Color(hex: "#FFD080").opacity(0.55 + (sin(time * 1.8) + 1) * 0.20 * fire))
                    .frame(width: 3.2 * sceneScale, height: 3.2 * sceneScale)
                    .offset(x: -2 * sceneScale, y: -1 * sceneScale)
                    .blur(radius: 0.6)
            }
            .position(x: width * 0.5, y: logY - 1 * sceneScale)

            // Occasional ember floating up — rare, slow.
            ForEach(0..<4, id: \.self) { i in
                let seed = Double(i) * 0.31
                let progress = (time * 0.22 + seed).truncatingRemainder(dividingBy: 1.0)
                let drift = sin(time * 1.2 + seed * 7) * (3 + progress * 5)
                let sx = width * 0.5 + CGFloat(drift)
                let sy = logY - 4 * sceneScale - CGFloat(progress * 50 * sceneScale)
                let opacity = pow(1.0 - progress, 1.6) * 0.7 * fire
                Circle()
                    .fill(Color(hex: "#FFB060").opacity(opacity))
                    .frame(width: 1.4 * sceneScale, height: 1.4 * sceneScale)
                    .position(x: sx, y: sy)
                    .blur(radius: 0.3)
            }

            // Smoke — only meaningful once a fire is going. Fully hidden in the empty state.
            let plumeSway = sin(slowPhase * 0.42) * 1.8
            let smokeCount = glowProgress < 0.02 ? 0 : max(2, Int((4.0 + 6.0 * glowProgress).rounded()))
            let smokeOpacityScale = 0.4 + 0.6 * glowProgress
            ForEach(Array(0..<smokeCount), id: \.self) { i in
                let seed = Double(i) * 0.187
                let progress = (slowPhase * 0.16 + seed).truncatingRemainder(dividingBy: 1.0)
                let y = CGFloat(logY) - 8 - CGFloat(progress * 150)
                let curl = sin(slowPhase * 0.95 + seed * 8.2) * (5.0 + progress * 14.0)
                let x = width * 0.5 + CGFloat(curl + plumeSway)
                let opacity = pow(1.0 - progress, 1.25) * 0.28 * smokeOpacityScale
                Ellipse()
                    .fill(Color(hex: "#A8A39B").opacity(opacity))
                    .frame(width: 9 + progress * 26, height: 7 + progress * 16)
                    .rotationEffect(.degrees(sin(seed * 8) * 22))
                    .position(x: x, y: y)
                    .blur(radius: 2.0 + progress * 3.6)
            }

            // Pommy sleeping just outside the tent door, near the fire's warmth.
            // Walks from the door threshold to a rest spot a few pixels in front of it.
            if dailyGoalMet {
                let walkT = max(0.0, min(1.0, (choreographyElapsed - 1.0) / 1.5))
                let walkEase = walkT * walkT * (3 - 2 * walkT)
                // Start: at the door. End: just outside, slightly toward the fire.
                let doorX = tentX
                let doorY = campY + 50 * sceneScale
                let restX = tentX + 10 * sceneScale
                let restY = campY + 56 * sceneScale
                let pommyX = doorX + (restX - doorX) * CGFloat(walkEase)
                let pommyY = doorY + (restY - doorY) * CGFloat(walkEase)
                let pommyOpacity = walkEase
                PommyMascot(
                    pose: .sleep,
                    size: 26 * sceneScale,
                    cheekTint: Color(hex: "#FF6B5B"),
                    chatty: false,
                    cadence: .decorative,
                    activityMode: activityMode
                )
                    .opacity(pommyOpacity)
                    .position(x: pommyX, y: pommyY)
                    .allowsHitTesting(false)
            }

            // "Day's work done" message — appears 3.5s after goal met, persists 5s, then fades.
            if dailyGoalMet {
                let msgFadeIn = max(0.0, min(1.0, (choreographyElapsed - 3.5) / 0.6))
                let msgFadeOut = max(0.0, min(1.0, (choreographyElapsed - 8.5) / 0.6))
                let msgOpacity = msgFadeIn * (1.0 - msgFadeOut)
                if msgOpacity > 0.01 {
                    Text("Day's work done. Rest well.")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.4)
                        .foregroundStyle(Color(hex: "#F4ECDA").opacity(0.92))
                        .shadow(color: Color.black.opacity(0.45), radius: 4, y: 1)
                        .opacity(msgOpacity)
                        .position(x: width * 0.5, y: height * 0.10)
                }
            }

            // Aurora ribbons — visible all week once the weekly focus goal is met.
            if weeklyGoalMet {
                let weeklyT = weeklyGoalMetAt.map { Date().timeIntervalSince($0) } ?? 99.0
                // Reveal: aurora fades in over 3s after weekly goal first met, then persists.
                let auroraOpacity = max(0.0, min(1.0, (weeklyT - 0.5) / 2.5))
                AuroraRibbonsView(width: width, height: height, time: time)
                    .opacity(auroraOpacity)

                // Sky brighten flash — first 0.5s after weekly goal.
                if weeklyT < 0.6 {
                    let flashT = max(0.0, 1.0 - weeklyT / 0.5)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: width, height: height)
                        .opacity(0.18 * flashT)
                        .blendMode(.plusLighter)
                }

                // "Week complete" message — 3s to 8s after weekly goal.
                let weeklyMsgIn = max(0.0, min(1.0, (weeklyT - 3.0) / 0.6))
                let weeklyMsgOut = max(0.0, min(1.0, (weeklyT - 8.0) / 0.6))
                let weeklyMsgOpacity = weeklyMsgIn * (1.0 - weeklyMsgOut)
                if weeklyMsgOpacity > 0.01 {
                    Text("Week complete · You did it.")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color(hex: "#E8F0DC").opacity(0.95))
                        .shadow(color: Color.black.opacity(0.55), radius: 5, y: 1)
                        .opacity(weeklyMsgOpacity)
                        .position(x: width * 0.5, y: height * 0.18)
                }
            }
        }
        .frame(width: width, height: height)
        .mask(SceneBandAlphaMask())
        .allowsHitTesting(false)
    }
}

@MainActor
private struct AuroraRibbonsView: View {
    let width: CGFloat
    let height: CGFloat
    let time: Double

    var body: some View {
        let baseY = height * 0.18
        let bands: [(color: Color, baseOffset: CGFloat, amplitude: CGFloat, freq: Double, phaseRate: Double, phase: Double, thickness: CGFloat)] = [
            (Color(hex: "#5EE39E"), -10, 16, 0.018, 0.30, 0.0,            22),
            (Color(hex: "#5EBFD9"),   8, 22, 0.014, 0.22, .pi * 2.0 / 3,  26),
            (Color(hex: "#9B7CE0"),  26, 18, 0.020, 0.18, .pi * 4.0 / 3,  20)
        ]
        return ZStack {
            ForEach(0..<bands.count, id: \.self) { i in
                let band = bands[i]
                AuroraRibbonShape(
                    width: width,
                    centerY: baseY + band.baseOffset,
                    amplitude: band.amplitude,
                    frequency: band.freq,
                    phase: time * band.phaseRate + band.phase,
                    thickness: band.thickness
                )
                .fill(
                    LinearGradient(
                        colors: [
                            band.color.opacity(0.0),
                            band.color.opacity(0.32),
                            band.color.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blur(radius: 6)
                .blendMode(.plusLighter)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .allowsHitTesting(false)
    }
}

private struct AuroraRibbonShape: Shape {
    let width: CGFloat
    let centerY: CGFloat
    let amplitude: CGFloat
    let frequency: Double
    let phase: Double
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 6
        let xs = stride(from: rect.minX, through: rect.maxX, by: step)
        var topPoints: [CGPoint] = []
        var bottomPoints: [CGPoint] = []
        for x in xs {
            let centerline = centerY + sin(Double(x) * frequency + phase) * Double(amplitude)
            topPoints.append(CGPoint(x: x, y: CGFloat(centerline) - thickness / 2))
            bottomPoints.append(CGPoint(x: x, y: CGFloat(centerline) + thickness / 2))
        }
        guard let firstTop = topPoints.first else { return p }
        p.move(to: firstTop)
        for pt in topPoints.dropFirst() { p.addLine(to: pt) }
        for pt in bottomPoints.reversed() { p.addLine(to: pt) }
        p.closeSubpath()
        return p
    }
}

private struct TentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let apex = CGPoint(x: rect.midX, y: rect.minY)
        let leftBase = CGPoint(x: rect.minX, y: rect.maxY)
        let rightBase = CGPoint(x: rect.maxX, y: rect.maxY)
        p.move(to: leftBase)
        p.addQuadCurve(
            to: apex,
            control: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.30)
        )
        p.addQuadCurve(
            to: rightBase,
            control: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.30)
        )
        p.closeSubpath()
        return p
    }
}

private struct TentDoorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.18),
                       control: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.44))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.maxY),
                       control: CGPoint(x: rect.maxX - rect.width * 0.23, y: rect.minY + rect.height * 0.44))
        p.closeSubpath()
        return p
    }
}

private struct SceneBandAlphaMask: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Subtle top-edge fade only — no side fade. Foreground anchors are now inset enough
            // that they don't need a horizontal mask.
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.00),
                            .init(color: .white.opacity(0.70), location: 0.025),
                            .init(color: .white, location: 0.08),
                            .init(color: .white, location: 1.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: w, height: h)
        }
    }
}

private struct LeftMountainRidgeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        // Asymmetric left massif: broader shoulder with a taller, offset peak.
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.13, y: rect.minY + rect.height * 0.66),
            control1: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.94),
            control2: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.72)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.22),
            control1: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.54),
            control2: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY + rect.height * 0.18)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.52),
            control1: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.58)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.62, y: rect.minY + rect.height * 0.44),
            control1: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.minY + rect.height * 0.46),
            control2: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.38)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.80, y: rect.minY + rect.height * 0.72),
            control1: CGPoint(x: rect.minX + rect.width * 0.67, y: rect.minY + rect.height * 0.52),
            control2: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.74)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.86),
            control1: CGPoint(x: rect.minX + rect.width * 0.86, y: rect.minY + rect.height * 0.70),
            control2: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.82)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct SmallTrailingMountainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY + rect.height * 0.56),
            control1: CGPoint(x: rect.minX + rect.width * 0.05, y: rect.minY + rect.height * 0.92),
            control2: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.62)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.48, y: rect.minY + rect.height * 0.34),
            control1: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.minY + rect.height * 0.44),
            control2: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.minY + rect.height * 0.30)
        )
        p.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + rect.height * 0.62),
            control1: CGPoint(x: rect.minX + rect.width * 0.56, y: rect.minY + rect.height * 0.42),
            control2: CGPoint(x: rect.minX + rect.width * 0.63, y: rect.minY + rect.height * 0.66)
        )
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.84),
            control1: CGPoint(x: rect.minX + rect.width * 0.79, y: rect.minY + rect.height * 0.66),
            control2: CGPoint(x: rect.minX + rect.width * 0.92, y: rect.minY + rect.height * 0.80)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PineTreeShape: Shape {
    /// Per-tree seed — slightly perturbs tier widths, sags, and apex offsets so no two trees
    /// look identical. 0 yields the canonical silhouette. Real forests are not photocopies.
    var seed: Double = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()

        // Small narrow trunk — just a hint at the base, not a feature.
        let trunkWidth = rect.width * 0.05
        p.addRoundedRect(
            in: CGRect(
                x: rect.midX - trunkWidth / 2,
                y: rect.maxY - rect.height * 0.14,
                width: trunkWidth,
                height: rect.height * 0.13
            ),
            cornerSize: CGSize(width: trunkWidth * 0.38, height: trunkWidth * 0.38)
        )

        // Per-tier width / sag / horizontal offset jitter, seeded so each tree is unique
        // but stable across frames. Bounded so silhouettes still read as pines.
        func wj(_ i: Int) -> CGFloat { 1.0 + CGFloat(sin(seed * (1.7 + Double(i) * 0.6) + Double(i) * 1.3)) * 0.13 }
        func sj(_ i: Int) -> CGFloat { CGFloat(sin(seed * (3.4 + Double(i) * 0.5) + Double(i) * 2.1)) * 0.05 }
        func xj(_ i: Int) -> CGFloat { CGFloat(sin(seed * (2.8 + Double(i) * 0.4) + Double(i) * 1.7)) * 0.04 * rect.width }

        func addTier(top: CGFloat, width: CGFloat, height: CGFloat, sag: CGFloat, jitterIndex: Int) {
            let w = width * wj(jitterIndex)
            let s = sag + sj(jitterIndex)
            let xOff = xj(jitterIndex)
            let apex = CGPoint(x: rect.midX + xOff, y: rect.minY + top)
            let leftBase = CGPoint(x: rect.midX - w / 2, y: rect.minY + top + height * 0.82)
            let rightBase = CGPoint(x: rect.midX + w / 2, y: rect.minY + top + height * 0.82)
            // Slight droop on the left vs right edge so the silhouette isn't perfectly symmetric.
            let leftCtrl = CGPoint(
                x: rect.midX - w * 0.30 + xOff * 0.5,
                y: rect.minY + top + height * (0.45 + Double(sj(jitterIndex + 5)))
            )
            let rightCtrl = CGPoint(
                x: rect.midX + w * 0.30 + xOff * 0.5,
                y: rect.minY + top + height * (0.45 - Double(sj(jitterIndex + 7)))
            )
            p.move(to: apex)
            p.addQuadCurve(to: rightBase, control: rightCtrl)
            p.addQuadCurve(
                to: leftBase,
                control: CGPoint(x: rect.midX + xOff, y: rect.minY + top + height * s)
            )
            p.addQuadCurve(to: apex, control: leftCtrl)
            p.closeSubpath()
        }

        // Four tiers — narrow tip, full base. Each tier's width, sag and apex offset are jittered
        // so each tree has its own slightly-irregular silhouette without breaking the pine shape.
        addTier(top: rect.height * 0.00, width: rect.width * 0.34, height: rect.height * 0.24, sag: 0.94, jitterIndex: 0)
        addTier(top: rect.height * 0.18, width: rect.width * 0.58, height: rect.height * 0.30, sag: 0.92, jitterIndex: 1)
        addTier(top: rect.height * 0.40, width: rect.width * 0.80, height: rect.height * 0.34, sag: 0.90, jitterIndex: 2)
        addTier(top: rect.height * 0.62, width: rect.width * 1.00, height: rect.height * 0.30, sag: 0.88, jitterIndex: 3)
        return p
    }
}

@MainActor
private struct FireflyGlyph: View {
    let styleSeed: Int
    let time: Double
    let glow: Double
    let opacity: Double

    private var isBlinking: Bool {
        let phase = sin(time * 0.95 + Double(styleSeed) * 1.5 + 0.6)
        return phase > 0.965
    }

    var body: some View {
        ZStack {
            // Soft aura around the body — additive so fireflies actually light the scene.
            // Bigger and brighter relative to the (smaller) body so the glow reads first.
            Circle()
                .fill(Color(hex: "#FFE86B").opacity(0.36 * glow * opacity))
                .frame(width: 56 + glow * 56, height: 56 + glow * 56)
                .blur(radius: 14)
                .blendMode(.plusLighter)

            // Inner halo — adds a tighter bright bloom right around the body.
            Circle()
                .fill(Color(hex: "#FFF1B8").opacity(0.45 * glow * opacity))
                .frame(width: 22 + glow * 14, height: 22 + glow * 14)
                .blur(radius: 5)
                .blendMode(.plusLighter)

            // Wings — subtle flap in opposing phases. Smaller to match the smaller body.
            let flapL = sin(time * 8 + Double(styleSeed) * 4) * 8
            let flapR = sin(time * 8 + Double(styleSeed) * 4 + .pi) * 8
            Ellipse()
                .fill(Color(hex: "#DCE8F4").opacity(0.42 * opacity))
                .frame(width: 13, height: 8)
                .rotationEffect(.degrees(24 + flapL))
                .offset(x: -6, y: -3.5)
            Ellipse()
                .fill(Color(hex: "#DCE8F4").opacity(0.42 * opacity))
                .frame(width: 13, height: 8)
                .rotationEffect(.degrees(-24 + flapR))
                .offset(x: 6, y: -3.5)

            // Single glowing body core — smaller, with a brighter outer stroke for that lit-from-within feel.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "#FFFAD4").opacity((0.92 + glow * 0.08) * opacity),
                            Color(hex: "#FFD84A").opacity((0.74 + glow * 0.20) * opacity)
                        ],
                        center: .center,
                        startRadius: 0.5,
                        endRadius: 6
                    )
                )
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#FFF3AA").opacity(0.62 * glow * opacity), lineWidth: 0.8)
                )

            faceLayer
        }
    }

    @ViewBuilder
    private var faceLayer: some View {
        if isBlinking {
            ArcSmile(upsideDown: true)
                .stroke(Color(hex: "#4A3728").opacity(0.95 * opacity), lineWidth: 1.0)
                .frame(width: 2.2, height: 1.2)
                .offset(x: -1.7, y: -1.3)
            ArcSmile(upsideDown: true)
                .stroke(Color(hex: "#4A3728").opacity(0.95 * opacity), lineWidth: 1.0)
                .frame(width: 2.2, height: 1.2)
                .offset(x: 1.7, y: -1.3)
        } else {
            Circle()
                .fill(Color.white.opacity(0.95 * opacity))
                .frame(width: 1.9, height: 1.9)
                .offset(x: -1.7, y: -1.3)
            Circle()
                .fill(Color.white.opacity(0.95 * opacity))
                .frame(width: 1.9, height: 1.9)
                .offset(x: 1.7, y: -1.3)
            Circle()
                .fill(Color(hex: "#3D2C20").opacity(0.92 * opacity))
                .frame(width: 0.8, height: 0.8)
                .offset(x: -1.7, y: -1.3)
            Circle()
                .fill(Color(hex: "#3D2C20").opacity(0.92 * opacity))
                .frame(width: 0.8, height: 0.8)
                .offset(x: 1.7, y: -1.3)
        }

        // Low-key smile to keep it natural.
        ArcSmile(upsideDown: false)
            .stroke(Color(hex: "#3F2F23").opacity(0.78 * opacity), lineWidth: 0.8)
            .frame(width: 2.1, height: 1.0)
            .offset(y: 0.7)
        }
    }

private struct ArcSmile: Shape {
    var upsideDown: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        if upsideDown {
            p.addArc(
                center: CGPoint(x: rect.midX, y: rect.maxY),
                radius: rect.width / 2,
                startAngle: .degrees(200),
                endAngle: .degrees(340),
                clockwise: false
            )
        } else {
            p.addArc(
                center: CGPoint(x: rect.midX, y: rect.minY),
                radius: rect.width / 2,
                startAngle: .degrees(20),
                endAngle: .degrees(160),
                clockwise: false
            )
        }
        return p
    }
}
