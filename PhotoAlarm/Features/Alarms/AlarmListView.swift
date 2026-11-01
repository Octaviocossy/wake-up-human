import SwiftData
import SwiftUI

/// The app's normal content: the Alarms, the Target object and (in Debug builds) the debug menu.
struct AlarmListView: View {
    private enum Editing: Identifiable {
        case new
        case existing(WakeAlarm)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let alarm): alarm.id.uuidString
            }
        }

        var alarm: WakeAlarm? {
            switch self {
            case .new: nil
            case .existing(let alarm): alarm
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\WakeAlarm.hour), SortDescriptor(\WakeAlarm.minute)]) private var alarms: [WakeAlarm]
    @Query private var objects: [TargetObject]
    @State private var model: AlarmListModel
    @State private var editing: Editing?
    /// When this build's provisioning profile expires, and when that was last read. nil expiry: no banner.
    @State private var buildExpiry: Date?
    @State private var buildExpiryCheckedAt: Date = .now

    init(context: ModelContext) {
        _model = State(initialValue: AlarmListModel(context: context))
    }

    var body: some View {
        List {
            ExpiryBanner(expiry: buildExpiry, now: buildExpiryCheckedAt)
            noticeSection
            alarmsSection
            targetObjectSection
            #if DEBUG
                Section { NavigationLink("Debug") { DebugMenuView() } }
            #endif
        }
        .navigationTitle("Alarms")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add alarm", systemImage: "plus") { editing = .new }
            }
        }
        .sheet(item: $editing) { editing in
            AlarmEditorView(model: model, alarm: editing.alarm)
        }
        .onAppear(perform: refreshBuildExpiry)
        // The list stays on screen while the app is backgrounded, so days pass without it reappearing.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshBuildExpiry() }
        }
    }

    private func refreshBuildExpiry() {
        buildExpiry = ProvisioningProfile.embeddedExpirationDate()
        buildExpiryCheckedAt = .now
    }

    // MARK: Sections

    /// Why the last enable was refused, with a way out; or the last error.
    @ViewBuilder
    private var noticeSection: some View {
        if let block = model.enableBlock {
            Section {
                switch block {
                case .targetObjectNotRegistered:
                    Text("Register your target object first").foregroundStyle(.red)
                    NavigationLink("Set up target object") { objectSetup }
                case .notAuthorized:
                    Text("Allow alarms for Photo Alarm in Settings").foregroundStyle(.red)
                    if let settings = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: settings)
                    }
                }
            }
        }
        if let message = model.errorMessage {
            Section { Text(message).foregroundStyle(.red) }
        }
    }

    private var alarmsSection: some View {
        Section {
            if alarms.isEmpty {
                Text("No alarms yet").foregroundStyle(.secondary)
            }
            ForEach(alarms) { alarm in
                row(for: alarm)
            }
            .onDelete { offsets in
                let doomed = offsets.map { alarms[$0] }
                Task { await model.delete(doomed) }
            }
        }
    }

    private var targetObjectSection: some View {
        Section("Target object") {
            if let object = objects.first {
                Text("Registered · \(object.references.count) references")
            } else {
                Text("Not registered")
            }
            NavigationLink("Set up target object") { objectSetup }
        }
    }

    private var objectSetup: some View {
        ObjectSetupView(
            matcher: AppEnvironment.matcher, repository: TargetObjectRepository(context: modelContext))
    }

    // MARK: Rows

    private func row(for alarm: WakeAlarm) -> some View {
        HStack {
            Button {
                editing = .existing(alarm)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Self.timeText(hour: alarm.hour, minute: alarm.minute))
                        .font(.title2.monospacedDigit())
                    Text(Self.weekdaysText(alarm.weekdayNumbers))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if model.failedAlarmIDs.contains(alarm.id) {
                        Text("Could not schedule this alarm")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("Enabled", isOn: enabledBinding(for: alarm))
                .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.6)
    }

    /// Flipping the switch asks the model; the Alarm only changes if the model allows it, so a refused enable
    /// snaps back to off.
    private func enabledBinding(for alarm: WakeAlarm) -> Binding<Bool> {
        Binding(
            get: { alarm.isEnabled },
            set: { enabled in Task { await model.setEnabled(alarm, to: enabled) } })
    }

    // MARK: Formatting

    private static func timeText(hour: Int, minute: Int) -> String {
        let time = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
        return time.formatted(date: .omitted, time: .shortened)
    }

    private static func weekdaysText(_ numbers: [Int]) -> String {
        let calendar = Calendar.current
        let chosen = AlarmRules.weekOrder(firstWeekday: calendar.firstWeekday).filter(numbers.contains)
        if chosen.count == 7 { return "Every day" }
        return chosen.map { calendar.shortWeekdaySymbols[$0 - 1] }.joined(separator: " ")
    }
}
