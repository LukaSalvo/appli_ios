import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Shared contract for the "pay in progress" Live Activity.
/// Compiled into both the app (which starts / refreshes it) and the widget
/// extension (which renders it on the Lock Screen and the Dynamic Island).
struct PayActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// When the session started — the widget renders a live-ticking timer
        /// from this without needing per-second updates.
        var startDate: Date
        /// Pay accrued as of the last update pushed by the app.
        var earned: Double
        /// Effective hourly rate (base rate + per-hour benefits), for context.
        var ratePerHour: Double
    }

    /// Static label shown by the activity.
    var title: String
}
#endif
