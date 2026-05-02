import SwiftUI
import AppKit

// MARK: - App delegate (close = hide, not quit)

final class AppDelegate: NSObject, NSApplicationDelegate {

    static let hideOnCloseDelegate = HideOnCloseWindowDelegate()

    private var clickOutsideMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installClickOutsideToDismissEditing()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first(where: { $0.identifier?.rawValue == "main" })?
                .makeKeyAndOrderFront(nil)
        }
        return true
    }

    /// Resigns first responder whenever the user clicks anywhere that isn't
    /// an editable text view. SwiftUI doesn't do this on macOS by default —
    /// once a `TextField` takes focus it stays focused until the user tabs
    /// away or hits Return, which feels like the input has trapped them.
    private func installClickOutsideToDismissEditing() {
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = event.window else { return event }
            let location = event.locationInWindow
            let hit      = window.contentView?.hitTest(location)
            if !Self.isInsideEditableText(hit) {
                // Defer so the click still reaches its intended target first
                // (button taps, focus moves to another field, etc.).
                DispatchQueue.main.async {
                    if !Self.isInsideEditableText(window.firstResponder as? NSView) ||
                       !Self.isInsideEditableText(hit) {
                        window.makeFirstResponder(nil)
                    }
                }
            }
            return event
        }
    }

    private static func isInsideEditableText(_ view: NSView?) -> Bool {
        var current: NSView? = view
        while let v = current {
            if v is NSTextView { return true }
            if let field = v as? NSTextField, field.isEditable { return true }
            current = v.superview
        }
        return false
    }
}

// MARK: - Window delegate (close button hides, doesn't close)

private final class ObserverHolder {
    var token: NSObjectProtocol?
}

final class HideOnCloseWindowDelegate: NSObject, NSWindowDelegate {
    weak var appState: AppState?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Flip visibility before orderOut. orderOut does NOT fire willClose,
        // miniaturize, or any other observed notification — without this the
        // activity-mode signal stays at .throttled while the window is hidden.
        MainActor.assumeIsolated {
            appState?.setMainWindowVisibility(false)
        }

        if sender.styleMask.contains(.fullScreen) {
            // Hiding a fullscreen window leaves its Space behind as a black
            // screen. Exit fullscreen first, then hide once the transition ends.
            let center = NotificationCenter.default
            let holder = ObserverHolder()
            holder.token = center.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: sender,
                queue: .main
            ) { [weak sender] _ in
                sender?.orderOut(nil)
                if let t = holder.token { center.removeObserver(t) }
            }
            sender.toggleFullScreen(nil)
        } else {
            sender.orderOut(nil)
        }
        return false
    }
}

// MARK: - App

