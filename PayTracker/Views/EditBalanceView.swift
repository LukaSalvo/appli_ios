import SwiftUI

/// Sheet to set the current account balance ("j'ai X € sur mon compte").
struct EditBalanceView: View {
    @Binding var balance: Double
    @Environment(\.dismiss) private var dismiss

    @State private var amount: Double

    init(balance: Binding<Double>) {
        _balance = balance
        _amount = State(initialValue: balance.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Solde actuel")
                        Spacer()
                        TextField("Montant", value: $amount, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("€").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Le solde de votre compte aujourd'hui. L'app l'utilise pour estimer votre solde en fin de mois.")
                }
            }
            .navigationTitle("Solde actuel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        balance = amount
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    EditBalanceView(balance: .constant(1250))
}
