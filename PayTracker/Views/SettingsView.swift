import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("hourlyRate") private var hourlyRate: Double = 11.65
    @Query(sort: \Benefit.createdAt) private var benefits: [Benefit]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddBenefit = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Taux horaire") {
                    HStack {
                        Text("€ / heure")
                        Spacer()
                        TextField("Taux", value: $hourlyRate, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }

                Section {
                    if benefits.isEmpty {
                        Text("Aucun avantage pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(benefits) { benefit in
                            BenefitRowView(benefit: benefit)
                        }
                        .onDelete(perform: deleteBenefits)
                    }
                } header: {
                    Text("Avantages")
                } footer: {
                    Text("Les avantages « par heure » s'ajoutent à votre taux horaire. Les avantages « par prise de poste » (ex : prime panier repas) sont ajoutés une seule fois au démarrage d'une session.")
                }

                Button {
                    showingAddBenefit = true
                } label: {
                    Label("Ajouter un avantage", systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showingAddBenefit) {
                AddBenefitView()
            }
        }
    }

    private func deleteBenefits(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(benefits[index])
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [WorkSession.self, Benefit.self], inMemory: true)
}
