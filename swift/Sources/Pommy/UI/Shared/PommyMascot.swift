import SwiftUI

// MARK: - Mascot pose

enum MascotPose: String, Codable {
    /// Calm, eyes open, gentle breathing. Default presence.
    case idle
    /// Eyes closed, slight forward lean — used while a focus session runs.
    case focus
    /// Eyes closed + Z's overhead — used in the Rest screen.
    case sleep
    /// One small arm up, slight bounce — used in Saved banner / greetings.
    case wave
    /// Both arms up, eyes happy — used for streak milestones.
    case celebrate
    /// Half-hidden, peeking from a corner, used for low-key idle accent.
    case peek
    /// Eyes downcast, mouth flat, used for discard hover and sync errors.
    case sad
    /// Tilted head, alert, used for sync-in-progress.
    case curious
    /// Headband on, eyes squinted, determined. Used during focus overflow.
    case focusHard
}

// MARK: - PommyMascot

/// Vector tomato character. Pure SwiftUI — scales without quality loss and
/// can be re-tinted/animated freely.
@MainActor
struct PommyMascot: View {
    enum Cadence {
        case hero
        case decorative
    }

    var pose: MascotPose = .idle
    /// Visual scale. The body is 100×100 at scale 1.0.
    var size: CGFloat = 100
    /// Optional category tint applied as a soft cheek glow.
    var cheekTint: Color = Color(hex: "#FF6B5B")
    /// When true, tapping the mascot triggers a small "tap to chat" Easter
    /// egg where Pommy plays a randomized skit and ends with a focus nudge.
    /// The chat appears in a system popover so it can extend beyond panel
    /// bounds without clipping.
    var chatty: Bool = false
    var cadence: Cadence = .hero
    var activityMode: AnimationActivityMode = .full

    @State private var chatBeats: [PommyBeat] = []
    @State private var chatIndex: Int = 0
    @State private var chatTask:  Task<Void, Never>? = nil

    /// The pose we actually render. While a chat is in progress we override
    /// the caller-provided pose with the current beat's pose so expressions
    /// follow the conversation.
    private var displayPose: MascotPose {
        guard !chatBeats.isEmpty, chatIndex < chatBeats.count else { return pose }
        return chatBeats[chatIndex].pose
    }

    private var isChatting: Bool { !chatBeats.isEmpty }

    // Brand palette
    private let bodyTop      = Color(hex: "#F25E4D")
    private let bodyBottom   = Color(hex: "#C73B2C")
    private let bodyShadow   = Color(hex: "#9A2F22")
    private let stemDark     = Color(hex: "#3F6B4D")
    private let stemLight    = Color(hex: "#5C8C6B")
    private let highlightCol = Color.white.opacity(0.25)

    private var minimumInterval: Double {
        switch (activityMode, cadence) {
        case (.full, .hero): return 1.0 / 30.0
        case (.full, .decorative): return 1.0 / 15.0
        case (.throttled, .hero): return 1.0 / 15.0
        case (.throttled, .decorative): return 1.0 / 8.0
        case (.frozen, _): return 60.0
        }
    }