@main
struct PommyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var appState = AppState()

    var body: some Scene {
        Window("Pommy", id: "main") {
            ContentView()
                .environment(appState)
                .background(WindowConfigurator(appState: appState))
                .onAppear {
                    Task { await appState.onLaunch() }
                }
        }
        .defaultSize(width: 960, height: 660)
        .commands {
            pommyCommands
        }

        MenuBarExtra {
            MenuBarPopover()
                .environment(appState)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: pommyMenubarIcon)
                Text(appState.menubarLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Keyboard commands

    private var pommyCommands: some Commands {
        Group {
            CommandGroup(replacing: .appInfo) {
                Button("About Pommy") {}
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        appState.selectedPage = .settings
                    }
                    NSApp.windows
                        .first(where: { $0.identifier?.rawValue == "main" })?
                        .makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// MARK: - Menubar icon

/// Returns the app icon pre-sized to 16×16 pt so SwiftUI's Image(nsImage:)
/// renders it at the correct menubar height without any layout passes.
private var pommyMenubarIcon: NSImage {
    let copy = NSApp.applicationIconImage.copy() as! NSImage
    copy.size = NSSize(width: 16, height: 16)
    return copy
}

// MARK: - Root content view

@MainActor
struct ContentView: View {
    @Environment(AppState.self) private var appState

    @State private var showOnboarding: Bool = !UserDefaults.standard.hasCompletedOnboarding
    @State private var showShortcuts:  Bool = false
    /// Lifted from CalendarView so the right panel can rebalance Notes ↔ Calendar
    /// when a day's detail is showing. Initialized to today so the panel opens
    /// already in the expanded layout (no first-launch reflow).
    @State private var calendarSelectedDay: Date? = Date()

    private var ambientTint: Color {
        let key = appState.session.state == .idle
            ? appState.config.defaultCategory
            : appState.session.category
        return appState.config.color(for: key)
    }

    var body: some View {
        ZStack {
            mainContent

            // Hidden button captures `?` (shift+/) anywhere in the window
            Button("") {
                withAnimation(Motion.springSoft) { showShortcuts.toggle() }
            }
            .keyboardShortcut("?", modifiers: [.shift])
            .opacity(0)
            .frame(width: 0, height: 0)

            if showShortcuts {
                ShortcutOverlay {
                    withAnimation(Motion.springSoft) { showShortcuts = false }
                }
                .zIndex(50)
            }

            if showOnboarding {
                OnboardingView {
                    withAnimation(Motion.springSoft) { showOnboarding = false }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    private var mainContent: some View {
        HStack(spacing: 0) {
            SidebarView(onShowShortcuts: {
                withAnimation(Motion.springSoft) { showShortcuts.toggle() }
            })

            PommyDivider()

            leftPanel

            PommyDivider()

            rightPanel
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
        }
        .frame(minWidth: 820, minHeight: 540)
        .background(
            AmbientAppBackground(tint: ambientTint)
                .animation(.easeInOut(duration: 0.6), value: ambientTint)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var leftPanel: some View {
        ZStack {
            if appState.selectedPage == .timer       { TimerPanelView()      .transition(.opacity) }
            if appState.selectedPage == .stopwatch   { StopwatchPanelView()  .transition(.opacity) }
            if appState.selectedPage == .stats       { StatsView()           .transition(.opacity) }
            if appState.selectedPage == .mindfulness { MindfulnessView()     .transition(.opacity) }
            if appState.selectedPage == .settings    { SettingsView()        .transition(.opacity) }
        }
        .frame(minWidth: 280, maxWidth: .infinity)
    }

    private var rightPanel: some View {
        // When a calendar day is selected, the day detail needs room to breathe
        // — shrink Notes to a fixed band and let Calendar stretch. When nothing
        // is selected, Notes regains the leftover space.
        let calendarExpanded = calendarSelectedDay != nil
        return VStack(spacing: 0) {
            NotesView()
                .frame(
                    minHeight: 160,
                    maxHeight: calendarExpanded ? 220 : .infinity
                )
            PommyDivider(axis: .horizontal, inset: 14)
            CalendarView(selectedDay: $calendarSelectedDay)
                .frame(maxHeight: .infinity)
        }
        .animation(.easeInOut(duration: 0.25), value: calendarExpanded)
    }
}

// MARK: - Window configurator (installs hide-on-close delegate, restores position)

private struct WindowConfigurator: NSViewRepresentable {
    let appState: AppState

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            AppDelegate.hideOnCloseDelegate.appState = appState
            window.delegate = AppDelegate.hideOnCloseDelegate
            window.identifier = NSUserInterfaceItemIdentifier("main")
            window.setFrameAutosaveName("PommyMainWindow")
            context.coordinator.bind(window: window)
            appState.setMainWindowVisibility(window.isVisible)
            appState.setMainWindowKey(window.isKeyWindow)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.appState = appState
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    @MainActor
    final class Coordinator {
        var appState: AppState
        private var observers: [NSObjectProtocol] = []
        private weak var observedWindow: NSWindow?

        init(appState: AppState) {
            self.appState = appState
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func bind(window: NSWindow) {
            guard observedWindow !== window else { return }
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
            observedWindow = window

            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowKey(true)
                    self?.appState.setMainWindowVisibility(true)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowKey(false)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didMiniaturizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowVisibility(false)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didDeminiaturizeNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowVisibility(true)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowVisibility(false)
                }
            })
            // Authoritative visibility: AppKit reports occlusion state for hide,
            // Spaces switches, full-screen-app coverage, etc. orderOut does not
            // fire willClose/miniaturize, so this is the signal of last resort.
            observers.append(center.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                guard let window else { return }
                let isVisible = window.occlusionState.contains(.visible)
                MainActor.assumeIsolated {
                    self?.appState.setMainWindowVisibility(isVisible)
                }
            })
        }
    }
}
