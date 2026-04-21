import Foundation

protocol Socks5ConnectionDelegate: AnyObject {
    func connectionDidConnect()
    func connectionDidDisconnect(error: Error?)
    func connectionDidFail(with error: Error)
}

class Socks5Connection: NSObject, GCDAsyncSocketDelegate {
    private var socket: GCDAsyncSocket?
    private weak var delegate: Socks5ConnectionDelegate?

    private var serverHost: String = ""
    private var serverPort: UInt16 = 0
    private var serverUsername: String?
    private var serverPassword: String?

    private var targetHost: String?
    private var targetPort: UInt16?
    private var targetCommand: UInt8?

    private var readData = Data()
    private var writeData = Data()

    private let socksVersion: UInt8 = 0x05
    private let authVersion: UInt8 = 0x01

    enum Socks5AuthMethod: UInt8 {
        case noAuth = 0x00
        case gssapi = 0x01
        case usernamePassword = 0x02
        case noAcceptable = 0xFF
    }

    enum Socks5Command: UInt8 {
        case connect = 0x01
        case bind = 0x02
        case udpAssociate = 0x03
    }

    enum Socks5AddressType: UInt8 {
        case ipv4 = 0x01
        case domain = 0x03
        case ipv6 = 0x04
    }

    enum Socks5Reply: UInt8 {
        case success = 0x00
        case serverFailure = 0x01
        case ruleFailure = 0x02
        case networkUnreachable = 0x03
        case hostUnreachable = 0x04
        case connectionRefused = 0x05
        case ttlExpired = 0x06
        case commandNotSupported = 0x07
        case addressNotSupported = 0x08
    }

    init(delegate: Socks5ConnectionDelegate?) {
        self.delegate = delegate
        super.init()
    }

    func connect(to server: ProxyServer, targetHost: String? = nil, targetPort: UInt16? = nil) {
        self.serverHost = server.host
        self.serverPort = UInt16(server.port)
        self.serverUsername = server.username
        self.serverPassword = server.password
        self.targetHost = targetHost ?? "0.0.0.0"
        self.targetPort = targetPort ?? 80
        self.targetCommand = Socks5Command.connect.rawValue

        socket = GCDAsyncSocket(delegate: self, delegateQueue: .main)
        socket?.setDelegateQueue(.main)
        socket?.timeout = 10

        do {
            try socket?.connect(toHost: server.host, onPort: UInt16(server.port), withTimeout: 10)
        } catch {
            delegate?.connectionDidFail(with: error)
        }
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
    }

    func isConnected() -> Bool {
        return socket?.isConnected ?? false
    }

    // MARK: - GCDAsyncSocketDelegate

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        startSocks5Handshake()
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        delegate?.connectionDidDisconnect(error: err)
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        readData.append(data)

