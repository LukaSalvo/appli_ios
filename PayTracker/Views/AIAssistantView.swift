import SwiftUI
import SwiftData

/// Conversational assistant that lets the user **add, modify or delete** a
/// worked day in plain French — typed or dictated. Orders are parsed by
/// ``SessionCommandParser`` (Apple's on-device model when available, a heuristic
/// otherwise) and applied straight to the SwiftData store, with a one-tap undo.
struct AIAssistantView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<WorkSession> { $0.endDate != nil },
        sort: \WorkSession.startDate,
        order: .reverse
    )
    private var pastSessions: [WorkSession]

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65

    @State private var messages: [ChatMessage] = []
    @State private var undoActions: [UUID: () -> Void] = [:]
    @State private var inputText: String = ""
    @State private var isThinking = false
    @StateObject private var speech = SpeechRecognizer()
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "Ajoute hier de 9h à 17h",
        "Modifie lundi, je suis parti à 18h",
        "Supprime mes heures d'avant-hier",
        "J'ai bossé 8h-16h avec 30 min de pause mardi"
    ]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            welcomeCard
                        }
                        ForEach(messages) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                        if isThinking {
                            thinkingBubble.id("thinking")
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
                .onChange(of: isThinking) { _, _ in scrollToEnd(proxy) }
            }
            .navigationTitle("Assistant IA")
            .safeAreaInset(edge: .bottom) { inputBar }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isRecording { inputText = newValue }
        }
    }

    // MARK: - Welcome / empty state

    private var welcomeCard: some View {
        Card(hero: true) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Votre assistant heures", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.appAccent)

                Text("Demandez-moi d'ajouter, de corriger ou de supprimer les heures d'un jour — même un jour passé. Écrivez ou dictez, en langage naturel.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { example in
                        Button {
                            inputText = example
                            inputFocused = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .font(.caption)
                                    .foregroundStyle(Color.appAccent)
                                Text(example)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(privacyFooter)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var privacyFooter: String {
        if SessionCommandParser.isOnDeviceModelAvailable {
            return "Analysé par l'IA d'Apple, directement sur votre iPhone — rien n'est envoyé en ligne."
        }
        return "Compris localement sur votre appareil. L'analyse est affinée par l'IA d'Apple sur iPhone compatible (iOS 26)."
    }

    // MARK: - Message bubbles

    @ViewBuilder
    private func bubble(for message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color.appAccent, in: RoundedRectangle(cornerRadius: 18))
            }
        case .assistant:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(Color.appAccent)
                    .padding(.top, 12)
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let undo = undoActions[message.id] {
                        Button {
                            performUndo(message.id, undo)
                        } label: {
                            Label("Annuler", systemImage: "arrow.uturn.backward")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .tint(.appAccent)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                Spacer(minLength: 40)
            }
        }
    }

    private var thinkingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.footnote)
                .foregroundStyle(Color.appAccent)
                .padding(.top, 12)
            HStack(spacing: 8) {
                ProgressView()
                Text("Analyse…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 40)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            if let status = speech.statusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                if speech.isSupported {
                    Button {
                        toggleDictation()
                    } label: {
                        Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(speech.isRecording ? Color.white : Color.appAccent)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle().fill(speech.isRecording ? Color.moneyDanger : Color.appAccent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speech.isRecording ? "Arrêter la dictée" : "Dicter")
                }

                TextField(speech.isRecording ? "Parlez…" : "Écrivez votre demande…", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? Color.appAccent : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Envoyer")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    private func toggleDictation() {
        if speech.isRecording {
            speech.stop()
        } else {
            inputFocused = false
            inputText = ""
            speech.start()
        }
    }

    // MARK: - Send & apply

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        if speech.isRecording { speech.stop() }
        speech.reset()

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        isThinking = true

        Task {
            let command = await SessionCommandParser.parse(text)
            await MainActor.run {
                let result = apply(command)
                let assistant = ChatMessage(role: .assistant, text: result.message)
                messages.append(assistant)
                if let undo = result.undo { undoActions[assistant.id] = undo }
                isThinking = false
            }
        }
    }

    private func performUndo(_ id: UUID, _ undo: () -> Void) {
        undo()
        undoActions[id] = nil
        messages.append(ChatMessage(role: .assistant, text: "↩︎ C'est annulé."))
    }

    private func apply(_ command: SessionCommand) -> CommandResult {
        switch command.intent {
        case .add: return applyAdd(command)
        case .modify: return applyModify(command)
        case .delete: return applyDelete(command)
        case .unknown:
            return CommandResult(
                message: "Je n'ai pas bien saisi. Essayez par exemple « supprime mes heures de lundi » ou « modifie hier, je suis parti à 18h »."
            )
        }
    }

    private func applyAdd(_ c: SessionCommand) -> CommandResult {
        let start = combine(day: c.day, time: c.arrival ?? defaultTime(9, on: c.day))
        var end = combine(day: c.day, time: c.departure ?? defaultTime(17, on: c.day))
        if end <= start { end.addTimeInterval(24 * 3600) }
        let breakMin = c.breakMinutes ?? 0

        let session = WorkSession(
            startDate: start,
            endDate: end,
            breakDuration: Double(breakMin) * 60,
            hourlyRateSnapshot: hourlyRate,
            perHourBenefitsSnapshot: enabledPerHour,
            fixedBenefitsSnapshot: enabledFixed
        )
        let context = modelContext
        context.insert(session)

        let msg = "✅ Journée ajoutée — \(dayLabel(c.day)).\n\(timeLabel(start))–\(timeLabel(end)) · \(formatHours(session.duration() / 3600)) travaillées · \(Money.string(session.totalPay()))"
        return CommandResult(message: msg) {
            context.delete(session)
        }
    }

    private func applyModify(_ c: SessionCommand) -> CommandResult {
        let targets = sessions(on: c.day)
        guard let session = targets.first else {
            return CommandResult(
                message: "🔎 Aucune journée enregistrée le \(dayLabel(c.day)). Dites « ajoute \(dayLabelShort(c.day))… » pour la créer."
            )
        }
        guard c.hasAnyField else {
            return CommandResult(
                message: "❓ Que faut-il changer le \(dayLabel(c.day)) ? Précisez l'heure d'arrivée, l'heure de départ ou la pause."
            )
        }

        let prevStart = session.startDate
        let prevEnd = session.endDate
        let prevBreak = session.breakDuration
        let day = Calendar.current.startOfDay(for: session.startDate)

        var start = session.startDate
        var end = session.endDate ?? session.startDate
        if let arrival = c.arrival { start = combine(day: day, time: arrival) }
        if let departure = c.departure { end = combine(day: day, time: departure) }
        if end <= start { end = end.addingTimeInterval(24 * 3600) }

        session.startDate = start
        session.endDate = end
        if let br = c.breakMinutes { session.breakDuration = Double(br) * 60 }

        let msg = "✏️ Journée du \(dayLabel(day)) mise à jour.\n\(timeLabel(start))–\(timeLabel(end)) · \(formatHours(session.duration() / 3600)) travaillées · \(Money.string(session.totalPay()))"
        return CommandResult(message: msg) {
            session.startDate = prevStart
            session.endDate = prevEnd
            session.breakDuration = prevBreak
        }
    }

    private func applyDelete(_ c: SessionCommand) -> CommandResult {
        let targets = sessions(on: c.day)
        guard !targets.isEmpty else {
            return CommandResult(message: "🔎 Aucune journée enregistrée le \(dayLabel(c.day)).")
        }
        let snapshots = targets.map(SessionSnapshot.init)
        let context = modelContext
        for session in targets { context.delete(session) }

        let msg = targets.count == 1
            ? "🗑️ Journée du \(dayLabel(c.day)) supprimée."
            : "🗑️ \(targets.count) journées du \(dayLabel(c.day)) supprimées."
        return CommandResult(message: msg) {
            for snap in snapshots { context.insert(snap.makeSession()) }
        }
    }

    // MARK: - Data helpers

    private var enabledPerHour: Double {
        benefits.filter { $0.isEnabled && $0.type == .perHour }.reduce(0) { $0 + $1.amount }
    }
    private var enabledFixed: Double {
        benefits.filter { $0.isEnabled && $0.type == .perShift }.reduce(0) { $0 + $1.amount }
    }

    private func sessions(on day: Date) -> [WorkSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return pastSessions.filter { $0.startDate >= start && $0.startDate < end }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Date helpers

    private func combine(day: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: day)
        let t = cal.dateComponents([.hour, .minute], from: time)
        var c = DateComponents()
        c.year = d.year; c.month = d.month; c.day = d.day
        c.hour = t.hour; c.minute = t.minute
        return cal.date(from: c) ?? day
    }

    private func defaultTime(_ hour: Int, on day: Date) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    private func dayLabel(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func dayLabelShort(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide))
    }

    private func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Supporting types

