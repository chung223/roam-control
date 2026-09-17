import ActivityKit
import SwiftUI
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
            .activitySystemActionForegroundColor(nil)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.isWalking ? "Walking" : "Simulating")
                    } icon: {
                        Image(systemName: context.state.symbolName)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(context.state.isSimulating ? .orange : .secondary)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedTimeText(startedAt: context.attributes.startedAt)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.placeName)
                            .font(.headline)
                            .lineLimit(1)

                        if context.state.isWalking {
                            WalkingProgressView(state: context.state)
                        } else {
                            Text(context.state.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.symbolName)
                    .foregroundStyle(context.state.isSimulating ? .orange : .secondary)
            } compactTrailing: {
                if context.state.isWalking, context.state.stage == .running {
                    Text(percentText(context.state.progress))
                        .font(.caption2.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.symbolName)
                    .foregroundStyle(context.state.isSimulating ? .orange : .secondary)
            }
            .widgetURL(URL(string: "roamcontrol://session"))
        }
    }

    private func percentText(_ progress: Double) -> String {
        "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
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
                .foregroundStyle(state.isSimulating ? .orange : .secondary)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(state.placeName)
                    .font(.headline)
                    .lineLimit(1)

                if state.isWalking {
                    WalkingProgressView(state: state)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                ElapsedTimeText(startedAt: startedAt)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text("Roam Control")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
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
            ProgressView(value: min(max(state.progress, 0), 1))
                .tint(state.stage == .paused ? .secondary : .green)

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
        guard state.stage != .arrived else { return "Arrived" }

        let measurement = Measurement(
            value: state.remainingDistance,
            unit: UnitLength.meters
        )
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = state.remainingDistance < 1000 ? 0 : 1
        return "\(formatter.string(from: measurement)) left"
    }
}

private struct ElapsedTimeText: View {
    let startedAt: Date

    var body: some View {
        Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
    }
}
