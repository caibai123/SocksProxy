import Foundation

enum ProxyRule {
    static let proxiedDomains: Set<String> = [
        "nj.cschannel.anticheatexpert.com",
        "4399.com"
    ]

    static func shouldProxyDomain(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        for domain in proxiedDomains {
            if lowercased == domain || lowercased.hasSuffix("." + domain) {
                return true
            }
        }
        return false
    }
}