        switch tag {
        case 0:
            handleGreetingResponse()
        case 1:
            handleAuthResponse()
        case 2:
            handleConnectionResponse()
        default:
            break
        }
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        // Data written successfully
    }

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        return -1 // Reject timeout
    }

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        return -1 // Reject timeout
    }

    // MARK: - SOCKS5 Protocol Implementation

    private func startSocks5Handshake() {
        // Step 1: Send greeting (version + auth methods)
        var greeting = Data()
        greeting.append(socksVersion)

        // Determine supported auth methods
        var methods = [Socks5AuthMethod.noAuth.rawValue]
        if serverUsername != nil && serverPassword != nil {
            methods.append(Socks5AuthMethod.usernamePassword.rawValue)
        }

        greeting.append(UInt8(methods.count))
        for method in methods {
            greeting.append(method)
        }

        socket?.write(greeting, withTimeout: 10, tag: 0)
        socket?.readData(withTimeout: 10, tag: 0)
    }

    private func handleGreetingResponse() {
        guard readData.count >= 2 else {
            delegate?.connectionDidFail(with: Socks5Error.invalidResponse)
            return
        }

        let version = readData[0]
        let method = readData[1]
        readData.removeAll()

        guard version == socksVersion else {
            delegate?.connectionDidFail(with: Socks5Error.invalidVersion)
            return
        }

        if method == Socks5AuthMethod.usernamePassword.rawValue {
            performUsernamePasswordAuth()
        } else if method == Socks5AuthMethod.noAuth.rawValue {
            sendConnectionRequest()
        } else if method == Socks5AuthMethod.noAcceptable.rawValue {
            delegate?.connectionDidFail(with: Socks5Error.noAcceptableMethod)
        } else {
            delegate?.connectionDidFail(with: Socks5Error.authenticationFailed)
        }
    }

    private func performUsernamePasswordAuth() {
        guard let username = serverUsername, let password = serverPassword else {
            delegate?.connectionDidFail(with: Socks5Error.missingCredentials)
            return
        }

        var authData = Data()
        authData.append(authVersion)
        authData.append(UInt8(username.utf8.count))
        authData.append(contentsOf: username.utf8)
        authData.append(UInt8(password.utf8.count))
        authData.append(contentsOf: password.utf8)

        socket?.write(authData, withTimeout: 10, tag: 1)
        socket?.readData(withTimeout: 10, tag: 1)
    }

    private func handleAuthResponse() {
        guard readData.count >= 2 else {
            delegate?.connectionDidFail(with: Socks5Error.invalidResponse)
            return
        }

        let version = readData[0]
        let status = readData[1]
        readData.removeAll()

        guard version == authVersion else {
            delegate?.connectionDidFail(with: Socks5Error.invalidVersion)
            return
        }

        if status == 0x00 {
            sendConnectionRequest()
        } else {
            delegate?.connectionDidFail(with: Socks5Error.authenticationFailed)
        }
    }

    private func sendConnectionRequest() {
        guard let targetHost = targetHost, let targetPort = targetPort else {
            delegate?.connectionDidFail(with: Socks5Error.invalidTarget)
            return
        }

        var request = Data()
        request.append(socksVersion)
        request.append(targetCommand ?? Socks5Command.connect.rawValue)
        request.append(0x00) // Reserved

        // Address - support domain, IPv4, IPv6
        if isIPv6Address(targetHost) {
            request.append(Socks5AddressType.ipv6.rawValue)
            if let ipv6Data = parseIPv6(targetHost) {
                request.append(ipv6Data)
            }
        } else if isIPv4Address(targetHost) {
            request.append(Socks5AddressType.ipv4.rawValue)
            let parts = targetHost.split(separator: ".").compactMap { UInt8($0) }
            if parts.count == 4 {
                request.append(contentsOf: parts)
            }
        } else {
            // Domain name
            request.append(Socks5AddressType.domain.rawValue)
            let hostData = targetHost.utf8
            request.append(UInt8(hostData.count))
            request.append(contentsOf: hostData)
        }

        // Port (big-endian)
        var port = targetPort.bigEndian
        request.append(contentsOf: withUnsafeBytes(of: &port) { Array($0) })

        socket?.write(request, withTimeout: 10, tag: 2)
        socket?.readData(withTimeout: 10, tag: 2)
    }

    private func handleConnectionResponse() {
        guard readData.count >= 10 else {
            delegate?.connectionDidFail(with: Socks5Error.invalidResponse)
            return
        }

        let version = readData[0]
        let reply = readData[1]
        readData.removeAll()

        guard version == socksVersion else {
            delegate?.connectionDidFail(with: Socks5Error.invalidVersion)
            return
        }

        if reply == Socks5Reply.success.rawValue {
            delegate?.connectionDidConnect()
        } else {
            let errorMessage = getReplyMessage(reply)
            delegate?.connectionDidFail(with: Socks5Error.connectionFailed(errorMessage))
        }
    }

    // MARK: - Helper Methods

    private func isIPv4Address(_ address: String) -> Bool {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return num >= 0 && num <= 255
        }
    }

    private func isIPv6Address(_ address: String) -> Bool {
        return address.contains(":")
    }

    private func parseIPv6(_ address: String) -> Data? {
        var addr = in6_addr()
        let result = address.withCString { ptr in
            inet_pton(AF_INET6, ptr, &addr)
        }
        guard result == 1 else { return nil }
        return withUnsafeBytes(of: addr.s6_addr) { Data($0) }
    }

    private func getReplyMessage(_ reply: UInt8) -> String {
        switch reply {
        case 0x01: return "SOCKS server failure"
        case 0x02: return "Connection not allowed by rule"
        case 0x03: return "Network unreachable"
        case 0x04: return "Host unreachable"
        case 0x05: return "Connection refused"
        case 0x06: return "TTL expired"
        case 0x07: return "Command not supported"
        case 0x08: return "Address type not supported"
        default: return "Unknown error"
        }
    }
}

enum Socks5Error: Error, LocalizedError {
    case invalidVersion
    case authenticationFailed
    case missingCredentials
    case invalidTarget
    case invalidResponse
    case noAcceptableMethod
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Invalid SOCKS5 version"
        case .authenticationFailed:
            return "Authentication failed"
        case .missingCredentials:
            return "Missing username or password"
        case .invalidTarget:
            return "Invalid target address"
        case .invalidResponse:
            return "Invalid server response"
        case .noAcceptableMethod:
            return "No acceptable authentication method"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        }
    }
}
