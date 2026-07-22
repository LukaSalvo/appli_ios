import SwiftUI

struct BenefitRowView: View {
    @Bindable var benefit: Benefit

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.name)
                    .font(.body)
                Text(benefit.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(benefit.amount, format: .currency(code: "EUR"))
                .foregroundStyle(.secondary)
            Toggle("", isOn: $benefit.isEnabled)
                .labelsHidden()
        }
    }
}
