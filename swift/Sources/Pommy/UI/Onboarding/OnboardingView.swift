import SwiftUI
import AppKit

/// 3-card welcome flow shown on first launch.
@MainActor
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    let onDismiss: () -> Void

    @State private var step: Int = 0

    var body: some View {
        ZStack {
            // Backdrop
            LinearGradient(
                colors: [
                    Color(hex: "#1F1F26"),
                    Color(hex: "#16161A")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 40)

                content
                    .id(step)
                    .transition(.opacity.combined(with: .offset(y: 6)))

                Spacer()

                progressDots

                HStack {
                    Button("Skip") { finish() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary.opacity(0.55))

                    Spacer()

                    Button {
                        if step < 2 {
                            withAnimation(Motion.springSoft) { step += 1 }
                        } else {
                            finish()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(step < 2 ? "Continue" : "Let's go")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: step < 2 ? "arrow.right" : "checkmark")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .fill(brandTint.verticalGradient)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Surface.innerHighlight, lineWidth: 1)
                        )
                        .shadow(color: brandTint.opacity(0.4), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .pommyPress()
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
    }

    private var brandTint: Color {
        appState.config.color(for: appState.config.defaultCategory)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcomeCard
        case 1: categoriesCard
        default: mindfulnessCard
        }
    }

    // MARK: Card 0 — welcome

    private var welcomeCard: some View {
        VStack(spacing: 20) {
            PommyMascot(pose: .wave, size: 130, chatty: true)
            VStack(spacing: 8) {
                Text("Hi, I'm Pommy.")
                    .font(.system(size: 32, weight: .ultraLight))
                Text("I'm a focus timer. I look like a tomato. I will not apologize for either.")
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
    }

    // MARK: Card 1 — categories

    private var categoriesCard: some View {
        VStack(spacing: 18) {
            PommyMascot(pose: .idle, size: 80, cheekTint: brandTint)

            VStack(spacing: 6) {
                Text("Pick your categories")
                    .font(.system(size: 22, weight: .light))
                Text("I'll sort your sessions by these so you can see exactly which projects you've been ignoring. Edit them anytime in Settings.")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            HStack(spacing: 8) {
                ForEach(appState.config.categories.prefix(5), id: \.self) { cat in
                    let color = appState.config.color(for: cat)
                    Text(cat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(color.verticalGradient))
                        .shadow(color: color.opacity(0.35), radius: 8, y: 3)
                }
            }
            .padding(.top, 6)
        }
    }

    // MARK: Card 2 — mindfulness

    private var mindfulnessCard: some View {
        VStack(spacing: 16) {
            PommyMascot(pose: .sleep, size: 110)
            VStack(spacing: 6) {
                Text("Breathe. Seriously.")
                    .font(.system(size: 22, weight: .light))
                Text("There's a guided breathing exercise before focus and a rest mode between sessions. Turn them on. I will quietly notice if you don't.")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }

            // Toggles inline
            VStack(spacing: 8) {
                onboardingToggle(
                    title: "Breathe before each focus session",
                    isOn: Binding(
                        get: { appState.config.breatheBeforeFocus },
                        set: { v in
                            appState.config.breatheBeforeFocus = v
                            appState.saveConfig()
                        }
                    )
                )
            }
            .frame(maxWidth: 360)
            .padding(.top, 4)
        }
    }

    private func onboardingToggle(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.85))
        }
        .toggleStyle(.switch)
        .tint(brandTint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Surface.hairline, lineWidth: 1)
        )
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i == step ? brandTint : Color.white.opacity(0.15))
                    .frame(width: i == step ? 18 : 6, height: 6)
                    .animation(Motion.springSnap, value: step)
            }
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "pommy.onboarding.complete")
        onDismiss()
    }
}

extension UserDefaults {
    var hasCompletedOnboarding: Bool {
        bool(forKey: "pommy.onboarding.complete")
    }

    var hasCelebratedFirstSession: Bool {
        get { bool(forKey: "pommy.firstSession.celebrated") }
        set { set(newValue, forKey: "pommy.firstSession.celebrated") }
    }
}
