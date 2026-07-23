import SwiftUI
import WidgetKit
import ActivityKit

/// The Live Activity: shows the session timer ticking and the pay earned so
/// far, both on the Lock Screen and in the Dynamic Island.
struct PayLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PayActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.4))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("En cours", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.earned, format: .currency(code: "EUR"))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.startDate, style: .timer)
                            .monospacedDigit()
                        Spacer()
                        Text("\(context.state.ratePerHour, format: .currency(code: "EUR"))/h")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.earned, format: .currency(code: "EUR"))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: PayActivityAttributes.ContentState

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Paie en cours", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.startDate, style: .timer)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(state.earned, format: .currency(code: "EUR"))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.green)
                Text("\(state.ratePerHour, format: .currency(code: "EUR"))/h")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
