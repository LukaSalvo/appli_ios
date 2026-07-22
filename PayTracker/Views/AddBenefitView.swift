import SwiftUI
import SwiftData

struct AddBenefitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var type: BenefitType = .perShift

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom (ex : Prime panier repas)", text: $name)
                TextField("Montant", value: $amount, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                Picker("Type", selection: $type) {
                    ForEach(BenefitType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            .navigationTitle("Nouvel avantage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let benefit = Benefit(name: name, amount: amount, type: type)
                        modelContext.insert(benefit)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddBenefitView()
        .modelContainer(for: [WorkSession.self, Benefit.self], inMemory: true)
}
