import SwiftUI

/// Stats panel — header band (mascot + calendar-week total + tiny garden + streak),
/// with Sunday→Saturday stacked bars and day selection.
@MainActor
struct StatsView: View {
    @Environment(AppState.self) private var appState

    private struct DayCategorySlice: Identifiable {
        let day: String
        let category: String
        let minutes: Int
        let color: Color

        var id: String { "\(day)-\(category)" }
    }

    @State private var selectedDate: String? = nil
    /// Timestamp when the daily focus goal was first met today. Drives the one-shot
    /// completion choreography in the Today scene. Cleared on date rollover.
    @State private var dailyGoalMetAt: Date? = nil
    @State private var weeklyGoalMetAt: Date? = nil
    @State private var trackedDayKey: String = SessionLog.isoDate(from: Date())

    // MARK: - Derived data

    private var weekDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1 = Sunday
        let start = today - TimeInterval((weekday - 1) * 86_400)
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var weekDateKeys: [String] {
        weekDates.map(SessionLog.isoDate(from:))
    }

    private var weekData: [(date: String, minutes: Int)] {
        let keys = Set(weekDateKeys)
        let focusEntries = appState.sessionLog.entries.filter {
            $0.isFocus && keys.contains($0.date)
        }
        var totals: [String: Int] = [:]
        for e in focusEntries { totals[e.date, default: 0] += e.duration_mins }
        return weekDateKeys.map { (date: $0, minutes: totals[$0, default: 0]) }
    }

    private var focusEntriesInWeek: [SessionEntry] {
        let keys = Set(weekDateKeys)
        return appState.sessionLog.entries.filter {
            $0.isFocus && keys.contains($0.date)
        }
    }

    private var weekTotal: Int {
        focusEntriesInWeek.reduce(0) { $0 + $1.duration_mins }
    }

    private var streak: Int {
        appState.sessionLog.focusStreak(minMinutes: appState.config.streakMinMinutes)
    }

    private var dailyCategorySlices: [String: [DayCategorySlice]] {
        var grouped: [String: [String: Int]] = [:]
        for e in focusEntriesInWeek {
            grouped[e.date, default: [:]][e.category, default: 0] += e.duration_mins
        }

        var result: [String: [DayCategorySlice]] = [:]
        for day in weekData.map(\.date) {
            let totals = grouped[day, default: [:]]
            result[day] = totals
                .sorted { $0.value > $1.value }
                .map {
                    DayCategorySlice(
                        day: day,
                        category: $0.key,
                        minutes: $0.value,
                        color: appState.config.color(for: $0.key)
                    )
                }
        }
        return result
    }

    private var bestDay: (label: String, minutes: Int)? {
        guard let top = weekData.max(by: { $0.minutes < $1.minutes }), top.minutes > 0 else { return nil }
        return (label: fullDayLabel(top.date), minutes: top.minutes)
    }

    private var heroTint: Color {
        appState.config.color(for: appState.config.defaultCategory)
    }

    private var todayFocusMinutes: Int {
        appState.sessionLog.todayFocusMinutes
    }

    private var todayUnitsCompleted: Int {
        todayFocusMinutes / 60
    }

    private var todayTheme: StatsTodayTheme {
        appState.config.statsTodayTheme
    }

    private var todayThemeHeight: CGFloat {
        switch todayTheme {
        case .fireflyJar:
            return 240
        }
    }

    /// 0…1 across the whole week. Drives the small companion plant beside
    /// the mascot in the header — full bloom when the week hits the user's
    /// configured weekly focus target.
    private var weeklyPlantGrowth: Double {
        let target = appState.config.weeklyFocusTargetMins
        guard target > 0 else { return 0 }
        return min(1.0, Double(weekTotal) / Double(target))
    }

    private var dailyGoalMet: Bool {
        let target = appState.config.dailyFocusTargetMins
        return target > 0 && todayFocusMinutes >= target
    }

    private var weeklyGoalMet: Bool {
        let target = appState.config.weeklyFocusTargetMins
        return target > 0 && weekTotal >= target
    }

