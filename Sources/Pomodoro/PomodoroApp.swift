import SwiftUI
import EventKit
import AppKit
import PomodoroCore

@MainActor final class TimerModel: ObservableObject {
    @Published var state: TimerState
    @Published var now = Date()
    @Published var autoBreak: Bool { didSet { UserDefaults.standard.set(autoBreak, forKey: "autoBreak") } }
    @Published var autoSync: Bool {
        didSet {
            UserDefaults.standard.set(autoSync, forKey: "autoSync")
            recordActivity(autoSync ? "Automatic calendar sync enabled." : "Automatic calendar sync disabled.")
            if autoSync { syncPending() }
        }
    }
    @Published var activities: [ActivityEntry] = []
    @Published var syncState = CalendarSyncState()
    @Published var calendars: [EKCalendar] = []
    @Published var reminders: [EKReminder] = []
    @Published var reminderLists: [EKCalendar] = []
    @Published var selectedReminderListID: String {
        didSet { UserDefaults.standard.set(selectedReminderListID, forKey: "selectedReminderListID") }
    }
    var filteredReminders: [EKReminder] {
        reminders.filter { selectedReminderListID.isEmpty || $0.calendar.calendarIdentifier == selectedReminderListID }
    }
    @Published var message = ""
    @Published var reminderStatus = "Load tasks from Apple Reminders to choose a focus task."
    @Published var loadingReminders = false
    @Published var loadingCalendars = false
    private let store = EKEventStore()
    private var clock: Timer?
    private let stateKey = "pomodoroState"
    init() {
        if let data = UserDefaults.standard.data(forKey: stateKey), let saved = try? JSONDecoder().decode(TimerState.self, from: data) { state = saved }
        else { state = TimerState() }
        selectedReminderListID = UserDefaults.standard.string(forKey: "selectedReminderListID") ?? ""
        autoBreak = UserDefaults.standard.bool(forKey: "autoBreak")
        autoSync = (UserDefaults.standard.object(forKey: "autoSync") as? Bool) ?? true
        if let data = UserDefaults.standard.data(forKey: "activities"), let saved = try? JSONDecoder().decode([ActivityEntry].self, from: data) { activities = saved }
        if let data = UserDefaults.standard.data(forKey: "calendarSync"), let saved = try? JSONDecoder().decode(CalendarSyncState.self, from: data) { syncState = saved }
        recordActivity("App opened.")
        tick()
        if autoSync { syncPending() }
        clock = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    var timeText: String { let seconds = Int(ceil(state.seconds(at: now))); return String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    func deleteActivity(_ id: UUID) {
        activities.removeAll { $0.id == id }
        persistSyncAndActivity()
    }
    func clearActivities() {
        activities.removeAll()
        persistSyncAndActivity()
    }
    var calendarAccessDescription: String {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
            ? "Calendar access granted."
            : "Calendar access required. Connect Calendar to authorize sync."
    }
    func recordActivity(_ text: String) {
        activities.append(ActivityEntry(text))
        if activities.count > 500 { activities.removeFirst(activities.count - 500) }
        persistSyncAndActivity()
    }
    private func persistSyncAndActivity() {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(activities), forKey: "activities")
            UserDefaults.standard.set(try JSONEncoder().encode(syncState), forKey: "calendarSync")
        } catch { message = "Could not save activity or sync status: \(error.localizedDescription)" }
    }
    func save() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(state), forKey: stateKey) }
        catch { message = "Could not save timer state: \(error.localizedDescription)" }
    }
    private func finishChange(previousCount: Int) {
        let newRecords = Array(state.logs.dropFirst(previousCount))
        // Persist the queue before timer state, so a restart cannot lose a sync request.
        if autoSync { syncState.enqueue(newRecords); persistSyncAndActivity() }
        save()
        if autoSync && !newRecords.isEmpty { syncPending() }
    }
    func tick() {
        now = Date()
        if let deadline = state.deadline, now >= deadline {
            let count = state.logs.count
            let phase = state.phase.title
            state.finish(at: now, autoStartBreak: autoBreak)
            recordActivity("\(phase) completed. Next phase: \(state.phase.title).")
            finishChange(previousCount: count)
            NSSound.beep()
        }
    }
    func toggle() {
        tick()
        let count = state.logs.count
        if state.deadline == nil {
            state.start(at: Date())
            recordActivity("Started / resumed \(state.phase.title): \(state.taskTitle.isEmpty ? "Untitled" : state.taskTitle).")
        } else {
            state.pause(at: Date())
            recordActivity("Paused \(state.phase.title).")
        }
        now = Date(); finishChange(previousCount: count)
    }
    func end() {
        let count = state.logs.count
        state.endEarly(at: Date()); now = Date()
        recordActivity("Ended / reset session. Current phase: \(state.phase.title).")
        finishChange(previousCount: count)
    }
    func selectTask(_ title: String) {
        state.taskTitle = title; save(); recordActivity("Selected task: \(title).")
    }
    func selectCalendar(_ id: String) {
        state.calendarID = id.isEmpty ? nil : id; save()
        let name = calendars.first { $0.calendarIdentifier == id }?.title ?? "None"
        recordActivity("Selected calendar: \(name).")
        if autoSync { syncPending() }
    }
    func syncPending() {
        guard !syncState.pending.isEmpty else { return }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            Task { await connectCalendar() }
            return
        }
        for log in state.logs where syncState.pending.contains(log.id) { export(log, automatic: true) }
    }
    func connectCalendar() async {
        guard !loadingCalendars else { return }
        loadingCalendars = true
        defer { loadingCalendars = false }
        do {
            let granted = try await store.requestFullAccessToEvents()
            if granted { store.reset() }
            calendars = granted ? store.calendars(for: .event).filter { $0.allowsContentModifications } : []
            message = granted ? "Calendars refreshed." : "Calendar access was denied. Enable it in System Settings."
            recordActivity(message)
            if granted { syncPending() }
        } catch { message = "Could not connect to Calendar: \(error.localizedDescription)"; recordActivity(message) }
    }
    func loadReminders() async {
        guard !loadingReminders else { return }
        loadingReminders = true
        reminderStatus = "Loading reminders…"
        defer { loadingReminders = false; recordActivity(reminderStatus) }
        do {
            guard try await store.requestFullAccessToReminders() else {
                reminders = []
                reminderLists = []
                reminderStatus = "Reminders access was denied. Enable it in System Settings > Privacy & Security > Reminders."
                return
            }
            reminderLists = store.calendars(for: .reminder).sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            if !selectedReminderListID.isEmpty && !reminderLists.contains(where: { $0.calendarIdentifier == selectedReminderListID }) {
                selectedReminderListID = ""
            }
            let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
            let fetched: [EKReminder]? = await withCheckedContinuation { continuation in
                store.fetchReminders(matching: predicate) { continuation.resume(returning: $0) }
            }
            guard let fetched else {
                reminders = []
                reminderStatus = "Could not read reminders. Try loading tasks again."
                return
            }
            reminders = fetched.sorted { ($0.title ?? "").localizedStandardCompare($1.title ?? "") == .orderedAscending }
            reminderStatus = reminders.isEmpty
                ? "No incomplete reminders found. Add a task in Apple Reminders, then load tasks again."
                : "Loaded \(reminders.count) incomplete reminders. Select one below."
        } catch {
            reminders = []
            reminderStatus = "Could not load Reminders: \(error.localizedDescription)"
        }
    }
    func export(_ log: FocusLog, automatic: Bool = false) {
        if syncState.synced.contains(log.id) { return }
        syncState.enqueue([log])
        persistSyncAndActivity()
        func failed(_ reason: String) {
            message = reason
            recordActivity("Calendar sync pending for \(log.title.isEmpty ? "Focus" : log.title): \(reason)")
        }
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            failed("Connect to Calendar to sync this record."); return
        }
        let identifier = "Pomodoro log: \(log.id.uuidString)"
        let predicate = store.predicateForEvents(withStart: log.start.addingTimeInterval(-1), end: log.end.addingTimeInterval(1), calendars: nil)
        if store.events(matching: predicate).contains(where: { $0.notes == identifier }) {
            syncState.markSynced(log.id)
            recordActivity("Calendar record already exists: \(log.title).")
            message = "This record already exists in Calendar."
            return
        }
        guard let id = log.calendarID ?? state.calendarID, let calendar = store.calendar(withIdentifier: id), calendar.allowsContentModifications else {
            failed("Select a writable calendar."); return
        }
        let event = EKEvent(eventStore: store)
        event.title = log.title.isEmpty ? "Pomodoro Focus" : log.title
        event.startDate = log.start; event.endDate = log.end; event.calendar = calendar; event.notes = identifier
        do {
            try store.save(event, span: .thisEvent)
            syncState.markSynced(log.id)
            message = "Saved to Calendar."
            recordActivity("\(automatic ? "Automatically synced" : "Synced") \(event.title ?? "Focus") to \(calendar.title).")
        } catch { failed("Could not save to Calendar: \(error.localizedDescription)") }
    }

}

