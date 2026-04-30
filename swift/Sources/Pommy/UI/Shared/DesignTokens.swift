import SwiftUI

// MARK: - Design tokens
//
// Single source of truth for the Pommy visual language.
// Every screen should draw from these tokens instead of using magic numbers,
// so that any tuning of the brand only happens here.
//
// Mood: calm, warm, intentional, breathing, crafted.

// MARK: Surfaces

enum Surface {
    /// Main app background. Slightly warmer than the previous `#1C1C1E`,
    /// but kept at the same luminance so colors retain their pop.
    static let base    = Color(hex: "#1B1B1F")
    /// Elevated panels / cards sitting on top of `base`.
    static let raised  = Color(hex: "#212126")
    /// Sidebar — a touch darker than the base for clearer separation.
    static let sidebar = Color(hex: "#16161A")
    /// Inset / sunken affordances (text fields, search).
    static let sunken  = Color(hex: "#131317")

    /// Subtle hairline border used on elevated surfaces and dividers.
    static let hairline       = Color.white.opacity(0.06)
    /// Slightly stronger top edge for a "lit from above" highlight.
    static let topHighlight   = Color.white.opacity(0.08)
    /// Soft inner highlight used inside gradient fills.
    static let innerHighlight = Color.white.opacity(0.18)

    // Translucent fill tints — for capsules, expanded rows, input bgs.
    // Use these instead of raw `Color.white.opacity(...)` so we have
    // a finite ladder of greys rather than a smear of values.
    /// 4% — barely-there row / pill background.
    static let fillFaint   = Color.white.opacity(0.04)
    /// 6% — soft fill, same level as `hairline`. Use for input bgs.
    static let fillSoft    = Color.white.opacity(0.06)
    /// 10% — assertive fill, used on secondary buttons.
    static let fillStrong  = Color.white.opacity(0.10)
}

// MARK: Radii

enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
}

// MARK: Spacing

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40
}

// MARK: Typography

extension Font {
    /// 56pt ultraLight — week-total / hero numerals.
    static let pommyDisplay = Font.system(size: 56, weight: .ultraLight).monospacedDigit()
    /// 42pt thin — dial timer / streak.
    static let pommyHero    = Font.system(size: 42, weight: .thin).monospacedDigit()
    /// 28pt ultraLight — page titles, breath phase.
    static let pommyTitle   = Font.system(size: 28, weight: .ultraLight)
    /// 20pt light — sub titles.
    static let pommySubtitle = Font.system(size: 20, weight: .light)
    /// 13pt regular — body / row labels.
    static let pommyBody     = Font.system(size: 13, weight: .regular)
    /// 13pt medium — emphasized body.
    static let pommyBodyEmph = Font.system(size: 13, weight: .medium)
    /// 11pt semibold uppercase — section labels (use with `.tracking(0.6)`).
    static let pommyLabel    = Font.system(size: 11, weight: .semibold)
    /// 10pt regular — captions / meta.
    static let pommyCaption  = Font.system(size: 10, weight: .regular)
}

// MARK: Motion

enum Motion {
    /// Slow, exhaled curve for breathing/glow effects.
    static let breath: Animation = .timingCurve(0.4, 0, 0.2, 1, duration: 0.6)
    /// Soft spring for content transitions, hover, expand/collapse.
    static let springSoft: Animation = .interpolatingSpring(stiffness: 140, damping: 18)
    /// Snappier spring for selection / pill movement.
    static let springSnap: Animation = .spring(response: 0.3, dampingFraction: 0.82)
    /// Quick fade for hover state.
    static let hover: Animation = .easeOut(duration: 0.18)
}

// MARK: - Color helpers (category palette extensions)

extension Color {
    /// A softer ambient version (~22% opacity) for background glows.
    var ambient: Color { self.opacity(0.22) }
    /// A subtle (~12%) tint for surface overlays.
    var subtle:  Color { self.opacity(0.12) }
    /// A faint (~6%) glaze used for hover / selected backgrounds.
    var glaze:   Color { self.opacity(0.06) }

