import Foundation

/// Reads the addresses Bonjour resolved for a service.
///
/// Shared by the direct-path experiment and the session path, so that what the
/// experiment probes and what a session would dial are derived the same way.
enum ResolvedServiceAddress {
    /// Renders a resolved `sockaddr` as a numeric address, keeping the scope
    /// on an IPv6 link-local address because it is not routable without one.
    static func describe(_ addressData: Data) -> (host: String, isIPv6: Bool)? {
        addressData.withUnsafeBytes { raw -> (String, Bool)? in
            guard
                raw.count >= MemoryLayout<sockaddr>.size,
                let base = raw.baseAddress?.assumingMemoryBound(to: sockaddr.self)
            else { return nil }

            let family = base.pointee.sa_family
            guard family == sa_family_t(AF_INET) || family == sa_family_t(AF_INET6) else {
                return nil
            }

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let status = getnameinfo(
                base,
                socklen_t(addressData.count),
                &hostBuffer,
                socklen_t(hostBuffer.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard status == 0 else { return nil }
            return (String(cString: hostBuffer), family == sa_family_t(AF_INET6))
        }
    }

    /// The resolved addresses worth dialling, loopback removed. IPv4 first: a
    /// link-local IPv6 address needs its scope to survive, and an address
    /// without one would fail for a reason unrelated to what is being tested.
    static func dialable(from addresses: [Data]?) -> [String] {
        var hosts: [String] = []
        for data in addresses ?? [] {
            guard let described = describe(data) else { continue }
            guard !described.host.hasPrefix("127."), described.host != "::1" else { continue }
            hosts.append(described.host)
        }
        return hosts.sorted { !$0.contains(":") && $1.contains(":") }
    }
}