    var body: some View {
        // When frozen, render a single static frame and skip TimelineView entirely.
        // TimelineView at any minimumInterval still wakes the SwiftUI graph + CA
        // transaction loop on every tick; the only way to truly idle is to not
        // schedule a timeline at all.
        Group {
            if activityMode == .frozen {
                renderedBody(at: Date().timeIntervalSinceReferenceDate)
            } else {
                TimelineView(.animation(minimumInterval: minimumInterval)) { context in
                    renderedBody(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .onDisappear {
            chatTask?.cancel()
            chatTask = nil
        }
    }

    @ViewBuilder
    private func renderedBody(at t: Double) -> some View {
        let blink = t.truncatingRemainder(dividingBy: 4.0) < 0.14
        ZStack {
            // Soft shadow under the body
            Ellipse()
                .fill(Color.black.opacity(0.35))
                .frame(width: size * 0.75, height: size * 0.10)
                .blur(radius: size * 0.04)
                .offset(y: size * 0.50)

            mascot(time: t, blink: blink)
                .frame(width: size, height: size)
                .scaleEffect(scaleForBreath(time: t))
                .rotationEffect(.degrees(headTilt))
                .offset(y: bounceOffset(time: t))
        }
        .frame(width: size, height: size * 1.1)
        // Only become tappable when chatty; otherwise let parents (e.g. a
        // surrounding Button on a card) receive the tap.
        .contentShape(Rectangle())
        .allowsHitTesting(chatty)
        .onTapGesture { if chatty { handleChatTap() } }
        .popover(isPresented: chatPopoverBinding,
                 attachmentAnchor: .rect(.bounds),
                 arrowEdge: .top) {
            if let beat = currentBeat {
                PommyChatBubbleContent(text: beat.text, tint: cheekTint)
                    .padding(4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: chatIndex)
        .animation(.easeInOut(duration: 0.25), value: isChatting)
    }

    private var currentBeat: PommyBeat? {
        guard isChatting, chatIndex < chatBeats.count else { return nil }
        return chatBeats[chatIndex]
    }

    /// Drives the system popover; we only honor open=false (auto-dismiss).
    private var chatPopoverBinding: Binding<Bool> {
        Binding(
            get: { isChatting && currentBeat != nil },
            set: { isOpen in
                if !isOpen && isChatting { endChat() }
            }
        )
    }

    // MARK: - Tap-to-chat sequencer

    private func handleChatTap() {
        // Tap during a chat advances to the next beat (or ends it).
        if isChatting {
            chatTask?.cancel()
            advanceChat()
            return
        }

        let convo = PommyQuips.randomConversation()
        guard !convo.isEmpty else { return }
        chatBeats = convo
        chatIndex = 0
        scheduleAdvance(after: holdDuration(for: convo[0].text))
    }

    private func advanceChat() {
        let next = chatIndex + 1
        if next >= chatBeats.count {
            endChat()
            return
        }
        chatIndex = next
        scheduleAdvance(after: holdDuration(for: chatBeats[next].text))
    }

    private func endChat() {
        chatTask?.cancel()
        chatTask = nil
        chatBeats = []
        chatIndex = 0
    }

    private func scheduleAdvance(after seconds: Double) {
        chatTask?.cancel()
        chatTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            advanceChat()
        }
    }

    /// Reading time per beat: short floor + ~50ms per character so longer lines
    /// stay on screen long enough to read comfortably.
    private func holdDuration(for text: String) -> Double {
        let chars = Double(text.count)
        return max(1.6, min(5.0, 1.2 + chars * 0.045))
    }

    @ViewBuilder
    private func mascot(time t: Double, blink: Bool) -> some View {
        ZStack {
            arms(time: t)

            ZStack {
                // Body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [bodyTop, bodyBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // Bottom shadow band — gives a sense of weight
                Ellipse()
                    .fill(bodyShadow.opacity(0.4))
                    .frame(width: size * 0.78, height: size * 0.30)
                    .offset(y: size * 0.30)
                    .blur(radius: size * 0.05)
                    .blendMode(.multiply)

                // Top-left specular highlight
                Ellipse()
                    .fill(highlightCol)
                    .frame(width: size * 0.30, height: size * 0.18)
                    .offset(x: -size * 0.18, y: -size * 0.22)
                    .blur(radius: size * 0.02)

                // Cheeks (soft)
                cheek(offsetX: -size * 0.20)
                cheek(offsetX:  size * 0.20)

                face(blink: blink)

                if displayPose == .focusHard {
                    headband
                }

                stem
                    .offset(y: -size * 0.46)
            }
            .clipShape(Circle())
            .drawingGroup()
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )

            // Stem in front of clipped body so leaves pop above the silhouette
            stem
                .offset(y: -size * 0.46)

            zSparkles(time: t)
        }
    }

    // MARK: - Stem

    private var stem: some View {
        ZStack {
            Capsule()
                .fill(stemDark)
                .frame(width: size * 0.10, height: size * 0.18)

            // Leaf left
            leaf
                .frame(width: size * 0.32, height: size * 0.18)
                .rotationEffect(.degrees(-32))
                .offset(x: -size * 0.10, y: -size * 0.02)

            // Leaf right
            leaf
                .frame(width: size * 0.30, height: size * 0.16)
                .rotationEffect(.degrees(28))
                .offset(x:  size * 0.11, y: -size * 0.01)
        }
    }

    private var leaf: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [stemLight, stemDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    // MARK: - Face

    /// Hachimaki-style determined headband, drawn within the body clip.
    /// Includes a small red center dot and angled brow strokes for grit.
    private var headband: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                .fill(Color.white)
                .frame(width: size * 1.05, height: size * 0.10)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.02, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
                )
                .offset(y: -size * 0.22)

            Circle()
                .fill(Color(hex: "#E0413A"))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(y: -size * 0.22)

            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size * 0.10, y: -size * 0.025))
            }
            .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: size * 0.10, height: size * 0.05)
            .offset(x: -size * 0.20, y: -size * 0.10)

            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: size * 0.10, y: size * 0.025))
            }
            .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            .frame(width: size * 0.10, height: size * 0.05)
            .offset(x: size * 0.10, y: -size * 0.10)
        }
    }

    @ViewBuilder
    private func face(blink: Bool) -> some View {
        let eyeOffsetY: CGFloat = -size * 0.04

        if displayPose == .focus || displayPose == .sleep || displayPose == .focusHard {
            closedEye(at: -size * 0.16, y: eyeOffsetY)
            closedEye(at:  size * 0.16, y: eyeOffsetY)
        } else if displayPose == .celebrate {
            happyEye(at: -size * 0.16, y: eyeOffsetY)
            happyEye(at:  size * 0.16, y: eyeOffsetY)
        } else if displayPose == .sad {
            sadEye(at: -size * 0.16, y: eyeOffsetY)
            sadEye(at:  size * 0.16, y: eyeOffsetY)
        } else {
            openEye(at: -size * 0.16, y: eyeOffsetY, blink: blink)
            openEye(at:  size * 0.16, y: eyeOffsetY, blink: blink)
        }

        mouth
    }

    private func openEye(at x: CGFloat, y: CGFloat, blink: Bool) -> some View {
        Capsule()
            .fill(Color(hex: "#1B0E0A"))
            .frame(width: size * 0.06, height: blink ? size * 0.015 : size * 0.10)
            .offset(x: x, y: y)
            .animation(.easeInOut(duration: 0.12), value: blink)
    }

    private func closedEye(at x: CGFloat, y: CGFloat) -> some View {
        // A short curve — closed eye
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: size * 0.12, y: 0),
                           control: CGPoint(x: size * 0.06, y: -size * 0.04))
        }
        .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: size * 0.12, height: size * 0.05)
        .offset(x: x - size * 0.06, y: y)
    }

    private func sadEye(at x: CGFloat, y: CGFloat) -> some View {
        // Downcast curve, frowning eye
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: size * 0.12, y: 0),
                           control: CGPoint(x: size * 0.06, y: -size * 0.04))
        }
        .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: size * 0.12, height: size * 0.05)
        .offset(x: x - size * 0.06, y: y + size * 0.01)
    }

    private func happyEye(at x: CGFloat, y: CGFloat) -> some View {
        // Upside down arc — happy crescent
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: size * 0.12, y: 0),
                           control: CGPoint(x: size * 0.06, y: size * 0.05))
        }
        .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: size * 0.12, height: size * 0.05)
        .offset(x: x - size * 0.06, y: y - size * 0.02)
    }

    @ViewBuilder
    private var mouth: some View {
        let baseY = size * 0.16

        switch displayPose {
        case .sleep:
            // Tiny "o" mouth
            Circle()
                .fill(Color(hex: "#1B0E0A"))
                .frame(width: size * 0.05, height: size * 0.05)
                .offset(y: baseY)
        case .celebrate:
            // Wide smile
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: size * 0.22, y: 0),
                               control: CGPoint(x: size * 0.11, y: size * 0.08))
            }
            .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            .frame(width: size * 0.22, height: size * 0.06)
            .offset(x: -size * 0.11, y: baseY - size * 0.02)
        case .sad:
            // Frown (inverted curve)
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: size * 0.16, y: 0),
                               control: CGPoint(x: size * 0.08, y: -size * 0.05))
            }
            .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size * 0.16, height: size * 0.05)
            .offset(x: -size * 0.08, y: baseY + size * 0.02)
        case .curious:
            // Small "o", surprised
            Capsule()
                .fill(Color(hex: "#1B0E0A"))
                .frame(width: size * 0.05, height: size * 0.06)
                .offset(y: baseY)
        case .focusHard:
            // Flat determined line
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(Color(hex: "#1B0E0A"))
                .frame(width: size * 0.14, height: size * 0.025)
                .offset(y: baseY + size * 0.01)
        default:
            // Gentle curve smile
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                p.addQuadCurve(to: CGPoint(x: size * 0.16, y: 0),
                               control: CGPoint(x: size * 0.08, y: size * 0.05))
            }
            .stroke(Color(hex: "#1B0E0A"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size * 0.16, height: size * 0.04)
            .offset(x: -size * 0.08, y: baseY)
        }
    }

    private func cheek(offsetX x: CGFloat) -> some View {
        Ellipse()
            .fill(cheekTint.opacity(0.45))
            .frame(width: size * 0.16, height: size * 0.10)
            .blur(radius: size * 0.04)
            .offset(x: x, y: size * 0.06)
    }

    // MARK: - Arms (for wave / celebrate)

    @ViewBuilder
    private func arms(time t: Double) -> some View {
        switch displayPose {
        case .wave:
            // Right arm waves at sin phase 0
            arm(side: .right, raised: true, time: t, phase: 0)
        case .celebrate:
            // Both arms up, alternating phases for that celebratory look
            arm(side: .left,  raised: true, time: t, phase: 0)
            arm(side: .right, raised: true, time: t, phase: .pi)
        default:
            EmptyView()
        }
    }

    private enum ArmSide { case left, right }

    private func arm(side: ArmSide, raised: Bool, time t: Double, phase: Double = 0) -> some View {
        let dx: CGFloat    = (side == .right ? 1 : -1)
        let baseX          = dx * size * 0.43
        let baseY: CGFloat = raised ? -size * 0.10 : size * 0.10
        // Oscillates ±8° with period 1 s; phase offsets left/right in celebrate
        let waveAngle      = sin(t * 2 * .pi + phase) * 8.0
        let rotation: Double = raised ? (side == .right ? -28 : 28) + waveAngle : 0

        return Capsule()
            .fill(
                LinearGradient(
                    colors: [bodyTop, bodyBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.12, height: size * 0.30)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .offset(x: baseX, y: baseY)
    }

    // MARK: - Sleep Z's

    @ViewBuilder
    private func zSparkles(time t: Double) -> some View {
        if displayPose == .sleep {
            // Oscillates 0..1 with period 4.8 s, matching the original 2.4 s half-period
            let zOsc = CGFloat((sin(t * .pi / 2.4) + 1) / 2)
            ZStack {
                Text("z")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .offset(x: size * 0.30, y: -size * 0.30 - zOsc * 4)
                    .opacity(0.3 + Double(zOsc) * 0.7)
                Text("z")
                    .font(.system(size: size * 0.13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .offset(x: size * 0.42, y: -size * 0.42 - zOsc * 6)
                    .opacity(1.0 - Double(zOsc) * 0.6)
            }
        }
    }

    // MARK: - Animation helpers

    // Breath: period 6.4 s (3.2 s up, 3.2 s down), matching original easeInOut(duration:3.2)
    private func scaleForBreath(time t: Double) -> CGFloat {
        let osc = CGFloat(sin(t * .pi / 3.2))
        switch displayPose {
        case .sleep:  return 1.0 + osc * 0.04
        case .focus:  return 1.0 + osc * 0.022
        case .peek:   return 1.0
        default:      return 1.0 + osc * 0.015
        }
    }

    // Bounce: period ~1.1 s, matching original spring(response:0.55)
    private func bounceOffset(time t: Double) -> CGFloat {
        let osc = CGFloat((sin(t * 2 * .pi / 1.1) + 1) / 2)
        switch displayPose {
        case .celebrate: return -osc * size * 0.08
        case .wave:      return -osc * size * 0.02
        default:         return 0
        }
    }

    private var headTilt: Double {
        switch displayPose {
        case .curious: return -8
        case .sad:     return 4
        default:       return 0
        }
    }
}

// MARK: - Petal burst (used at streak milestones)

@MainActor
struct PetalBurst: View {
    var trigger: Int
    var color: Color = Color(hex: "#F0A06B")

    @State private var animate: Bool = false

    var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                petal(index: i)
            }
        }
        .onChange(of: trigger) { _, _ in
            animate.toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                animate.toggle()
            }
        }
    }

    private func petal(index i: Int) -> some View {
        let angle  = Double(i) / 10.0 * .pi * 2
        let dist: CGFloat = animate ? 70 : 0
        let dx     = CGFloat(cos(angle)) * dist
        let dy     = CGFloat(sin(angle)) * dist - (animate ? 20 : 0)

        return Capsule()
            .fill(color.opacity(animate ? 0.0 : 0.9))
            .frame(width: 6, height: 10)
            .rotationEffect(.degrees(Double(i) * 36))
            .offset(x: dx, y: dy)
            .animation(.easeOut(duration: 1.2), value: animate)
    }
}

// MARK: - Chat bubble (used by the tap-to-chat Easter egg)

/// Body text inside Pommy's chat popover. The system popover provides its
/// own background, arrow, and shadow so we only style the inner content.
@MainActor
struct PommyChatBubbleContent: View {
    let text: String
    var tint: Color = Color(hex: "#FF6B5B")

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(tint.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(minWidth: 200, maxWidth: 320, alignment: .leading)
    }
}
