import SwiftUI

/// A compact 7-day bar chart of hours worked, with today's bar highlighted.
struct WeekBarChart: View {
    let data: [DailyHours]
    var isToday: (Date) -> Bool = { _ in false }

    @Environment(\.colorScheme) private var colorScheme
    private let maxBarHeight: CGFloat = 104

    var body: some View {
        let peak = max(data.map(\.hours).max() ?? 0, 1)

        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data) { day in
                let today = isToday(day.date)
                VStack(spacing: 6) {
                    Text(day.hours > 0 ? shortHours(day.hours) : "")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 12)

                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.appTrack)
                            .frame(height: maxBarHeight)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.appAccent.opacity(today ? 1 : 0.35))
                            .frame(height: max(6, maxBarHeight * day.hours / peak))
                            .shadow(color: today ? Color.appAccent.opacity(colorScheme == .dark ? 0.6 : 0.2) : .clear,
                                    radius: 6, y: 2)
                    }
                    .frame(maxWidth: .infinity)

                    Text(weekdayLetter(day.date))
                        .font(.caption2.weight(today ? .bold : .regular))
                        .foregroundStyle(today ? Color.appAccent : .secondary)
                }
            }
        }
        .frame(height: maxBarHeight + 34)
    }

    private func weekdayLetter(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    private func shortHours(_ hours: Double) -> String {
        hours >= 1
            ? String(format: "%.0f", hours) + "h"
            : String(Int((hours * 60).rounded())) + "m"
    }
}

#Preview {
    let now = Date()
    let cal = Calendar.current
    let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
    let sample = (0..<7).map { i in
        DailyHours(date: cal.date(byAdding: .day, value: i, to: start)!,
                   hours: [3.5, 7, 0, 6.5, 8, 4, 0][i])
    }
    return WeekBarChart(data: sample, isToday: { cal.isDate($0, inSameDayAs: now) })
        .padding()
}
