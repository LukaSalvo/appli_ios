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

extension LinearGradient {
    /// Vibrant teal → green, used on the hero numbers to make them pop.
    static let moneyText = LinearGradient(
        colors: [Color(red: 0.16, green: 0.78, blue: 0.58),
                 Color(red: 0.08, green: 0.52, blue: 0.38)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Soft accent wash for hero card backgrounds.
    static let heroWash = LinearGradient(
        colors: [Color.appAccent.opacity(0.16), Color.appAccent.opacity(0.03)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

/// A rounded card container used across the app for a consistent look.
/// `hero` gives it a subtle tinted wash + stronger lift for the main number.
struct Card<Content: View>: View {
    var hero: Bool = false
    var content: Content

    init(hero: Bool = false, @ViewBuilder content: () -> Content) {
        self.hero = hero
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(.secondarySystemGroupedBackground))
                if hero {
                    RoundedRectangle(cornerRadius: 22).fill(LinearGradient.heroWash)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(hero ? 0.08 : 0.05),
                    radius: hero ? 14 : 8, x: 0, y: hero ? 8 : 4)
    }
}
