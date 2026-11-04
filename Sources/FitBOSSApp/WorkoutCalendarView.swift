import FitBOSSCore
import SwiftUI

struct WorkoutCalendarView: View {
    @ObservedObject var store: WorkoutHistoryStore
    @State private var visibleMonth = Date()
    @State private var selectedDay = Date()
    @State private var pendingDeletion: UUID?
    @State private var showDeleteConfirmation = false

    private let weekdayLabels = ["月", "火", "水", "木", "金", "土", "日"]
    private let columns = Array(repeating: GridItem(.flexible(minimum: 32), spacing: 5), count: 7)

    private var calendar: Calendar { WorkoutDay.calendar }
    private var firstDay: Date {
        let p = calendar.dateComponents([.year, .month], from: visibleMonth)
        return calendar.date(from: p)!
    }
    private var monthLength: Int {
        calendar.range(of: .day, in: .month, for: firstDay)?.count ?? 30
    }
    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
    }
    private var selectedKey: String { WorkoutDay.key(for: selectedDay) }
    private var selectedSessions: [SavedWorkout] { store.history.sessions(on: selectedKey) }
    private var selectedIsRest: Bool { store.history.restDateKeys.contains(selectedKey) }
    private var selectedIsFuture: Bool {
        calendar.startOfDay(for: selectedDay) > calendar.startOfDay(for: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("運動履歴カレンダー").font(.largeTitle.bold())
                    Text("運動した日と休息日を記録します。すべてこのMacに保存されます。")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Label("運動した日", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(BOSSTheme.mint)
                    Label("休息日", systemImage: "moon.stars.fill")
                        .foregroundStyle(BOSSTheme.warning)
                    Spacer()
                }
                .font(.caption)

                VStack(spacing: 16) {
                    HStack {
                        Button { shiftMonth(by: -1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel("前の月")
                        Spacer()
                        Text(WorkoutDay.monthTitle(for: firstDay))
                            .font(.title2.bold())
                        Spacer()
                        Button { shiftMonth(by: 1) } label: { Image(systemName: "chevron.right") }
                            .disabled(firstDay >= calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!)
                            .accessibilityLabel("次の月")
                    }
                    .buttonStyle(.borderless)

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(weekdayLabels, id: \.self) { label in
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                        ForEach(0..<(leadingBlanks + monthLength), id: \.self) { index in
                            if index < leadingBlanks {
                                Color.clear.frame(height: 54)
                            } else {
                                dayCell(index - leadingBlanks + 1)
                            }
                        }
                    }
                }
                .padding(22)
                .background(BOSSTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text(WorkoutDay.dateTitle(for: selectedDay))
                        .font(.title3.bold())
                    if selectedSessions.isEmpty {
                        Text(selectedIsRest ? "休息日として記録しています。" : "この日の運動記録はありません。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedSessions) { workout in
                            HStack {
                                Label("腕立て伏せ \(workout.repetitions) 回（試験計測）", systemImage: "figure.strengthtraining.traditional")
                                Spacer()
                                Text(WorkoutDay.timeTitle(for: workout.completedAt))
                                    .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    pendingDeletion = workout.id
                                    showDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("この運動記録を削除")
                            }
                        }
                    }
                    Button {
                        _ = store.setRest(on: selectedKey, enabled: !selectedIsRest)
                    } label: {
                        Label(selectedIsRest ? "休息日の記録を取り消す" : "この日を休息日として記録",
                              systemImage: selectedIsRest ? "minus.circle" : "moon.stars")
                    }
                    .disabled(selectedIsFuture || !selectedSessions.isEmpty || store.storageError != nil)
                    Text("休息日は継続記録を最大2日連続までつなげます。休息日だけでは運動日数は増えません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(BOSSTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                if let error = store.storageError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(BOSSTheme.error)
                }
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(BOSSTheme.canvas)
        .foregroundStyle(BOSSTheme.primary)
        .navigationTitle("履歴カレンダー")
        .confirmationDialog("この運動記録を削除しますか？", isPresented: $showDeleteConfirmation) {
            Button("削除する", role: .destructive) {
                if let id = pendingDeletion { _ = store.removeSession(id) }
                pendingDeletion = nil
            }
            Button("キャンセル", role: .cancel) { pendingDeletion = nil }
        }
    }

    private func dayCell(_ dayNumber: Int) -> some View {
        let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: firstDay)!
        let key = WorkoutDay.key(for: date)
        let hasWorkout = store.history.completedDays.contains(key)
        let isRest = store.history.restDateKeys.contains(key)
        let isSelected = key == selectedKey
        let isFuture = date > calendar.startOfDay(for: Date())

        return Button {
            selectedDay = date
        } label: {
            VStack(spacing: 5) {
                Text("\(dayNumber)")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .bold : .regular))
                if hasWorkout {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(BOSSTheme.mint)
                } else if isRest {
                    Image(systemName: "moon.stars.fill").foregroundStyle(BOSSTheme.warning)
                } else {
                    Image(systemName: "circle.fill").opacity(0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(isFuture ? Color.secondary : Color.primary)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dayNumber)日\(hasWorkout ? "、運動記録あり" : isRest ? "、休息日" : "")")
    }

    private func shiftMonth(by count: Int) {
        guard let date = calendar.date(byAdding: .month, value: count, to: firstDay) else { return }
        visibleMonth = date
        selectedDay = date
    }
}