@main struct PomodoroApp: App {
    @StateObject private var model = TimerModel()
    var body: some Scene {
        WindowGroup("Pomodoro") { TimerView(model: model) }
        .defaultSize(width: 460, height: 820)
        MenuBarExtra { TimerView(model: model).frame(width: 440, height: 780) } label: {
            Label(model.state.deadline == nil ? "Pomodoro" : model.timeText, systemImage: "timer")
        }.menuBarExtraStyle(.window)
    }
}

struct TimerView: View {
    @State private var showActivity = false
    @State private var confirmClearActivities = false
    @ObservedObject var model: TimerModel
    var body: some View {
        VStack(spacing: 16) {
            Text("🍅 Pomodoro").font(.title.bold())
            Text("\(model.state.phase.title) · Completed sessions: \(model.state.completedFocus)").foregroundStyle(.secondary)
            Text(model.timeText).font(.system(size: 64, weight: .medium, design: .rounded)).monospacedDigit()
            TextField("What will you focus on?", text: $model.state.taskTitle)
                .textFieldStyle(.roundedBorder).disabled(model.state.deadline != nil)
                .onChange(of: model.state.taskTitle) { _, _ in model.save() }
            HStack {
                Button(model.state.deadline == nil ? "Start / Resume" : "Pause") { model.toggle() }.buttonStyle(.borderedProminent).tint(.red)
                Button("End / Reset Session") { model.end() }
            }
            Toggle("Automatically start breaks", isOn: $model.autoBreak)
            Divider()
            HStack {
                Text("Reminders").font(.headline)
                Spacer()
                Button(model.loadingReminders ? "Loading…" : "Load Tasks") {
                    Task { await model.loadReminders() }
                }.disabled(model.loadingReminders)
            }
            Text(model.reminderStatus).font(.caption).foregroundStyle(.secondary)
            if !model.reminderLists.isEmpty {
                Picker("Reminder List", selection: $model.selectedReminderListID) {
                    Text("All Lists").tag("")
                    ForEach(model.reminderLists, id: \.calendarIdentifier) { list in
                        Text("\(list.title) — \(list.source.title)").tag(list.calendarIdentifier)
                    }
                }.disabled(model.loadingReminders)
                if model.filteredReminders.isEmpty && !model.loadingReminders {
                    Text("No incomplete tasks in this list.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !model.filteredReminders.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(model.filteredReminders, id: \.calendarItemIdentifier) { reminder in
                            Button {
                                model.selectTask(reminder.title ?? "")
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(reminder.title ?? "Untitled").lineLimit(2)
                                    Text(reminder.calendar.title).font(.caption).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.bordered)
                        }
                    }
                }.frame(height: 110).disabled(model.state.deadline != nil)
                if model.state.deadline != nil {
                    Text("Pause the timer to choose a different task.").font(.caption)
                }
            }
            HStack {
                Text("Calendar").font(.headline)
                Spacer()
                Button("Connect Calendar") { Task { await model.connectCalendar() } }
                    .disabled(model.loadingCalendars)
            }
            Text(model.calendarAccessDescription).font(.caption).foregroundStyle(.secondary)
            if !model.calendars.isEmpty {
                Picker("Calendar", selection: Binding(get: { model.state.calendarID ?? "" }, set: { model.selectCalendar($0) })) {
                    Text("Select a calendar").tag("")
                    ForEach(model.calendars, id: \.calendarIdentifier) { Text($0.title).tag($0.calendarIdentifier) }
                }.disabled(model.state.deadline != nil)
            }
            Toggle("Automatically sync focus records", isOn: $model.autoSync)
            HStack {
                Button("Activity Log") { showActivity = true }
                Spacer()
                Button("Retry Pending (\(model.syncState.pending.count))") { model.syncPending() }
                    .disabled(model.syncState.pending.isEmpty)
            }
            Text("Pause, end, or complete a focus session to sync it to your selected calendar.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(model.state.logs.reversed()) { log in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(log.title.isEmpty ? "Focus" : log.title).lineLimit(1)
                                Text("\(log.start.formatted(date: .abbreviated, time: .shortened)) · \(Int(log.end.timeIntervalSince(log.start))) sec").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.syncState.synced.contains(log.id) {
                                Label("Synced", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green)
                            } else {
                                Button(model.syncState.pending.contains(log.id) ? "Retry Sync" : "Add to Calendar") { model.export(log) }
                            }
                        }
                    }
                }
            }
            if !model.message.isEmpty { Text(model.message).font(.caption).textSelection(.enabled) }
        }.padding(24)
        .sheet(isPresented: $showActivity) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Activity Log").font(.title2.bold())
                    Spacer()
                    Button("Clear All", role: .destructive) { confirmClearActivities = true }
                        .disabled(model.activities.isEmpty)
                    Button("Done") { showActivity = false }
                }
                Text("The latest 500 actions and sync results are stored on this Mac.").font(.caption).foregroundStyle(.secondary)
                if model.activities.isEmpty {
                    Text("No activity logs.").foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(model.activities.reversed()) { entry in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.date.formatted(date: .abbreviated, time: .standard)).font(.caption).foregroundStyle(.secondary)
                                Text(entry.message).textSelection(.enabled)
                            }
                            Spacer()
                            Button(role: .destructive) { model.deleteActivity(entry.id) } label: {
                                Image(systemName: "trash")
                            }.buttonStyle(.borderless).help("Delete this activity log")
                        }
                    }
                }
            }.padding(20).frame(minWidth: 500, minHeight: 420)
            .alert("Delete all activity logs?", isPresented: $confirmClearActivities) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All", role: .destructive) { model.clearActivities() }
            } message: {
                Text("This removes saved activity logs from this Mac. Focus records and calendar events are kept.")
            }
        }
    }
}
