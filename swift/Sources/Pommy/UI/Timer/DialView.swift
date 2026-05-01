import SwiftUI
import AppKit

/// Circular scroll-dial.
///
/// # Rotation model
/// A single signed accumulator (`totalAngle`, degrees) drives everything:
///   +  (clockwise)          → Focus, category-color arc fills CW from 12 o'clock
///   −  (counter-clockwise)  → Break, grey arc fills CCW from 12 o'clock
///
/// Dragging adds small unwrapped steps to the accumulator — no cap, keeps going
/// past 360° for long sessions. Tapping the centre opens an inline editor.
/// Preset buttons live below the dial in the parent view.
@MainActor
struct DialView: View {

    @Binding var minutes:     Int
    @Binding var sessionType: SessionType
    let categoryColor:        Color
    /// How many minutes equals one full revolution. Configurable in settings.
    var maxMinutes: Int = 120

    /// Degrees of rotation per minute, derived from `maxMinutes`.
    private var degreesPerMinute: Double { 360.0 / Double(maxMinutes) }

    // MARK: - Internal state

    @State private var totalAngle:    Double  = 0
    @State private var lastDragAngle: Double? = nil
    @State private var lastHapticMin: Int     = -1
    @State private var hovering:      Bool    = false

    // Centre-tap editing
    @State private var isEditing:  Bool   = false
    @State private var editText:   String = ""
    @FocusState private var editFocused: Bool

    // MARK: - Constants

    static  let diameter:          CGFloat = 200
    private static let lineWidth:  CGFloat = 8
    private static let trackAlpha: Double  = 0.06

    // MARK: - Body

    var body: some View {
        ZStack {
            trackRing
            fillArc
            terminusDot
            centerContent
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .contentShape(Circle().inset(by: -16))
        .gesture(dialDrag)
        .onHover { hovering = $0 }
    }

    // MARK: - Track + arc

    private var trackRing: some View {
        Circle()
            .stroke(
                Color.white.opacity(hovering ? Self.trackAlpha + 0.05 : Self.trackAlpha),
                lineWidth: Self.lineWidth
            )
            .frame(width: Self.diameter, height: Self.diameter)
            .animation(.easeOut(duration: 0.18), value: hovering)
    }

    private var fillArc: some View {
        let fraction = min(1.0, max(0.005, CGFloat(minutes) / CGFloat(maxMinutes)))
        let color    = sessionType == .focus ? categoryColor : Color(white: 0.43)
        let from = sessionType == .focus ? 0.0       : (1.0 - fraction)
        let to   = sessionType == .focus ? fraction  : 1.0

        return Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
            .frame(width: Self.diameter, height: Self.diameter)
            .rotationEffect(.degrees(-90))
            .animation(.easeInOut(duration: 0.25), value: sessionType)
    }

    /// Filled handle at the leading tip of the arc — sized to be easy to grab.
    private var terminusDot: some View {
        let fraction  = min(1.0, max(0.005, Double(minutes) / Double(maxMinutes)))
        let angleDeg  = sessionType == .focus
            ? -90.0 + fraction * 360.0
            :  270.0 - fraction * 360.0
        let angleRad  = angleDeg * .pi / 180.0
        let r         = Self.diameter / 2
        let dx        = CGFloat(cos(angleRad)) * r
        let dy        = CGFloat(sin(angleRad)) * r
        let color     = sessionType == .focus ? categoryColor : Color(white: 0.5)

        return ZStack {
            // Soft halo — both visual cue + larger perceived hit area
            Circle()
                .fill(color.opacity(0.4))
                .frame(width: 22, height: 22)
                .blur(radius: 5)
            // Inner outline ring, glassy
            Circle()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                .background(Circle().fill(color))
                .frame(width: 14, height: 14)
                .shadow(color: color.opacity(0.6), radius: 5)
        }
        .offset(x: dx, y: dy)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: minutes)
        .animation(.easeInOut(duration: 0.25), value: sessionType)
    }

    // MARK: - Centre content (display or editor)

    @ViewBuilder
    private var centerContent: some View {
        if isEditing {
            centreEditor
        } else {
            centreDisplay
                .onTapGesture { openEditor() }
                .contentShape(Rectangle())
        }
    }

    private var centreDisplay: some View {
        VStack(spacing: 2) {
            Text(timeString)
                .font(.system(size: 42, weight: .thin).monospacedDigit())
                .foregroundStyle(.primary)
            Text(sessionType == .focus ? "focus" : "break")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var centreEditor: some View {
        VStack(spacing: 8) {
            TextField("", text: $editText)
                .font(.system(size: 38, weight: .thin).monospacedDigit())
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .frame(width: 90)
                .focused($editFocused)
                .onSubmit { commitEdit() }
                .onExitCommand { cancelEdit() }

            // Focus / Break toggle
            HStack(spacing: 0) {
                typeButton("focus", type: .focus)
                typeButton("break", type: .break)
            }
            .background(Surface.fillSoft, in: Capsule())
        }
    }

    private func typeButton(_ label: String, type: SessionType) -> some View {
        let active = sessionType == type
        return Button {
            sessionType = type
            syncAngleFromType(type)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(active ? Surface.innerHighlight : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var timeString: String {
        let h = minutes / 60; let m = minutes % 60
        return h > 0 ? "\(h):\(String(format: "%02d", m))" : "\(m)"
    }

    // MARK: - Drag gesture

    private var dialDrag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if isEditing { cancelEdit() }

                let cx    = Self.diameter / 2
                let cy    = Self.diameter / 2
                let angle = atan2(
                    Double(value.location.y - cy),
                    Double(value.location.x - cx)
                ) * 180 / .pi

                if lastDragAngle == nil {
                    totalAngle    = sessionType == .focus
                                    ?  Double(minutes) * degreesPerMinute
                                    : -Double(minutes) * degreesPerMinute
                    lastDragAngle = angle
                    return
                }

                var step = angle - lastDragAngle!
                if step >  180 { step -= 360 }
                if step < -180 { step += 360 }

                totalAngle    += step
                lastDragAngle  = angle

                let newType = totalAngle >= 0 ? SessionType.focus : SessionType.break
                let newMins = max(1, Int(abs(totalAngle) / degreesPerMinute))
                if newType != sessionType { sessionType = newType }
                if newMins != minutes     { minutes = newMins; maybeHaptic(newMins) }
            }
            .onEnded { _ in lastDragAngle = nil }
    }

    // MARK: - Editor actions

    private func openEditor() {
        editText     = "\(minutes)"
        isEditing    = true
        editFocused  = true
    }

    private func commitEdit() {
        if let m = Int(editText.trimmingCharacters(in: .whitespaces)), m > 0 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                minutes = m
            }
            syncAngle()
            haptic()
        }
        isEditing   = false
        editFocused = false
    }

    private func cancelEdit() {
        isEditing   = false
        editFocused = false
    }

    // MARK: - Angle sync helpers

    private func syncAngle() {
        totalAngle = sessionType == .focus
                     ?  Double(minutes) * degreesPerMinute
                     : -Double(minutes) * degreesPerMinute
    }

    private func syncAngleFromType(_ type: SessionType) {
        totalAngle = type == .focus
                     ?  Double(minutes) * degreesPerMinute
                     : -Double(minutes) * degreesPerMinute
    }

    // MARK: - Haptics

    private func maybeHaptic(_ m: Int) {
        guard m != lastHapticMin else { return }
        lastHapticMin = m
        haptic()
    }

    private func haptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
