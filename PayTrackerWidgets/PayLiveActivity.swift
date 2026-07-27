import SwiftUI
import WidgetKit
import ActivityKit

/// The Live Activity: shows the session timer ticking and the pay earned so
/// far, both on the Lock Screen and in the Dynamic Island.
///
/// Amounts go through ``maskedAmount(_:hidden:)``: when the user has asked for
/// amounts to stay private, the Lock Screen shows the running timer but never
/// the euro figures.
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
                    maskedAmount(context.state.earned, hidden: context.state.hideAmounts)
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.startDate, style: .timer)
                            .monospacedDigit()
                        Spacer()
                        maskedRate(context.state.ratePerHour, hidden: context.state.hideAmounts)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                maskedAmount(context.state.earned, hidden: context.state.hideAmounts)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

/// A euro amount, or a placeholder when the user keeps amounts off the Lock Screen.
private func maskedAmount(_ value: Double, hidden: Bool) -> Text {
    hidden ? Text("•••") : Text(value, format: .currency(code: "EUR"))
}

private func maskedRate(_ value: Double, hidden: Bool) -> Text {
    hidden ? Text("•••/h") : Text("\(value, format: .currency(code: "EUR"))/h")
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
                maskedAmount(state.earned, hidden: state.hideAmounts)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.green)
                maskedRate(state.ratePerHour, hidden: state.hideAmounts)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
