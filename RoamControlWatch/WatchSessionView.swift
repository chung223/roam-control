import SwiftUI

/// One screen, because there is only one question worth asking from a wrist:
/// how far has it got, and can I hold it here.
struct WatchSessionView: View {
    @Environment(WatchLink.self) private var link

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !link.hasHeardFromPhone {
                    WaitingView(isReachable: link.isReachable)
                } else if link.state.isRunning {
                    RunningView(state: link.state, onTogglePause: link.togglePause)
                } else {
                    IdleView(message: link.state.message)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sprout")
    }
}

private struct WaitingView: View {
    let isReachable: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: isReachable ? "ellipsis.circle" : "iphone.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(isReachable ? "Waiting for the iPhone" : "The iPhone is not reachable")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }
}

private struct IdleView: View {
    let message: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf")
                .font(.title2)
                .foregroundStyle(.green)
            Text("No session running")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 24)
    }
}

private struct RunningView: View {
    let state: WatchSessionState
    let onTogglePause: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let progress = state.progress {
                Gauge(value: progress.clamped()) {
                    Image(systemName: "figure.walk")
                } currentValueLabel: {
                    Text(progress.clamped().formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption.monospacedDigit())
                }
                .gaugeStyle(.accessoryCircular)
                .tint(.green)
            } else {
                Image(systemName: "mappin.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            }

            Text(state.placeName)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let metres = state.metresRemaining {
                Text(distanceText(metres))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // While paused there is no arrival to count down to, and a
            // countdown that keeps running would be describing a walk that has
            // stopped.
            if let arrivesAt = state.arrivesAt, !state.isPaused, arrivesAt > .now {
                Text(arrivesAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if state.isWalking {
                Button(action: onTogglePause) {
                    Label(
                        state.isPaused ? "Resume" : "Pause",
                        systemImage: state.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }

            if state.phase == .stopping {
                Text("Restoring the real location")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }

    /// Whole units. On a wrist, "1.2 km" is read and "1,238 m" is decoded.
    private func distanceText(_ metres: Double) -> String {
        Measurement(value: metres, unit: UnitLength.meters)
            .formatted(
                .measurement(
                    width: .abbreviated,
                    usage: .road,
                    numberFormatStyle: .number.precision(.fractionLength(0...1))
                )
            )
    }
}

private extension Double {
    func clamped() -> Double { Swift.min(1, Swift.max(0, self)) }
}