    /// A vertical gradient suitable for filled CTAs and selected pills.
    /// Subtle drop (1.0 → 0.88) so colors retain their pop while still
    /// reading as "lit from above".
    var verticalGradient: LinearGradient {
        LinearGradient(
            colors: [self, self.opacity(0.88)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Brighter-to-darker angular gradient for ring strokes.
    /// Tightened: only an 18% drop in the middle stop so the ring stays
    /// vibrant while still showing depth.
    var ringGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                self,
                self.opacity(0.82),
                self
            ]),
            center: .center
        )
    }
}

// MARK: - Press / hover micro-interaction modifier

@MainActor
private struct PommyPressModifier: ViewModifier {
    @State private var pressed = false
    @State private var hovering = false
    var hoverScale: CGFloat = 1.02
    var pressScale: CGFloat = 0.96

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? pressScale : (hovering ? hoverScale : 1.0))
            .brightness(hovering && !pressed ? 0.04 : 0)
            .animation(Motion.springSnap, value: pressed)
            .animation(Motion.hover, value: hovering)
            .onHover { hovering = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true } }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    /// Adds a soft press + hover animation: hover scales up + lifts brightness,
    /// press dips down. Keeps interactions feeling "alive" without jitter.
    func pommyPress(hoverScale: CGFloat = 1.02, pressScale: CGFloat = 0.96) -> some View {
        modifier(PommyPressModifier(hoverScale: hoverScale, pressScale: pressScale))
    }
}

// MARK: - Soft glow shadow helper

extension View {
    /// Adds a soft ambient glow shadow tinted by `color`.
    /// Use for primary CTAs, ring overlays, hero numerals.
    func pommyGlow(_ color: Color, radius: CGFloat = 16, y: CGFloat = 6, opacity: Double = 0.35) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: y)
    }
}

// MARK: - Hairline border helper

extension View {
    /// Strokes a continuous rounded rectangle with a hairline white border
    /// to suggest a "lit from above" highlight on raised panels.
    func pommyHairline(cornerRadius: CGFloat = Radius.md, opacity: Double = 0.06) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(opacity), lineWidth: 1)
        )
    }
}

// MARK: - Ambient app background

/// Warm vertical gradient + a faint top-center category glow.
/// This is the single biggest "premium feel" lever — the app starts breathing
/// color subtly. Drop into the deepest container of any page that doesn't
/// already paint its own dark scene.
@MainActor
struct AmbientAppBackground: View {
    var tint: Color
    var intensity: Double = 0.07

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#22222A"),
                    Surface.base
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [tint.opacity(intensity), .clear],
                center: .init(x: 0.5, y: 0.0),
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Camp atmosphere tokens
//
// These tokens name the palette established by `TodayThemes.swift` so other
// screens can borrow accents (warm lamp, ember spill, starlight) without
// dragging in any of the literal scene elements (tents, fireflies, mountains).
//
// Use sparingly: the camp scene is the focal piece. Elsewhere these are for
// *accent* — selected pills, primary highlights — not surface fills.

enum Camp {
    /// Night-sky gradient stops, top → bottom. Used inside the camp scene;
    /// available here for any background that wants the same family.
    static let skyDeep = Color(hex: "#131722")
    static let skyMid  = Color(hex: "#111622")
    static let skyLow  = Color(hex: "#0D111A")

    /// Lamp inside the tent. Use for warm primary accents.
    static let lampWarm   = Color(hex: "#FFB060")
    /// Fire spill / ember halo. Slightly redder than `lampWarm`.
    static let emberWarm  = Color(hex: "#C46838")
    /// Starlight off-white — soft luminous text on dark surfaces.
    static let starWarm   = Color(hex: "#F4ECDA")
    /// Cool spike on bright stars / aurora. Pairs with `starWarm`.
    static let starCool   = Color(hex: "#DFE7FA")

