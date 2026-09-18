import Foundation
import Observation
import UIKit

/// Runs one of the reader's own Shortcuts when a session finishes.
///
/// The reason it exists is the half of a workflow this app cannot be part of.
/// Someone who turns a proxy off and a tracker off before starting can do that
/// from a Shortcut that calls Start Location — the order is right and nothing
/// here is needed. Turning them back on afterwards is the other half, and the
/// afterwards can happen while nobody is holding the phone.
///
/// There is a hard limit in the way: an app in the background cannot launch
/// another app, the Shortcuts app included. So a walk that arrives in a pocket
/// cannot run anything at that moment. Rather than pretend otherwise, the
/// request is held and run the next time the app is brought forward, and the
/// interface says that is what will happen.
@MainActor
@Observable
final class ShortcutRunner {
    static let nameKey = "shortcutToRunWhenSessionEnds"

    /// Posted when a session has finished in a way worth telling a Shortcut
    /// about: the real location restored, or a walk reaching its destination.
    /// A notification rather than a call, because the two moments are known to
    /// different objects and neither should have to know about this one.
    static let sessionFinished = Notification.Name("SproutSessionFinished")

    /// Where the callback comes back to, so Shortcuts hands the screen back
    /// rather than leaving the reader in it.
    static let returnURL = URL(string: "roamcontrol://shortcut-finished")!

    private(set) var isPending = false

    @ObservationIgnored
    private var observer: (any NSObjectProtocol)?

    var name: String {
        get { UserDefaults.standard.string(forKey: Self.nameKey) ?? "" }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            UserDefaults.standard.set(trimmed, forKey: Self.nameKey)
        }
    }

    var isConfigured: Bool { !name.isEmpty }

    /// Whether Shortcuts is there to be asked. Requires `shortcuts` in
    /// `LSApplicationQueriesSchemes`; without it this answers false and the
    /// setting explains itself rather than failing silently later.
    var isAvailable: Bool {
        guard let url = URL(string: "shortcuts://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: Self.sessionFinished,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.request() }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func request() {
        guard isConfigured, isAvailable else { return }
        guard UIApplication.shared.applicationState == .active else {
            isPending = true
            return
        }
        run()
    }

    /// Called when the app comes forward. A held request runs once and is
    /// forgotten: a shortcut that turns a proxy back on is not improved by
    /// running it twice, and by the second launch it is no longer news.
    func runPendingIfNeeded() {
        guard isPending else { return }
        isPending = false
        guard isConfigured, isAvailable else { return }
        run()
    }

    func cancelPending() {
        isPending = false
    }

    private func run() {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: Self.returnURL.absoluteString),
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }
}
