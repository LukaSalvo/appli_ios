import SwiftUI

extension Color {
    /// Identity "carnet de paie": pine-green money + a gold signature accent.
    /// App accent — a deep pine green that reads as "money in".
    static let appAccent = Color(red: 0.055, green: 0.541, blue: 0.373)
    /// Positive amounts (income, remaining budget).
    static let moneyGood = Color(red: 0.047, green: 0.522, blue: 0.345)
    /// Signature secondary accent (tickets restau, "en cours", highlights).
    static let gold = Color(red: 0.663, green: 0.475, blue: 0.122)
    /// A darker gold for text/icons on light grounds.
    static let goldInk = Color(red: 0.541, green: 0.384, blue: 0.071)
    /// Warnings / amounts leaving the account.
    static let moneyOut = Color(red: 0.769, green: 0.412, blue: 0.169)
    /// Over-budget / danger.
    static let moneyDanger = Color(red: 0.745, green: 0.227, blue: 0.188)
}

extension LinearGradient {
    /// Vibrant pine → emerald, used on the hero numbers to make them pop.
    static let moneyText = LinearGradient(
        colors: [Color(red: 0.13, green: 0.72, blue: 0.52),
                 Color(red: 0.04, green: 0.50, blue: 0.34)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// Soft accent wash for hero card backgrounds.
    static let heroWash = LinearGradient(
        colors: [Color.appAccent.opacity(0.15), Color.appAccent.opacity(0.03)],
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
                    .overlay {
                        if hero { RoundedRectangle(cornerRadius: 22).fill(LinearGradient.heroWash) }
                    }
                    .overlay(alignment: .top) {
                        if hero { Rectangle().fill(Color.gold).frame(height: 3) } // receipt-style top edge
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.primary.opacity(0.04), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(hero ? 0.08 : 0.05),
                    radius: hero ? 14 : 8, x: 0, y: hero ? 8 : 4)
    }
}
