import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Starts, refreshes and ends the Lock Screen / Dynamic Island Live Activity
/// that shows pay accruing during an hourly session. All calls are safe no-ops
/// when Live Activities are unavailable or disabled by the user.
enum LiveActivityManager {
    #if canImport(ActivityKit)
    static func start(startDate: Date, earned: Double, ratePerHour: Double, hideAmounts: Bool = false) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // If one is already live (e.g. after a relaunch), just refresh it.
        guard Activity<PayActivityAttributes>.activities.isEmpty else {
            update(startDate: startDate, earned: earned, ratePerHour: ratePerHour, hideAmounts: hideAmounts)
            return
        }
        let attributes = PayActivityAttributes(title: "Paie en cours")
        let state = PayActivityAttributes.ContentState(
            startDate: startDate, earned: earned, ratePerHour: ratePerHour, hideAmounts: hideAmounts
        )
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil)
            )
        } catch {
            // Non-fatal: the activity simply won't appear.
        }
    }

    static func update(startDate: Date, earned: Double, ratePerHour: Double, hideAmounts: Bool = false) {
        let state = PayActivityAttributes.ContentState(
            startDate: startDate, earned: earned, ratePerHour: ratePerHour, hideAmounts: hideAmounts
        )
        Task {
            for activity in Activity<PayActivityAttributes>.activities {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            }
        }
    }

    static func end() {
        Task {
            for activity in Activity<PayActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #else
    static func start(startDate: Date, earned: Double, ratePerHour: Double, hideAmounts: Bool = false) {}
    static func update(startDate: Date, earned: Double, ratePerHour: Double, hideAmounts: Bool = false) {}
    static func end() {}
    #endif
}
