import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @AppStorage("payMode") private var payModeRaw: String = PayMode.hourly.rawValue
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @AppStorage("monthlySalary") private var monthlySalary: Double = 1800
    @AppStorage("daysWorkedPerMonth") private var daysWorkedPerMonth: Int = 20

    @AppStorage("mealTicketsEnabled") private var mealTicketsEnabled: Bool = true
    @AppStorage("mealTicketValue") private var mealTicketValue: Double = 9.0
    @AppStorage("mealTicketEmployerPct") private var mealTicketEmployerPct: Double = 60

    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    @AppStorage("currentBalance") private var currentBalance: Double = 0

    @AppStorage("forgottenSessionHours") private var forgottenSessionHours: Double = 12

    @AppStorage("overtimeEnabled") private var overtimeEnabled: Bool = false
    @AppStorage("weeklyContractHours") private var weeklyContractHours: Double = 35
    @AppStorage("workingDaysPerWeek") private var workingDaysPerWeek: Int = 5
    @AppStorage("flexibleCompany") private var flexibleCompany: Bool = false

    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled: Bool = true

    @AppStorage(AppLock.enabledKey) private var appLockEnabled: Bool = false
    @AppStorage("hideAmountsOnLockScreen") private var hideAmountsOnLockScreen: Bool = false
    @EnvironmentObject private var appLock: AppLock

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]
    @Query(sort: \WorkSession.startDate) private var allSessions: [WorkSession]
    @Query(sort: \Expense.createdAt) private var allExpenses: [Expense]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBenefit = false

    @State private var exportDocument: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: AppBackup.Checked?
    @State private var showingImportConfirm = false
    @State private var fileError: String?

    private var payMode: PayMode { PayMode(rawValue: payModeRaw) ?? .hourly }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "PaieHoraire-\(formatter.string(from: .now))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section("Apparence") {
                    Picker("Thème", selection: $appearanceModeRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Label(mode.label, systemImage: mode.systemImage).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Pay mode
                Section("Mode de paie") {
                    Picker("Mode de paie", selection: $payModeRaw) {
                        ForEach(PayMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if payMode == .hourly {
                        amountRow(label: "Taux horaire net", value: $hourlyRate,
                                  limit: 0...Sanitize.maxRate)
                        Stepper(value: $forgottenSessionHours, in: 0...24, step: 1) {
                            HStack {
                                Text("Rappel de session oubliée")
                                Spacer()
                                Text(forgottenSessionHours == 0
                                     ? "Désactivé"
                                     : "après \(Int(forgottenSessionHours)) h")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        amountRow(label: "Salaire mensuel net", value: $monthlySalary)
                        Stepper(value: $daysWorkedPerMonth, in: 0...31) {
                            HStack {
                                Text("Jours travaillés / mois")
                                Spacer()
                                Text("\(daysWorkedPerMonth)").foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Benefits (hourly)
                Section {
                    if benefits.isEmpty {
                        Text("Aucun avantage pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(benefits) { BenefitRowView(benefit: $0) }
                            .onDelete(perform: deleteBenefits)
                    }
                    Button {
                        showingAddBenefit = true
                    } label: {
                        Label("Ajouter un avantage", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Avantages")
                } footer: {
                    Text("« Par heure » s'ajoute à votre taux horaire. « Par prise de poste » (prime panier…) est ajouté une fois au démarrage d'une session.")
                }

                // Meal tickets
                Section {
                    Toggle("Tickets restaurant", isOn: $mealTicketsEnabled)
                    if mealTicketsEnabled {
                        amountRow(label: "Valeur d'un ticket", value: $mealTicketValue, limit: 0...1_000)
                        VStack(alignment: .leading) {
                            HStack {
                                Text("Part employeur")
                                Spacer()
                                Text("\(Int(mealTicketEmployerPct)) %").foregroundStyle(.secondary)
                            }
                            Slider(value: $mealTicketEmployerPct, in: 0...100, step: 5)
                                .tint(.appAccent)
                        }
                    }
                } header: {
                    Text("Tickets restaurant")
                } footer: {
                    Text("La part payée par l'employeur est comptée comme un avantage dans votre budget.")
                }

                // Overtime
                Section {
                    Toggle("Suivre les heures supp", isOn: $overtimeEnabled)
                    if overtimeEnabled {
                        Stepper(value: $weeklyContractHours, in: 0...60, step: 0.5) {
                            HStack {
                                Text("Heures / semaine (contrat)")
                                Spacer()
                                Text(formatHours(weeklyContractHours)).foregroundStyle(.secondary)
                            }
                        }
                        Stepper(value: $workingDaysPerWeek, in: 1...7) {
                            HStack {
                                Text("Jours travaillés / semaine")
                                Spacer()
                                Text("\(workingDaysPerWeek)").foregroundStyle(.secondary)
                            }
                        }
                        Toggle("Entreprise flexible", isOn: $flexibleCompany)
                    }
                } header: {
                    Text("Heures supplémentaires")
                } footer: {
                    Text("« Entreprise flexible » : seules les heures au-delà du contrat hebdomadaire comptent, quelle que soit la répartition (ex. 7 h 15 du lundi au jeudi + 6 h le vendredi = 35 h, sans heures supp). Sinon, chaque jour au-delà de sa part (contrat ÷ jours) compte.")
                }

                // Notifications
                Section {
                    Toggle("Bilan quotidien à 18 h", isOn: $dailySummaryEnabled)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Chaque jour à 18 h, une notification récapitule vos heures et votre paie du jour, ainsi que le temps qu'il reste pour atteindre vos \(formatHours(weeklyContractHours)) de la semaine.")
                }

                // Privacy & lock
                Section {
                    if AppLock.isAvailable {
                        Toggle("Verrouiller l'app (\(AppLock.methodLabel))", isOn: $appLockEnabled)
                            .onChange(of: appLockEnabled) { _, enabled in
                                guard enabled else {
                                    appLock.disable()
                                    return
                                }
                                // Prove device ownership before arming the lock,
                                // so it can't be switched on for someone else.
                                Task {
                                    let confirmed = await appLock.confirmOwnership()
                                    if !confirmed { appLockEnabled = false }
                                }
                            }
                    } else {
                        Label("Ajoutez un code sur votre iPhone pour activer le verrouillage.",
                              systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Toggle("Masquer les montants sur l'écran verrouillé", isOn: $hideAmountsOnLockScreen)
                } header: {
                    Text("Confidentialité")
                } footer: {
                    Text("Le verrouillage demande \(AppLock.methodLabel) à chaque ouverture et masque l'app dans le sélecteur d'applications. Le masquage des montants retire les sommes en euros du bilan quotidien et de l'activité en direct — l'écran verrouillé n'affiche plus que vos heures.")
                }

                // Expenses
                Section("Budget") {
                    NavigationLink {
                        ExpensesView()
                    } label: {
                        Label("Dépenses fixes mensuelles", systemImage: "arrow.up.circle.fill")
                    }
                }

                // Backup / restore
                Section {
                    Button {
                        exportDocument = BackupDocument(backup: buildBackup())
                        showingExporter = true
                    } label: {
                        Label("Exporter mes données", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showingImporter = true
                    } label: {
                        Label("Importer des données", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Sauvegarde")
                } footer: {
                    Text("Exportez un fichier avec toutes vos données (sessions, avantages, dépenses, réglages). ⚠️ Ce fichier n'est pas chiffré : il contient votre salaire, votre solde et vos dépenses en clair. Rangez-le dans un espace de confiance. L'import remplace entièrement les données actuelles par celles du fichier.")
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingAddBenefit) {
                AddBenefitView()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: exportFilename
            ) { result in
                if case .failure(let error) = result {
                    fileError = error.localizedDescription
                } else {
                    Haptics.notify(.success)
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    importFile(at: url)
                case .failure(let error):
                    fileError = error.localizedDescription
                }
            }
            .confirmationDialog(
                "Remplacer toutes les données actuelles ?",
                isPresented: $showingImportConfirm,
                titleVisibility: .visible
            ) {
                Button("Remplacer", role: .destructive) { applyImport() }
                Button("Annuler", role: .cancel) { pendingImport = nil }
            } message: {
                Text(importConfirmationMessage)
            }
            .alert(
                "Erreur",
                isPresented: Binding(get: { fileError != nil }, set: { if !$0 { fileError = nil } })
            ) {
                Button("OK", role: .cancel) { fileError = nil }
            } message: {
                Text(fileError ?? "")
            }
        }
    }

    // MARK: - Backup / restore

    private func buildBackup() -> AppBackup {
        AppBackup(
            settings: AppBackup.Settings(
                payMode: payModeRaw,
                hourlyRate: hourlyRate,
                monthlySalary: monthlySalary,
                daysWorkedPerMonth: daysWorkedPerMonth,
                currentBalance: currentBalance,
                mealTicketsEnabled: mealTicketsEnabled,
                mealTicketValue: mealTicketValue,
                mealTicketEmployerPct: mealTicketEmployerPct,
                appearanceMode: appearanceModeRaw
            ),
            sessions: allSessions.map {
                AppBackup.Session(
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    breakDuration: $0.breakDuration,
                    hourlyRateSnapshot: $0.hourlyRateSnapshot,
                    perHourBenefitsSnapshot: $0.perHourBenefitsSnapshot,
                    fixedBenefitsSnapshot: $0.fixedBenefitsSnapshot
                )
            },
            benefits: benefits.map {
                AppBackup.Benefit(name: $0.name, amount: $0.amount, type: $0.typeRawValue,
                                  isEnabled: $0.isEnabled, createdAt: $0.createdAt)
            },
            expenses: allExpenses.map {
                AppBackup.Expense(name: $0.name, amount: $0.amount, category: $0.categoryRawValue,
                                   createdAt: $0.createdAt)
            }
        )
    }

    /// What the confirmation dialog says before wiping the current data —
    /// including anything the validator had to repair, so a partially broken
    /// file is never mistaken for a clean one.
    private var importConfirmationMessage: String {
        let base = "Sessions, avantages, dépenses et réglages seront remplacés par le contenu du fichier importé. Cette action est irréversible."
        guard let checked = pendingImport else { return base }
        var message = "Contenu du fichier : \(checked.summary).\n\n\(base)"
        if checked.hasCorrections {
            message += "\n\nCertaines valeurs du fichier étaient hors limites ou incohérentes : elles ont été corrigées ou ignorées."
        }
        return message
    }

    /// Loads and **validates** the file before anything is shown or written.
    /// The picker only proves the user chose the file, not that the app wrote
    /// it — see `AppBackup.checked()` for what is enforced.
    private func importFile(at url: URL) {
        do {
            pendingImport = try AppBackup.load(from: url)
            showingImportConfirm = true
        } catch {
            fileError = error.localizedDescription
        }
    }

    private func applyImport() {
        guard let backup = pendingImport?.backup else { return }

        for session in allSessions { modelContext.delete(session) }
        for benefit in benefits { modelContext.delete(benefit) }
        for expense in allExpenses { modelContext.delete(expense) }

        for s in backup.sessions {
            modelContext.insert(WorkSession(
                startDate: s.startDate,
                endDate: s.endDate,
                breakDuration: s.breakDuration,
                hourlyRateSnapshot: s.hourlyRateSnapshot,
                perHourBenefitsSnapshot: s.perHourBenefitsSnapshot,
                fixedBenefitsSnapshot: s.fixedBenefitsSnapshot
            ))
        }
        for b in backup.benefits {
            let benefit = Benefit(name: b.name, amount: b.amount,
                                   type: BenefitType(rawValue: b.type) ?? .perShift, isEnabled: b.isEnabled)
            benefit.createdAt = b.createdAt
            modelContext.insert(benefit)
        }
        for e in backup.expenses {
            let expense = Expense(name: e.name, amount: e.amount,
                                   category: ExpenseCategory(rawValue: e.category) ?? .other)
            expense.createdAt = e.createdAt
            modelContext.insert(expense)
        }

        payModeRaw = backup.settings.payMode
        hourlyRate = backup.settings.hourlyRate
        monthlySalary = backup.settings.monthlySalary
        daysWorkedPerMonth = backup.settings.daysWorkedPerMonth
        currentBalance = backup.settings.currentBalance
        mealTicketsEnabled = backup.settings.mealTicketsEnabled
        mealTicketValue = backup.settings.mealTicketValue
        mealTicketEmployerPct = backup.settings.mealTicketEmployerPct
        if let mode = backup.settings.appearanceMode { appearanceModeRaw = mode }

        // The old rows are gone: surface a write failure instead of leaving the
        // user with a half-applied import they think succeeded.
        do {
            try modelContext.save()
            Haptics.notify(.success)
        } catch {
            fileError = "L'import n'a pas pu être enregistré : \(error.localizedDescription)"
            Haptics.notify(.error)
        }
        pendingImport = nil
    }

    /// A money field whose value is clamped on every edit. Typing an absurd
    /// figure (or pasting one) otherwise propagates straight into the totals,
    /// the projected balance and the next export.
    private func amountRow(label: String, value: Binding<Double>,
                           limit: ClosedRange<Double> = 0...Sanitize.maxAmount) -> some View {
        let clamped = Binding<Double>(
            get: { value.wrappedValue },
            set: { value.wrappedValue = Sanitize.number($0, in: limit) }
        )
        return HStack {
            Text(label)
            Spacer()
            TextField("Montant", value: clamped, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
            Text("€").foregroundStyle(.secondary)
        }
    }

    private func deleteBenefits(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(benefits[index]) }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
        .environmentObject(AppLock())
}
