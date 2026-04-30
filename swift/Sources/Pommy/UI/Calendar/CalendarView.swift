import SwiftUI

/// Right-panel bottom section — monthly calendar grid.
///
/// Each day shows colored category dots.
/// Tap a day to see that day's sessions with task, duration, and notes.
@MainActor
struct CalendarView: View {
    @Environment(AppState.self) private var appState

    /// Owned by `PommyApp` so the right panel can rebalance Notes ↔ Calendar
    /// when a day's detail is showing.
    @Binding var selectedDay: Date?

    @State private var displayMonth:    Date    = Date()
    @State private var expandedEntryID: UUID?   = nil
    @State private var dragOffset:      CGFloat = 0
    @State private var monthSlide:      CGFloat = 0
    @State private var monthOpacity:    Double  = 1.0
    @State private var hoveredDay:      Date?   = nil
    @State private var hoverPreviewWorkItem: DispatchWorkItem? = nil
    private let hoverPreviewDelay: TimeInterval = 0.60

    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    private let gridColumns    = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            header
            PommyDivider(axis: .horizontal, inset: 12)
            weekdayRow
                .padding(.top, 6)
                .padding(.bottom, 2)
            monthGrid
            if let day = selectedDay {
                PommyDivider(axis: .horizontal, inset: 12)
                    .padding(.top, 4)
                dayDetail(day)
                    .frame(maxHeight: .infinity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedDay)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Calendar")
                .font(.pommyLabel)
                .foregroundStyle(Color.secondary.opacity(0.7))
                .textCase(.uppercase)
                .tracking(0.5)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pommyPress(hoverScale: 1.0, pressScale: 0.92)
            Text(monthYearLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: 72, alignment: .center)
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pommyPress(hoverScale: 1.0, pressScale: 0.92)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Weekday row

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(calendarDays, id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .offset(x: dragOffset + monthSlide)
        .opacity(monthOpacity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { v in
                    let dx = v.translation.width
                    let dy = v.translation.height
                    guard abs(dx) > abs(dy) * 1.5 else { return }
                    dragOffset = dx * 0.25
                }
                .onEnded { v in
                    let dx = v.translation.width
                    let dy = v.translation.height
                    withAnimation(.easeOut(duration: 0.15)) { dragOffset = 0 }
                    guard abs(dx) > abs(dy) * 1.5 else { return }
                    if dx < -50 { shiftMonth(1) }
                    else if dx > 50 { shiftMonth(-1) }
                }
        )
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(_ day: Date?) -> some View {
        if let day {
            let isToday    = Calendar.current.isDateInToday(day)
            let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? false
            let dots       = categoryDots(for: day)
            let todayTint  = appState.config.color(for: appState.config.defaultCategory)

            Button {
                hoverPreviewWorkItem?.cancel()
                hoverPreviewWorkItem = nil
                hoveredDay = nil
                withAnimation(Motion.springSnap) {
                    selectedDay     = isSelected ? nil : day
                    expandedEntryID = nil
                }
            } label: {
                VStack(spacing: 2) {
                    Text(dayNumber(day))
                        .font(.system(size: 10, weight: isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? Color.primary : Color.secondary.opacity(0.8))
                    HStack(spacing: 2) {
                        ForEach(dots.indices, id: \.self) { i in
                            // Tiny pill — more readable than dots
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(dots[i].verticalGradient)
                                .frame(width: 6, height: 3)
                        }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 30)
                .padding(.vertical, 3)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .fill(isSelected ? Surface.topHighlight : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.xs, style: .continuous)
                        .strokeBorder(
                            isToday ? todayTint.opacity(0.6) : Color.clear,
                            lineWidth: 1
                        )
                )
                .campGlow(active: isToday, tint: todayTint, outerRadius: 8, innerRadius: 3, outerOpacity: 0.18, innerOpacity: 0.12)
            }
            .buttonStyle(.plain)
            .pommyPress(hoverScale: 1.0, pressScale: 0.985)
            .onHover { isHovering in
                hoverPreviewWorkItem?.cancel()
                hoverPreviewWorkItem = nil

                guard isHovering else {
                    hoveredDay = hoveredDay == day ? nil : hoveredDay
                    return
                }

                let workItem = DispatchWorkItem {
                    hoveredDay = day
                }
                hoverPreviewWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + hoverPreviewDelay, execute: workItem)
            }
            .popover(isPresented: Binding(
                get: { hoveredDay == day && !dots.isEmpty },
                set: { if !$0 { hoveredDay = nil } }
            ), arrowEdge: .top) {
                dayHoverPreview(day)
            }
        } else {
            Color.clear.frame(height: 24)
        }
    }

    @ViewBuilder
    private func dayHoverPreview(_ day: Date) -> some View {
        let entries = sessionEntries(for: day)
        let focus   = entries.filter(\.isFocus)
        let total   = focus.reduce(0) { $0 + $1.duration_mins }

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(detailDateLabel(day))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if total > 0 {
                    Text(formatMins(total))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(focus.prefix(4)) { entry in
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.config.color(for: entry.category))
                        .frame(width: 5, height: 5)
                    Text(entry.task.isEmpty ? entry.category : entry.task)
                        .font(.system(size: 11))
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.duration_mins)m")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if focus.count > 4 {
                Text("+ \(focus.count - 4) more")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(width: 220)
    }

    // MARK: - Day detail

    @ViewBuilder
    private func dayDetail(_ day: Date) -> some View {
        let sessions = sessionEntries(for: day)
        let focus    = sessions.filter(\.isFocus)
        let totalMins = focus.reduce(0) { $0 + $1.duration_mins }

        VStack(alignment: .leading, spacing: 0) {
            // Date + total header (with close affordance)
            HStack(spacing: 8) {
                Text(detailDateLabel(day))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if totalMins > 0 {
                    Text(formatMins(totalMins))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Button {
                    withAnimation(Motion.springSnap) {
                        selectedDay = nil
                        expandedEntryID = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pommyPress(hoverScale: 1.0, pressScale: 0.9)
                .help("Close")
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if sessions.isEmpty {
                HStack {
                    Spacer()
                    Text("Nothing happened here. Spooky.")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundStyle(Color.secondary.opacity(0.55))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sessions) { entry in
                            sessionRow(entry)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func sessionRow(_ entry: SessionEntry) -> some View {
        let isExpanded = expandedEntryID == entry.id
        let isBreak    = entry.isBreak
        let dotColor   = isBreak ? Color(white: 0.45) : appState.config.color(for: entry.category)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedEntryID = isExpanded ? nil : entry.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 5, height: 5)
                    Text(entry.task.isEmpty ? entry.category : entry.task)
                        .font(.system(size: 11))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(entry.duration_mins)m")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.quaternary)
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 3) {
                        if !isBreak {
                            detailChip("\(entry.category)")
                        }
                        detailChip(isBreak ? "break" : "focus")
                        if entry.overflow_mins > 0 {
                            detailChip("+\(entry.overflow_mins)m overflow")
                        }
                        if !entry.notes.isEmpty {
                            Text(entry.notes)
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        } else {
                            Text("No notes left")
                                .font(.system(size: 10))
                                .foregroundStyle(.quaternary)
                                .italic()
                        }
                    }
                    .padding(.leading, 13)
                    .padding(.top, 1)
                }
            }
            .padding(.vertical, isExpanded ? 8 : 3)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(isExpanded ? Surface.fillSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(
                        isExpanded ? Surface.fillSoft : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(Motion.springSoft, value: isExpanded)
    }

    private func detailChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Surface.topHighlight, in: Capsule())
    }

    // MARK: - Data helpers

    private func categoryDots(for day: Date) -> [Color] {
        let iso  = SessionLog.isoDate(from: day)
        let focused = appState.sessionLog.entries.filter {
            $0.date == iso && $0.isFocus
        }
        if focused.isEmpty { return [] }
        var totals: [String: Int] = [:]
        for e in focused { totals[e.category, default: 0] += e.duration_mins }
        return totals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { appState.config.color(for: $0.key) }
    }

    private var calendarDays: [Date?] {
        let cal   = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayMonth)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first)
        else { return [] }

        let leadingBlanks = cal.component(.weekday, from: first) - 1
        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)

        for d in range {
            days.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func sessionEntries(for day: Date) -> [SessionEntry] {
        let iso = SessionLog.isoDate(from: day)
        return appState.sessionLog.entries
            .filter { $0.date == iso }
            .sorted { e1, e2 in
                if e1.session_type != e2.session_type {
                    return e1.isFocus
                }
                return e1.duration_mins > e2.duration_mins
            }
    }

    // MARK: - Navigation

    private func shiftMonth(_ offset: Int) {
        let direction: CGFloat = offset > 0 ? -40 : 40
        withAnimation(.easeOut(duration: 0.18)) {
            monthSlide   = direction
            monthOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            if let next = Calendar.current.date(byAdding: .month, value: offset, to: displayMonth) {
                displayMonth = next
                selectedDay  = nil
            }
            monthSlide = -direction
            withAnimation(Motion.springSoft) {
                monthSlide   = 0
                monthOpacity = 1.0
            }
        }
    }

    // MARK: - Formatting

    private var monthYearLabel: String {
        let f        = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: displayMonth)
    }

    private func dayNumber(_ date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private func detailDateLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        let f        = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: day)
    }

    private func formatMins(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        return h > 0 ? "\(h)h \(m > 0 ? "\(m)m" : "")" : "\(m)m"
    }
}
