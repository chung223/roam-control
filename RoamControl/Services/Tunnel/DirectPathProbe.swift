import Foundation
import Network
import Observation
import RoamPairingFFI
import os

/// Answers one question: must the pairing service be reached through
/// LocalDevVPN, or is it reachable directly?
///
/// The session path always connects to a fixed `10.7.0.1`, which is the address
/// LocalDevVPN provides, and never uses the addresses Bonjour already resolved
/// for the service. If one of those resolved addresses accepts a connection,
/// the tunnel app is not needed for this hop at all, and everything after it —
/// pair-verify, the TLS-PSK tunnel, the userspace TCP stack, RSD and DVT —
/// already runs inside this app.
///
/// This is read-only. It opens TCP connections and closes them without sending
/// a byte. It never starts, changes or stops a location session, and nothing it
/// finds is reported anywhere.
@MainActor
@Observable
final class DirectPathProbe: NSObject {
    struct Candidate: Identifiable, Sendable {
        enum Outcome: Equatable, Sendable {
            case pending
            case reachable(milliseconds: Int)
            case refused(String)
            case timedOut
        }

        let id = UUID()
        /// How the address was obtained, for reading the result.
        let source: Source
        let host: String
        let port: UInt16
        var outcome: Outcome = .pending

        enum Source: String, Sendable {
            /// The address LocalDevVPN provides. The control for comparison.
            case localDevVPN
            /// An address Bonjour resolved for the service itself.
            case bonjourIPv4
            case bonjourIPv6
            /// The device's own loopback. If a resolved address answers but
            /// this does not, the service is refusing loopback specifically,
            /// which is a different finding from "the app cannot reach it".
            case loopback
        }
    }

    enum State: Equatable {
        case notRun
        case searching
        case probing
        case finished
        case failed(String)
    }

    private static let perCandidateTimeout: TimeInterval = 2.5
    private static let discoveryTimeout: TimeInterval = 10

    private(set) var state: State = .notRun
    private(set) var candidates: [Candidate] = []
    private(set) var lastRun: Date?

    private let browser = NetServiceBrowser()
    private let probeQueue = DispatchQueue(label: "com.sean.roamcontrol.direct-path-probe")
    private var resolving: [NetService] = []
    private var pairingRecord: Data?
    private var discoveryTimeoutTask: Task<Void, Never>?
    private var matchedService = false

    override init() {
        super.init()
        browser.delegate = self
        browser.includesPeerToPeer = true
    }

    /// Whether any address other than LocalDevVPN's answered. This is the whole
    /// point of the experiment.
    var directPathWorks: Bool {
        candidates.contains { candidate in
            guard candidate.source == .bonjourIPv4 || candidate.source == .bonjourIPv6 else {
                return false
            }
            if case .reachable = candidate.outcome { return true }
            return false
        }
    }

    var loopbackWorks: Bool {
        candidates.contains { candidate in
            guard candidate.source == .loopback else { return false }
            if case .reachable = candidate.outcome { return true }
            return false
        }
    }

    var localDevVPNWorks: Bool {
        candidates.contains { candidate in
            guard candidate.source == .localDevVPN else { return false }
            if case .reachable = candidate.outcome { return true }
            return false
        }
    }

    func run(pairingRecord: Data?) {
        cancel()

        guard let pairingRecord else {
            state = .failed("Pair this iPhone before running the direct-path experiment.")
            return
        }

#if targetEnvironment(simulator)
        state = .failed("The direct-path experiment needs a physical iPhone.")
#else
        self.pairingRecord = pairingRecord
        candidates = []
        matchedService = false
        state = .searching
        browser.searchForServices(ofType: "_remotepairing._tcp.", inDomain: "local.")

        discoveryTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.discoveryTimeout))
            guard !Task.isCancelled, let self, self.state == .searching else { return }
            self.state = .failed(
                self.matchedService
                    ? "The paired iPhone was found but published no addresses to try."
                    : "No matching pairing service was found. Is the paired iPhone awake and on this network?"
            )
            self.stopDiscovery()
        }