    /// Subtle stroke used on the tent door etc. — readable on dark sky.
    static let strokeSubtle = Color(hex: "#7D849A").opacity(0.16)
}

// MARK: - Camp glow (two-layer plusLighter halo)

/// The same lit-object pattern the firefly and lamp use: a wide, soft outer
/// aura layered over a tighter inner halo, both `.plusLighter`. Drop on any
/// view to give it the "lit from within" feel without restructuring.
///
/// `active` toggles the glow on/off with smoothstep easing so it can be wired
/// straight to selection / running state.
extension View {
    func campGlow(
        active: Bool,
        tint: Color = Camp.lampWarm,
        outerRadius: CGFloat = 13,
        innerRadius: CGFloat = 5,
        outerOpacity: Double = 0.36,
        innerOpacity: Double = 0.45
    ) -> some View {
        self
            .shadow(color: tint.opacity(active ? outerOpacity : 0), radius: outerRadius, x: 0, y: 0)
            .shadow(color: tint.opacity(active ? innerOpacity : 0), radius: innerRadius, x: 0, y: 0)
            .animation(Motion.breath, value: active)
    }
}

// MARK: - Camp card chrome

/// A reusable raised-card surface in the camp idiom: `Surface.raised` fill,
/// hairline border, ambient drop shadow. Replaces ad-hoc `RoundedRectangle`
/// + `strokeBorder` recipes scattered through the UI.
extension View {
    func campCard(
        cornerRadius: CGFloat = Radius.md,
        fill: Color = Surface.raised,
        borderOpacity: Double = 0.06,
        shadowOpacity: Double = 0.30
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 5, x: 0, y: 5)
    }
}

// MARK: - Settings card + row chrome
//
// Replaces system `Form { Section { } }.formStyle(.grouped)` chrome — those
// system grouped panels paint their own grey backgrounds that visually float
// above `AmbientAppBackground`. These views give the same hierarchy but on
// the app's tokens, so settings reads as part of the same room.

@MainActor
struct PommySectionCard<Content: View>: View {
    let title: String?
    let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.pommyLabel)
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Surface.fillFaint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Surface.hairline, lineWidth: 1)
            )
        }
    }
}

/// Single row in a `PommySectionCard` — label on the left, control on the
/// right. Mimics SwiftUI's `LabeledContent` but on the app's tokens.
@MainActor
struct PommySettingsRow<Trailing: View>: View {
    let label: String
    let subtitle: String?
    let trailing: Trailing

    init(_ label: String, subtitle: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.label = label
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// Inline divider between rows of a `PommySectionCard`. Keeps spacing tight
/// since rows already pad themselves.
@MainActor
struct PommyRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Surface.hairline)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}

// MARK: - Secondary button chrome

/// A flat capsule/rect treatment used on validate / dismiss / open-link
/// secondary buttons. Replaces ad-hoc `Color.white.opacity(0.10)` capsules.
extension View {
    func pommySecondaryButton(
        cornerRadius: CGFloat = Radius.sm,
        horizontal: CGFloat = 14,
        vertical: CGFloat = 6
    ) -> some View {
        self
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Surface.fillStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Surface.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Eases

enum Ease {
    /// Smoothstep `t·t·(3 − 2t)` — the same curve TodayThemes uses for
    /// state transitions. Pass a normalized `0...1` value.
    static func smoothstep(_ t: Double) -> Double {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }
}

// MARK: - Soft divider

/// Vertical 1pt divider matching the Pommy hairline tone, slightly inset
/// so the columns "breathe". Use instead of `Divider()` between panels.
@MainActor
struct PommyDivider: View {
    var axis: Axis = .vertical
    var inset: CGFloat = 12

    var body: some View {
        Group {
            if axis == .vertical {
                Color.white.opacity(0.05)
                    .frame(width: 1)
                    .padding(.vertical, inset)
            } else {
                Color.white.opacity(0.05)
                    .frame(height: 1)
                    .padding(.horizontal, inset)
            }
        }
    }
}
