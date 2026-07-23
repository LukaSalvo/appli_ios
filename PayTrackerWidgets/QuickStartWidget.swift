import SwiftUI
import WidgetKit

/// A small Home Screen widget that deep-links straight into pay tracking.
/// It carries no personal data, so it needs no App Group entitlement.
struct QuickStartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickStartWidget", provider: QuickStartProvider()) { _ in
            QuickStartView()
        }
        .configurationDisplayName("Suivi de paie")
        .description("Démarrez le suivi de votre paie en un tap.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickStartEntry: TimelineEntry {
    let date: Date
}

struct QuickStartProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickStartEntry {
        QuickStartEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickStartEntry) -> Void) {
        completion(QuickStartEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickStartEntry>) -> Void) {
        // Static content — never needs refreshing.
        completion(Timeline(entries: [QuickStartEntry(date: .now)], policy: .never))
    }
}

struct QuickStartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "eurosign.circle.fill")
                .font(.title)
                .foregroundStyle(.white)
            Spacer()
            Text("Suivre ma paie")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Touchez pour démarrer")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "paytracker://start"))
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.22, blue: 0.15),
                         Color(red: 0.02, green: 0.11, blue: 0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }
}
