import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// Lock Screen and Dynamic Island presentation of a running location session.
///
/// Tapping anywhere opens Roam Control, which is where a session can actually
/// be stopped. The activity deliberately carries no controls of its own: the
/// stop path has to restore the real location and confirm the device accepted
/// it, and that is not something to fire off from a Lock Screen tap.
struct RoamSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RoamSessionActivityAttributes.self) { context in
            LockScreenView(
                state: context.state,
                startedAt: context.attributes.startedAt
            )
            .widgetURL(URL(string: "roamcontrol://session"))
            .activityBackgroundTint(nil)
            .activitySystemActionForegroundColor(SproutActivity.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(ActivityText.localized(context.state.isWalking ? "Walking" : "Simulating"))
                    } icon: {
                        Image(systemName: context.state.symbolName)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SproutActivity.tint(for: context.state))
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeText(startedAt: context.attributes.startedAt)
                        .font(.caption.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        // Two lines here as well as on the Lock Screen: the
                        // expanded view is the one with room to read the whole
                        // address, so it should not be the one that cuts it.
                        Text(context.state.placeName)
                            .font(.headline)
                            .lineLimit(2)

                        // The leading region already names the stage. Repeating
                        // it here only made the expanded view taller and emptier,
                        // and the guidance is to use the height the content needs.
                        if context.state.isWalking {
                            WalkingProgressView(state: context.state)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The island's bottom corners curve inwards over this
                    // region, and without the inset they clipped the first
                    // character of the distance line.
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(systemName: context.state.symbolName)
                    .foregroundStyle(SproutActivity.tint(for: context.state))
            } compactTrailing: {
                CompactTrailing(
                    state: context.state,
                    startedAt: context.attributes.startedAt
                )
            } minimal: {
                ProgressRing(state: context.state)
            }
            .widgetURL(URL(string: "roamcontrol://session"))
            .keylineTint(SproutActivity.primary)
        }
    }
}

// MARK: - Lock Screen