#endif
    }

    func cancel() {
        stopDiscovery()
        discoveryTimeoutTask?.cancel()
        discoveryTimeoutTask = nil
        pairingRecord = nil
        if state == .searching || state == .probing {
            state = .notRun
        }
    }

    // MARK: - Discovery

    private func stopDiscovery() {
        browser.stop()
        for service in resolving {
            service.stop()
            service.remove(from: .main, forMode: .common)
            service.delegate = nil
        }
        resolving = []
    }

    private func resolve(_ service: NetService) {
        guard state == .searching else { return }
        service.delegate = self
        service.includesPeerToPeer = true
        service.schedule(in: .main, forMode: .common)
        service.resolve(withTimeout: 7)
        resolving.append(service)
    }

    private func inspect(_ service: NetService) {
        guard
            state == .searching,
            service.port > 0, service.port <= Int(UInt16.max),
            let pairingRecord,
            let txtData = service.txtRecordData()
        else { return }

        let values = NetService.dictionary(fromTXTRecord: txtData)
        guard
            let identifierData = values["identifier"],
            let authTagData = values["authTag"]
        else { return }

        let identifier = String(decoding: identifierData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authTag = String(decoding: authTagData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !authTag.isEmpty else { return }

        // Same identity check the session path uses, so this only ever probes
        // the iPhone this app is paired with.
        let isPairedDevice = pairingRecord.withUnsafeBytes { recordBytes in
            guard let base = recordBytes.bindMemory(to: UInt8.self).baseAddress else { return false }
            return identifier.withCString { serviceIdentifier in
                authTag.withCString { serviceAuthTag in
                    rc_pairing_record_matches_service(
                        base, pairingRecord.count, serviceIdentifier, serviceAuthTag
                    ) == 1
                }
            }
        }
        guard isPairedDevice else { return }

        matchedService = true
        let port = UInt16(service.port)
        var found: [Candidate] = []

        for addressData in service.addresses ?? [] {
            guard let described = ResolvedServiceAddress.describe(addressData) else { continue }
            // A resolved loopback address tells us nothing new.
            guard !ResolvedServiceAddress.isLoopback(described.host) else { continue }
            found.append(
                Candidate(
                    source: described.isIPv6 ? .bonjourIPv6 : .bonjourIPv4,
                    host: described.host,
                    port: port
                )
            )
        }

        // Loopback is not advertised by Bonjour, so it is added explicitly.
        // It separates "an app on this device can reach the service" from
        // "the service requires a non-loopback source address".
        found.append(Candidate(source: .loopback, host: "127.0.0.1", port: port))

        // The control: the path the app actually uses today.
        found.append(Candidate(source: .localDevVPN, host: "10.7.0.1", port: port))

        guard !found.isEmpty else { return }
        discoveryTimeoutTask?.cancel()
        discoveryTimeoutTask = nil
        stopDiscovery()
        candidates = found
        state = .probing
        probeAll()
    }

    // MARK: - Probing

    private func probeAll() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for index in self.candidates.indices {
                guard self.state == .probing else { return }
                let candidate = self.candidates[index]
                let outcome = await Self.probe(host: candidate.host, port: candidate.port)
                guard self.state == .probing, index < self.candidates.count else { return }
                self.candidates[index].outcome = outcome
            }
            guard self.state == .probing else { return }
            self.state = .finished
            self.lastRun = Date()
        }
    }

    /// Opens a TCP connection, records whether it came up, and closes it.
    /// Nothing is written and no protocol is spoken.
    private static func probe(host: String, port: UInt16) async -> Candidate.Outcome {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            return .refused("Invalid port")
        }

        let queue = DispatchQueue(label: "com.sean.roamcontrol.direct-path-probe.connection")
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )
        let started = Date()

        return await withCheckedContinuation { continuation in
            let hasResumed = OSAllocatedUnfairLock(initialState: false)
            @Sendable func finish(_ outcome: Candidate.Outcome) {
                let shouldResume = hasResumed.withLock { resumed -> Bool in
                    guard !resumed else { return false }
                    resumed = true
                    return true
                }
                guard shouldResume else { return }
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: outcome)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = Int(Date().timeIntervalSince(started) * 1000)
                    finish(.reachable(milliseconds: elapsed))
                case .failed(let error):
                    finish(.refused(Self.shortReason(error)))
                case .cancelled:
                    finish(.timedOut)
                case .setup, .preparing, .waiting:
                    break
                @unknown default:
                    break
                }
            }
            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + Self.perCandidateTimeout) {
                finish(.timedOut)
            }
        }
    }

    // Called from NWConnection's state handler on the connection's own queue,
    // and it only maps an error to text, so it is not actor state.
    private nonisolated static func shortReason(_ error: NWError) -> String {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED: return "Connection refused"
            case .EHOSTUNREACH: return "Host unreachable"
            case .ENETUNREACH: return "Network unreachable"
            case .ETIMEDOUT: return "Timed out"
            case .EACCES, .EPERM: return "Blocked by the system"
            default: return "POSIX \(code.rawValue)"
            }
        case .dns: return "DNS failure"
        case .tls: return "TLS failure"
        @unknown default: return "Unknown"
        }
    }
}

extension DirectPathProbe: NetServiceBrowserDelegate, NetServiceDelegate {
    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        MainActor.assumeIsolated { resolve(service) }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        MainActor.assumeIsolated {
            state = .failed("Local Network access is unavailable. Allow it in iPhone Settings, then try again.")
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        MainActor.assumeIsolated { inspect(sender) }
    }

    nonisolated func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        MainActor.assumeIsolated { inspect(sender) }
    }
}

extension DirectPathProbe.Candidate.Source {
    var label: String {
        switch self {
        case .localDevVPN: "LocalDevVPN (control)"
        case .bonjourIPv4: "Bonjour IPv4"
        case .bonjourIPv6: "Bonjour IPv6"
        case .loopback: "Loopback"
        }
    }
}
