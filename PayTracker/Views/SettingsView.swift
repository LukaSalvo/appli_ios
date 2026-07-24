import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("payMode") private var payModeRaw: String = PayMode.hourly.rawValue
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @AppStorage("monthlySalary") private var monthlySalary: Double = 1800
    @AppStorage("daysWorkedPerMonth") private var daysWorkedPerMonth: Int = 20

    @AppStorage("mealTicketsEnabled") private var mealTicketsEnabled: Bool = true
    @AppStorage("mealTicketValue") private var mealTicketValue: Double = 9.0
    @AppStorage("mealTicketEmployerPct") private var mealTicketEmployerPct: Double = 60

    @AppStorage("forgottenSessionHours") private var forgottenSessionHours: Double = 12

    @AppStorage("overtimeEnabled") private var overtimeEnabled: Bool = false
    @AppStorage("weeklyContractHours") private var weeklyContractHours: Double = 35
    @AppStorage("workingDaysPerWeek") private var workingDaysPerWeek: Int = 5
    @AppStorage("flexibleCompany") private var flexibleCompany: Bool = false

    @AppStorage("dailySummaryEnabled") private var dailySummaryEnabled: Bool = true

    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBenefit = false

    private var payMode: PayMode { PayMode(rawValue: payModeRaw) ?? .hourly }

    var body: some View {
        NavigationStack {
            Form {
                // Pay mode
                Section("Mode de paie") {
                    Picker("Mode de paie", selection: $payModeRaw) {
                        ForEach(PayMode.allCases) { mode in
                            Label(mode.rawValue, systemImage: mode.systemImage).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    if payMode == .hourly {
                        amountRow(label: "Taux horaire net", value: $hourlyRate)
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
                        amountRow(label: "Valeur d'un ticket", value: $mealTicketValue)
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

                // Expenses
                Section("Budget") {
                    NavigationLink {
                        ExpensesView()
                    } label: {
                        Label("Dépenses fixes mensuelles", systemImage: "arrow.up.circle.fill")
                    }
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingAddBenefit) {
                AddBenefitView()
            }
        }
    }

    private func amountRow(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("Montant", value: value, format: .number.precision(.fractionLength(2)))
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
}