private struct LockScreenView: View {
    let state: RoamSessionActivityAttributes.ContentState
    let startedAt: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: state.symbolName)
                .font(.title2)
                .foregroundStyle(SproutActivity.tint(for: state))
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(ActivityText.localized(state.statusText))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Two lines: a Taiwanese street address does not fit one at
                // this size, and truncating it loses the part that identifies
                // the place.
                Text(state.placeName)
                    .font(.headline)
                    .lineLimit(2)

                if state.isWalking {
                    WalkingProgressView(state: state)
                        .padding(.top, 2)
                }
            }
            // Claims the width rather than leaving a Spacer to argue with the
            // text over it. A Spacer and a truncatable Text are both flexible,
            // so an HStack splits the free width between them: the address was
            // cut short, the route bar stopped half way across, and the space
            // they were arguing over sat empty to the right of both.
            //
            // The priority belongs here and not on the elapsed time. Putting it
            // there instead let the time take the row and left this column a
            // few characters wide, one per line.
            .frame(maxWidth: .infinity, alignment: .leading)

            // No wordmark here. It was dim, carried nothing, and sat in the
            // width the address needed.
            // A timer text is greedy: offered space, it takes it. Beside a
            // column that also wants the width, the two split the banner down
            // the middle — half of it reserved to print four characters, with
            // the address and the route bar laid out in what was left.
            //
            // Capping it is enough to stop that. fixedSize is not — its ideal
            // width is larger than the cap, so the text was clipped away to
            // nothing. The eight-hour bound fixes the longest string it can
            // show at 7:59:59, which fits well inside the cap.
            ElapsedTimeText(startedAt: startedAt)
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: 72, alignment: .trailing)
                // The timer fills the cap, so the frame's alignment never
                // applies to it; the text has to align itself.
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        // The row was sizing to its content, which left the elapsed time
        // stranded mid-banner with empty space past it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [state.statusText, state.placeName]
        if state.isWalking, state.stage == .running {
            parts.append("\(Int((state.progress * 100).rounded())) percent complete")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Shared pieces

private struct WalkingProgressView: View {
    let state: RoamSessionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RouteTrail(
                progress: state.progress,
                isPaused: state.stage == .paused
            )
            // RouteTrail is a GeometryReader, which contributes no width of
            // its own, so the column would otherwise be as wide as the text
            // and the bar would stop with it.
            .frame(maxWidth: .infinity)

            HStack(spacing: 6) {
                Text(distanceText)

                if
                    state.stage == .running,
                    let expectedArrival = state.expectedArrival,
                    expectedArrival > .now
                {
                    Text("·")
                    // Counts down in place, so the app does not have to push an
                    // update every second to keep this honest.
                    Text(timerInterval: Date.now...expectedArrival, countsDown: true)
                        .monospacedDigit()
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var distanceText: String {
        guard state.stage != .arrived else { return ActivityText.localized("Arrived") }

        let measurement = Measurement(
            value: state.remainingDistance,
            unit: UnitLength.meters
        )
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = state.remainingDistance < 1000 ? 0 : 1
        let distance = formatter.string(from: measurement)
        return String(localized: "\(distance) left")
    }
}

private struct ElapsedTimeText: View {
    let startedAt: Date

    /// Bounded, not open ended. A range ending at distantFuture makes the view
    /// reserve room for the longest duration it could ever print, and on the
    /// Lock Screen that reservation took about 40% of the banner to show four
    /// characters — everything else was laid out in what was left, which is
    /// why the address wrapped early and the route bar stopped short.
    ///
    /// Eight hours is the longest a Live Activity is meant to run, so it is
    /// the widest this ever has to be.
    private var interval: ClosedRange<Date> {
        startedAt...startedAt.addingTimeInterval(8 * 60 * 60)
    }

    var body: some View {
        Text(timerInterval: interval, countsDown: false)
    }
}

// MARK: - Dynamic Island pieces

/// The smallest presentation. A walk draws its progress as a ring around the
/// glyph, so the one place with room for nothing else still says how far along
/// the walk is.
private struct ProgressRing: View {
    let state: RoamSessionActivityAttributes.ContentState

    private var showsRing: Bool {
        state.isWalking && (state.stage == .running || state.stage == .paused)
    }

    var body: some View {
        ZStack {
            if showsRing {
                Circle()
                    .stroke(SproutActivity.primary.opacity(0.25), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min(max(state.progress, 0), 1))
                    .stroke(
                        SproutActivity.tint(for: state),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: state.symbolName)
                .font(.system(size: showsRing ? 9 : 12, weight: .bold))
                .foregroundStyle(SproutActivity.tint(for: state))
        }
    }
}

/// Carries a walk's own numbers — time to arrival, or percent when there is no
/// estimate. Both are short. Anything longer makes the island grow to hold it.
private struct CompactTrailing: View {
    let state: RoamSessionActivityAttributes.ContentState
    let startedAt: Date

    var body: some View {
        content
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(SproutActivity.tint(for: state))
    }

    @ViewBuilder
    private var content: some View {
        if
            state.isWalking,
            state.stage == .running,
            let expectedArrival = state.expectedArrival,
            expectedArrival > .now
        {
            // Counts down in place, like the Lock Screen, so a walk does not
            // cost an activity update every second.
            Text(timerInterval: Date.now...expectedArrival, countsDown: true)
        } else if state.isWalking, state.stage == .running || state.stage == .paused {
            Text(percentText)
        }
        // A held location has no number worth the width. The guidance is to
        // use only the space the content needs, and an elapsed timer here
        // rendered as h:mm:ss and stretched the island for nothing.
    }

    private var percentText: String {
        "\(Int((min(max(state.progress, 0), 1) * 100).rounded()))%"
    }
}

/// The walking route as a trail with a marker on it, rather than a bar. The
/// marker is the same walking glyph the rest of the session uses, so the two
/// read as the same thing at different sizes.
private struct RouteTrail: View {
    let progress: Double
    let isPaused: Bool

    private static let marker: CGFloat = 14

    private var clamped: Double { min(max(progress, 0), 1) }
    private var fill: Color { isPaused ? SproutActivity.accent : SproutActivity.primary }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SproutActivity.primary.opacity(0.35))
                    .frame(height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)

                Capsule()
                    .fill(fill)
                    .frame(width: max(6, width * clamped), height: 6)
                    .frame(maxHeight: .infinity, alignment: .center)

                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Self.marker, height: Self.marker)
                    .background(Circle().fill(fill))
                    .offset(x: width * clamped - Self.marker / 2)
            }
        }
        .frame(height: Self.marker)
        // Inset by half the marker so that at 0% and 100% it still sits inside
        // the view, and never reaches the rounded edge of the island — the
        // guidance asks content not to touch it.
        .padding(.horizontal, Self.marker / 2)
    }
}

// MARK: - Text

/// The extension compiles none of the app's resources, so it carries its own
/// String Catalog. Without this every word on the Lock Screen and in the
/// Dynamic Island stayed English whatever the device language was.
///
/// The English stays the key, exactly as `SessionMessage` does in the app, so
/// a string with no entry falls back to itself rather than disappearing.
private enum ActivityText {
    static func localized(_ english: String) -> String {
        String(localized: String.LocalizationValue(english))
    }
}

// MARK: - Palette

/// `SproutTheme` belongs to the app target, which this extension does not
/// compile, so the two colours the activity needs are mirrored here. Keep them
/// in step with `RoamControl/Resources/Theme/SproutTheme.swift`.
private enum SproutActivity {
    static let primary = dynamic(light: 0x6F9A4E, dark: 0xA3CC7A)
    static let accent = dynamic(light: 0xD4694A, dark: 0xE8896B)

    static func tint(for state: RoamSessionActivityAttributes.ContentState) -> Color {
        switch state.stage {
        case .running, .arrived: primary
        case .paused: accent
        // Dimmed rather than .secondary: the island is always black, and
        // .secondary there is close to invisible exactly while connecting.
        case .connecting, .stopping, .restoring: primary.opacity(0.6)
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