/// A single line in the assistant conversation.
private struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

/// The result of applying a command: what to tell the user, and how to undo it.
private struct CommandResult {
    let message: String
    var undo: (() -> Void)?
}

/// A value copy of a session, used to re-insert it when the user taps "Annuler".
private struct SessionSnapshot {
    let startDate: Date
    let endDate: Date?
    let breakDuration: TimeInterval
    let hourlyRateSnapshot: Double
    let perHourBenefitsSnapshot: Double
    let fixedBenefitsSnapshot: Double
    let kind: SessionKind

    init(_ s: WorkSession) {
        startDate = s.startDate
        endDate = s.endDate
        breakDuration = s.breakDuration
        hourlyRateSnapshot = s.hourlyRateSnapshot
        perHourBenefitsSnapshot = s.perHourBenefitsSnapshot
        fixedBenefitsSnapshot = s.fixedBenefitsSnapshot
        kind = s.kind
    }

    func makeSession() -> WorkSession {
        WorkSession(
            startDate: startDate,
            endDate: endDate,
            breakDuration: breakDuration,
            hourlyRateSnapshot: hourlyRateSnapshot,
            perHourBenefitsSnapshot: perHourBenefitsSnapshot,
            fixedBenefitsSnapshot: fixedBenefitsSnapshot,
            kind: kind
        )
    }
}

#Preview {
    AIAssistantView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self, VariableExpense.self], inMemory: true)
}