    private var avgMinutes: Int {
        let total = weekData.reduce(0) { $0 + $1.minutes }
        return total / max(weekData.count, 1)
    }

    private var selectedDay: (date: String, minutes: Int) {
        let today  = SessionLog.isoDate(from: Date())
        let target = selectedDate ?? today
        return weekData.first(where: { $0.date == target })
            ?? (date: today, minutes: 0)
    }

    private var selectedDaySlices: [DayCategorySlice] {
        dailyCategorySlices[selectedDay.date, default: []]
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerRow
            chartSection
            todayGardenSection
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    // MARK: - Header (week total + mascot + plant + streak)

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("This week")
                HStack(alignment: .bottom, spacing: 10) {
                    Text(formatMinutes(weekTotal))
                        .font(.system(size: 48, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    HStack(alignment: .bottom, spacing: 4) {
                        PommyMascot(
                            pose: weekTotal > 0 ? .idle : .peek,
                            size: 40,
                            cheekTint: heroTint,
                            chatty: true,
                            cadence: .decorative,
                            activityMode: appState.effectiveAnimationMode
                        )
                        PlantView(growth: weeklyPlantGrowth, size: 44)
                    }
                    .padding(.bottom, 2)
                }
                if let best = bestDay {
                    Text("Best day · \(best.label) · \(formatMinutes(best.minutes))")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                sectionLabel("Streak")
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .ultraLight))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(streak == 1 ? "day" : "days")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if isMilestone {
                    Text("\(streak)-day milestone")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.4)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.orange.opacity(0.85))
                }
            }
        }
    }

    private static let milestones: Set<Int> = [3, 7, 14, 30, 50, 100]
    private var isMilestone: Bool { Self.milestones.contains(streak) }

    // MARK: - Chart

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title row: section label on the left, selected-day readout on the right.
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("This week")
                Spacer()
                HStack(spacing: 8) {
                    Text(fullDayLabel(selectedDay.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .id("daylabel-\(selectedDay.date)")
                        .transition(.opacity)
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(selectedDay.minutes > 0 ? formatMinutes(selectedDay.minutes) : "—")
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                }
            }

            if !selectedDaySlices.isEmpty {
                HStack(spacing: 8) {
                    ForEach(selectedDaySlices.prefix(3)) { slice in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(slice.color)
                                .frame(width: 5, height: 5)
                            Text("\(slice.category) \(formatMinutes(slice.minutes))")
                                .font(.system(size: 10, weight: .medium).monospacedDigit())
                                .foregroundStyle(.secondary.opacity(0.85))
                        }
                    }
                }
                .id("slices-\(selectedDay.date)")
                .transition(.opacity.combined(with: .offset(y: 2)))
            }

            chartBody
                .frame(height: 110)

            // Day axis
            HStack(spacing: 0) {
                ForEach(weekData, id: \.date) { day in
                    let isSelected = day.date == selectedDay.date
                    Text(shortDayLabel(day.date))
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.primary : Color.secondary.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .animation(Motion.springSnap, value: isSelected)
                }
            }
        }
        .animation(Motion.springSoft, value: selectedDay.date)
    }

    private var chartBody: some View {
        let cap = max(weekData.map(\.minutes).max() ?? 1, 1)

        return GeometryReader { geo in
            let availableHeight = geo.size.height - 12   // leave room for the dot above selected bar
            ZStack(alignment: .bottom) {
                // Dashed average line — Apple Health style.
                if avgMinutes > 0 {
                    let y = availableHeight * (1 - CGFloat(avgMinutes) / CGFloat(cap))
                    ZStack(alignment: .topTrailing) {
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(
                            Color.secondary.opacity(0.25),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                        )
                        Text("avg \(formatMinutes(avgMinutes))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.secondary.opacity(0.55))
                            .padding(.top, max(0, y - 12))
                    }
                }

                HStack(spacing: 0) {
                    ForEach(weekData, id: \.date) { day in
                        barColumn(day: day, cap: cap, plotHeight: availableHeight)
                    }
                }
            }
        }
    }

    private func barColumn(day: (date: String, minutes: Int), cap: Int, plotHeight: CGFloat) -> some View {
        let isSelected = day.date == selectedDay.date
        let slices     = dailyCategorySlices[day.date, default: []]
        let frac       = CGFloat(day.minutes) / CGFloat(cap)
        let barH       = max(day.minutes > 0 ? 2 : 0, frac * plotHeight)

        return Button {
            withAnimation(Motion.springSnap) {
                selectedDate = day.date
            }
        } label: {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                Circle()
                    .fill(heroTint)
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 1.0 : 0.0)
                    .scaleEffect(isSelected ? 1.0 : 0.6)
                if day.minutes > 0 {
                    VStack(spacing: 0) {
                        ForEach(slices) { slice in
                            Rectangle()
                                .fill(slice.color.opacity(isSelected ? 0.95 : 0.72))
                                .frame(
                                    width: 14,
                                    height: max(1, barH * CGFloat(slice.minutes) / CGFloat(day.minutes))
                                )
                        }
                    }
                    .frame(width: 14, height: barH, alignment: .bottom)
                    .clipShape(Capsule(style: .continuous))
                    .shadow(
                        color: heroTint.opacity(isSelected ? 0.30 : 0),
                        radius: isSelected ? 8 : 0,
                        y: isSelected ? 2 : 0
                    )
                } else {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 14, height: 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .contentShape(Rectangle())
            .animation(Motion.springSoft, value: isSelected)
        }
        .buttonStyle(.plain)
        .pommyPress(hoverScale: 1.05, pressScale: 0.92)
    }

    // MARK: - Today's garden

    private var todayGardenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Today")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(Color.secondary.opacity(0.65))

                if dailyGoalMet {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Goal complete")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.4)
                    }
                    .foregroundStyle(Color(hex: "#E8B68A"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color(hex: "#E8B68A").opacity(0.14))
                    )
                    .overlay(
                        Capsule().stroke(Color(hex: "#E8B68A").opacity(0.30), lineWidth: 0.5)
                    )
                }

                Spacer()
                Text("\(todayTheme.countLabel(todayUnitsCompleted)) · \(formatMinutes(todayFocusMinutes))")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.secondary.opacity(0.75))
            }

            TodayThemeRenderer(
                theme: todayTheme,
                focusMinutes: todayFocusMinutes,
                dailyGoalMet: dailyGoalMet,
                dailyGoalMetAt: dailyGoalMetAt,
                weeklyGoalMet: weeklyGoalMet,
                weeklyGoalMetAt: weeklyGoalMetAt
            )
            .frame(minHeight: todayThemeHeight, maxHeight: .infinity)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
        .onAppear { syncGoalState() }
        .onChange(of: todayFocusMinutes) { _, _ in syncGoalState() }
        .onChange(of: weekTotal) { _, _ in syncGoalState() }
    }

    private func syncGoalState() {
        let nowKey = SessionLog.isoDate(from: Date())
        if nowKey != trackedDayKey {
            trackedDayKey = nowKey
            dailyGoalMetAt = nil
        }
        if dailyGoalMet, dailyGoalMetAt == nil {
            dailyGoalMetAt = Date()
        } else if !dailyGoalMet, dailyGoalMetAt != nil {
            dailyGoalMetAt = nil
        }
        if weeklyGoalMet, weeklyGoalMetAt == nil {
            weeklyGoalMetAt = Date()
        } else if !weeklyGoalMet, weeklyGoalMetAt != nil {
            weeklyGoalMetAt = nil
        }
    }

    // MARK: - Shared

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(Color.secondary.opacity(0.65))
    }

    private func formatMinutes(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func shortDayLabel(_ iso: String) -> String {
        let f        = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: iso) else { return "" }
        let g        = DateFormatter()
        g.dateFormat = "EEE"
        return String(g.string(from: date).prefix(1))
    }

    private func fullDayLabel(_ iso: String) -> String {
        if iso == SessionLog.isoDate(from: Date()) { return "Today" }
        let f        = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: iso) else { return "" }
        let g        = DateFormatter()
        g.dateFormat = "EEE"
        return g.string(from: date)
    }
}
