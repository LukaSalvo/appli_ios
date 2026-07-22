import SwiftUI

extension Color {
    /// App accent — a confident teal-green that reads as "money in".
    static let appAccent = Color(red: 0.11, green: 0.63, blue: 0.47)
    /// Positive amounts (income, remaining budget).
    static let moneyGood = Color(red: 0.11, green: 0.55, blue: 0.40)
    /// Warnings / amounts leaving the account.
    static let moneyOut = Color(red: 0.85, green: 0.42, blue: 0.20)
    /// Over-budget / danger.
    static let moneyDanger = Color(red: 0.80, green: 0.25, blue: 0.22)
}

/// A rounded card container used across the app for a consistent look.
struct Card<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
    }
}
