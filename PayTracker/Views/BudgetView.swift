import SwiftUI
import SwiftData

struct BudgetView: View {
    @AppStorage("payMode") private var payModeRaw: String = PayMode.hourly.rawValue
    @AppStorage("monthlySalary") private var monthlySalary: Double = 1800

    // Current account balance
    @AppStorage("currentBalance") private var currentBalance: Double = 0
    @State private var showingEditBalance = false

    // Meal-ticket settings
    @AppStorage("mealTicketsEnabled") private var mealTicketsEnabled: Bool = true
    @AppStorage("mealTicketValue") private var mealTicketValue: Double = 9.0
    @AppStorage("mealTicketEmployerPct") private var mealTicketEmployerPct: Double = 60
    @AppStorage("daysWorkedPerMonth") private var daysWorkedPerMonth: Int = 20

    @Query(filter: #Predicate<WorkSession> { $0.endDate != nil })
    private var completedSessions: [WorkSession]

    @Query(sort: \Expense.createdAt) private var expenses: [Expense]

    private var payMode: PayMode { PayMode(rawValue: payModeRaw) ?? .hourly }

    // MARK: - Derived figures

    /// Distinct calendar days worked this month (for the meal-ticket count).
    private var daysWorkedThisMonth: Int {
        if payMode == .monthly { return daysWorkedPerMonth }
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: .now) else { return 0 }
        let days = completedSessions
            .filter { month.contains($0.startDate) }
            .map { cal.startOfDay(for: $0.startDate) }
        return Set(days).count
    }

    private var salaryIncome: Double {
        if payMode == .monthly { return monthlySalary }
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: .now) else { return 0 }
        return completedSessions
            .filter { month.contains($0.startDate) }
            .reduce(0) { $0 + $1.totalPay() }
    }

    private var mealConfig: MealTicketConfig {
        MealTicketConfig(
            isEnabled: mealTicketsEnabled,
            faceValue: mealTicketValue,
            employerSharePct: mealTicketEmployerPct,
            daysWorked: daysWorkedThisMonth
        )
    }

    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private var summary: BudgetSummary {
        BudgetSummary(
            salaryIncome: salaryIncome,
            mealTicketBenefit: mealConfig.employerBenefit,
            totalExpenses: totalExpenses
        )
    }

    /// What's left to receive/pay this month, based on how much of the month has elapsed.
    private var remainingIncomeThisMonth: Double {
        summary.totalIncome * (1 - monthElapsedFraction())
    }
    private var remainingExpensesThisMonth: Double {
        summary.totalExpenses * (1 - monthElapsedFraction())
    }

    /// Current balance projected to the end of the month, given what's left to
    /// come in (salary/benefits not yet received) and go out (expenses not yet paid).
    private var projectedEndOfMonthBalance: Double {
        currentBalance + remainingIncomeThisMonth - remainingExpensesThisMonth
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    ringCard
                    incomeCard
                    if mealTicketsEnabled {
                        mealTicketCard
                    }
                    expensesCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Budget")
            .sheet(isPresented: $showingEditBalance) {
                EditBalanceView(balance: $currentBalance)
            }
        }
    }

    // MARK: - Cards

    private var balanceCard: some View {
        Card(hero: true) {
            VStack(spacing: 12) {
                HStack {
                    Label("Solde actuel", systemImage: "banknote.fill")
                        .font(.headline)
                        .foregroundStyle(Color.goldInk)
                    Spacer()
                    Button {
                        showingEditBalance = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                Text(Money.string(currentBalance))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient.moneyText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: currentBalance)
                Divider()
                HStack {
                    Text("Estimé en fin de mois")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.string(projectedEndOfMonthBalance))
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(projectedEndOfMonthBalance < 0 ? Color.moneyDanger : Color.moneyGood)
                }
            }
        }
        .onTapGesture {
            showingEditBalance = true
        }
    }

    private var ringCard: some View {
        Card(hero: true) {
            VStack(spacing: 12) {
                BudgetRing(
                    spentFraction: summary.spentFraction,
                    remaining: summary.remaining,
                    isOverBudget: summary.remaining < 0
                )
                HStack(spacing: 24) {
                    legend(color: .moneyGood, label: "Revenus", value: summary.totalIncome)
                    legend(color: .moneyOut, label: "Dépenses fixes", value: summary.totalExpenses)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var incomeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Revenus du mois", systemImage: "arrow.down.circle.fill", tint: .moneyGood)
                line(payMode == .monthly ? "Salaire net" : "Heures travaillées ce mois",
                     Money.string(summary.salaryIncome))
                if summary.mealTicketBenefit > 0 {
                    line("Part employeur tickets restau", Money.string(summary.mealTicketBenefit))
                }
                Divider()
                line("Total", Money.string(summary.totalIncome), bold: true)
            }
        }
    }

    private var mealTicketCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("Tickets restaurant", systemImage: "fork.knife", tint: .goldInk)
                line("Tickets ce mois", "\(mealConfig.daysWorked) × \(Money.string(mealTicketValue))")
                line("Valeur totale", Money.string(mealConfig.totalFaceValue))
                line("Payé par l'employeur (\(Int(mealTicketEmployerPct)) %)",
                     Money.string(mealConfig.employerBenefit))
                line("Votre part", Money.string(mealConfig.employeeCost))
            }
        }
    }

    private var expensesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader("Dépenses fixes", systemImage: "arrow.up.circle.fill", tint: .moneyOut)
                    Spacer()
                    NavigationLink {
                        ExpensesView()
                    } label: {
                        Text("Gérer").font(.subheadline.bold())
                    }
                }
                if expenses.isEmpty {
                    Text("Aucune dépense fixe. Ajoutez votre loyer, vos abonnements…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(expenses.prefix(6)) { expense in
                        HStack {
                            Image(systemName: expense.category.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(expense.name)
                            Spacer()
                            Text(Money.string(expense.amount))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                    if expenses.count > 6 {
                        Text("+ \(expenses.count - 6) autres")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    line("Total", Money.string(totalExpenses), bold: true)
                }
            }
        }
    }

    // MARK: - Small building blocks

    private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(tint)
    }

    private func line(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).foregroundStyle(bold ? .primary : .secondary)
            Spacer()
            Text(value)
                .fontWeight(bold ? .bold : .semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
    }

    private func legend(color: Color, label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            Text(Money.string(value))
                .font(.subheadline.bold())
                .monospacedDigit()
        }
    }
}

#Preview {
    BudgetView()
        .modelContainer(for: [WorkSession.self, Benefit.self, Expense.self], inMemory: true)
}
