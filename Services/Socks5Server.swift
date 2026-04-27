import Foundation

protocol Socks5ServerDelegate: AnyObject {
    func socks5ServerDidStart(port: UInt16)
    func socks5ServerDidStop()
    func socks5ServerDidFail(error: String)
}

class Socks5Server: NSObject, GCDAsyncSocketDelegate {
    weak var delegate: Socks5ServerDelegate?

    private var listenSocket: GCDAsyncSocket?
    private var clientSockets: [GCDAsyncSocket] = []
    private var clientHandlers: [GCDAsyncSocket: ClientHandler] = [:]

    private let upstreamHost = "121.204.251.76"
    private let upstreamPort: UInt16 = 1080
    private let upstreamUsername = "cb"
    private let upstreamPassword = "cb"

    private(set) var listenPort: UInt16 = 0

    override init() {
        super.init()
    }

    func start(port: UInt16 = 0) {
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: .main)
        listenSocket?.isIPv6Enabled = false
        listenSocket?.isIPv4Enabled = true

        do {
            try listenSocket?.accept(onPort: port)
            listenPort = listenSocket?.localPort ?? 0
            delegate?.socks5ServerDidStart(port: listenPort)
        } catch {
            delegate?.socks5ServerDidFail(error: "启动失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        for handler in clientHandlers.values {
            handler.close()
        }
        clientHandlers.removeAll()

        for sock in clientSockets {
            sock.disconnect()
        }
        clientSockets.removeAll()

        listenSocket?.disconnect()
        listenSocket = nil

        delegate?.socks5ServerDidStop()
    }

    // MARK: - GCDAsyncSocketDelegate (listen socket)

    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let handler = ClientHandler(
            clientSocket: newSocket,
            server: self,
            upstreamHost: upstreamHost,
            upstreamPort: upstreamPort,
            upstreamUsername: upstreamUsername,
            upstreamPassword: upstreamPassword
        )
        clientHandlers[newSocket] = handler
        clientSockets.append(newSocket)
        handler.start()
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if sock === listenSocket {
            delegate?.socks5ServerDidStop()
        }
    }

    func removeHandler(for socket: GCDAsyncSocket) {
        clientSockets.removeAll { $0 === socket }
        clientHandlers.removeValue(forKey: socket)
    }
}

// MARK: - Client Connection Handler

class ClientHandler: NSObject, GCDAsyncSocketDelegate {
    let clientSocket: GCDAsyncSocket
    weak var server: Socks5Server?

    private let upstreamHost: String
    private let upstreamPort: UInt16
    private let upstreamUsername: String?
    private let upstreamPassword: String?

    private var upstreamSocket: GCDAsyncSocket?
    private var stage: HandlerStage = .greeting

    private enum HandlerStage {
        case greeting
        case auth
        case connectRequest
        case upstreamHandshake
        case upstreamAuth
        case upstreamConnect
        case relay
    }

    private var clientBuffer = Data()
    private var upstreamBuffer = Data()
    private var targetHost: String = ""
    private var targetPort: UInt16 = 0

    init(clientSocket: GCDAsyncSocket, server: Socks5Server,
         upstreamHost: String, upstreamPort: UInt16,
         upstreamUsername: String?, upstreamPassword: String?) {
        self.clientSocket = clientSocket
        self.server = server
        self.upstreamHost = upstreamHost
        self.upstreamPort = upstreamPort
        self.upstreamUsername = upstreamUsername
        self.upstreamPassword = upstreamPassword
        super.init()
    }

    func start() {
        clientSocket.delegate = self
        clientSocket.readData(withTimeout: 30, tag: 0)
    }

    func close() {
        upstreamSocket?.disconnect()
        upstreamSocket = nil
        clientSocket.disconnect()
    }

    // MARK: - GCDAsyncSocketDelegate

    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        if sock === upstreamSocket {
            startUpstreamHandshake()
        }
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if sock === upstreamSocket {
            upstreamSocket?.disconnect()
            upstreamSocket = nil
        }
        if sock === clientSocket {
            upstreamSocket?.disconnect()
            server?.removeHandler(for: clientSocket)
        }
    }

    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        if sock === clientSocket {
            clientBuffer.append(data)
            processClientBuffer()
        } else if sock === upstreamSocket {
            upstreamBuffer.append(data)
            processUpstreamBuffer()
        }
    }

    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {}

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutReadWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        return -1
    }

    func socket(_ sock: GCDAsyncSocket, shouldTimeoutWriteWithTag tag: Int, elapsed: TimeInterval, bytesDone length: UInt) -> TimeInterval {
        return -1
    }

    // MARK: - Client Protocol Processing

    private func processClientBuffer() {
        switch stage {
        case .greeting:
            processGreeting()
        case .auth:
            processAuth()
        case .connectRequest:
            processConnectRequest()
        case .relay:
            forwardToUpstream(clientBuffer)
            clientBuffer.removeAll()
        default:
            break
        }
    }

    private func processGreeting() {
        guard clientBuffer.count >= 2 else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        guard clientBuffer[0] == 0x05 else {
            sendClientError(reply: 0x01)
            return
        }

        let nMethods = Int(clientBuffer[1])
        guard clientBuffer.count >= 2 + nMethods else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        let methods = Array(clientBuffer[2..<(2 + nMethods)])
        clientBuffer.removeAll()

        let selected: UInt8 = methods.contains(0x02) ? 0x02 : (methods.contains(0x00) ? 0x00 : 0xFF)

        clientSocket.write(Data([0x05, selected]), withTimeout: 30, tag: 0)

        if selected == 0xFF {
            clientSocket.disconnect()
            return
        }

        stage = (selected == 0x02) ? .auth : .connectRequest
        clientSocket.readData(withTimeout: 30, tag: 0)
    }

    private func processAuth() {
        guard clientBuffer.count >= 2 else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        guard clientBuffer[0] == 0x01 else {
            sendClientError(reply: 0x01)
            return
        }

        let uLen = Int(clientBuffer[1])
        guard clientBuffer.count >= 2 + uLen + 1 else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        let pLen = Int(clientBuffer[2 + uLen])
        guard clientBuffer.count >= 2 + uLen + 1 + pLen else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        let username = String(data: clientBuffer[2..<(2+uLen)], encoding: .utf8) ?? ""
        let password = String(data: clientBuffer[(2+uLen+1)..<(2+uLen+1+pLen)], encoding: .utf8) ?? ""

        clientBuffer.removeAll()

        let ok = (username == upstreamUsername && password == upstreamPassword)
        clientSocket.write(Data([0x01, ok ? 0x00 : 0x01]), withTimeout: 30, tag: 0)

        if !ok {
            clientSocket.disconnect()
            return
        }

        stage = .connectRequest
        clientSocket.readData(withTimeout: 30, tag: 0)
    }

    private func processConnectRequest() {
        guard clientBuffer.count >= 10 else {
            clientSocket.readData(withTimeout: 30, tag: 0)
            return
        }

        guard clientBuffer[0] == 0x05 && clientBuffer[1] == 0x01 else {
            sendClientReply(reply: 0x07, bindHost: "0.0.0.0", bindPort: 0)
            return
        }

        let addrType = clientBuffer[3]

        switch addrType {
        case 0x01:
            guard clientBuffer.count >= 10 else { clientSocket.readData(withTimeout: 30, tag: 0); return }
            let ipBytes = clientBuffer[4..<8]
            targetHost = ipBytes.map { String($0) }.joined(separator: ".")
            let portBytes = clientBuffer[8..<10]
            targetPort = UInt16(portBytes[0]) << 8 | UInt16(portBytes[1])

        case 0x03:
            guard clientBuffer.count >= 5 else { clientSocket.readData(withTimeout: 30, tag: 0); return }
            let domainLen = Int(clientBuffer[4])
            guard clientBuffer.count >= 5 + domainLen + 2 else { clientSocket.readData(withTimeout: 30, tag: 0); return }
            let domainData = clientBuffer[5..<(5+domainLen)]
            targetHost = String(data: domainData, encoding: .utf8) ?? ""
            let portBytes = clientBuffer[(5+domainLen)..<(5+domainLen+2)]
            targetPort = UInt16(portBytes[0]) << 8 | UInt16(portBytes[1])

        case 0x04:
            sendClientReply(reply: 0x08, bindHost: "0.0.0.0", bindPort: 0)
            return

        default:
            sendClientReply(reply: 0x08, bindHost: "0.0.0.0", bindPort: 0)
            return
        }

        clientBuffer.removeAll()
        stage = .relay

        if ProxyRule.shouldProxyDomain(targetHost) {
            connectUpstream()
        } else {
            connectDirect()
        }
    }

    private func connectDirect() {
        let direct = GCDAsyncSocket(delegate: self, delegateQueue: .main)
        upstreamSocket = direct

        do {
            try direct.connect(toHost: targetHost, onPort: targetPort, withTimeout: 15)
        } catch {
            sendClientReply(reply: 0x04, bindHost: "0.0.0.0", bindPort: 0)
        }
    }

    private func connectUpstream() {
        let sock = GCDAsyncSocket(delegate: self, delegateQueue: .main)
        upstreamSocket = sock

        do {
            try sock.connect(toHost: upstreamHost, onPort: upstreamPort, withTimeout: 15)
        } catch {
            sendClientReply(reply: 0x03, bindHost: "0.0.0.0", bindPort: 0)
        }
    }

    // MARK: - Upstream SOCKS5 Handshake

    private func startUpstreamHandshake() {
        guard let upstream = upstreamSocket else { return }

        var greeting = Data([0x05])
        var methods: [UInt8] = [0x00]
        if let u = upstreamUsername, !u.isEmpty {
            methods.append(0x02)
        }
        greeting.append(UInt8(methods.count))
        greeting.append(contentsOf: methods)

        stage = .upstreamHandshake
        upstream.write(greeting, withTimeout: 10, tag: 0)
        upstream.readData(withTimeout: 10, tag: 0)
    }

    private func processUpstreamBuffer() {
        switch stage {
        case .upstreamHandshake:
            processUpstreamGreetingResponse()
        case .upstreamAuth:
            processUpstreamAuthResponse()
        case .upstreamConnect:
            processUpstreamConnectResponse()
        case .relay:
            forwardToClient(upstreamBuffer)
            upstreamBuffer.removeAll()
        default:
            break
        }
    }

    private func processUpstreamGreetingResponse() {
        guard upstreamBuffer.count >= 2 else {
            upstreamSocket?.readData(withTimeout: 10, tag: 0)
            return
        }

        guard upstreamBuffer[0] == 0x05 else {
            sendClientReply(reply: 0x01, bindHost: "0.0.0.0", bindPort: 0)
            return
        }

        let method = upstreamBuffer[1]
        upstreamBuffer.removeAll()

        if method == 0x02 {
            sendUpstreamAuth()
        } else if method == 0x00 {
            sendUpstreamConnect()
        } else {
            sendClientReply(reply: 0x01, bindHost: "0.0.0.0", bindPort: 0)
        }
    }

    private func sendUpstreamAuth() {
        guard let upstream = upstreamSocket,
              let u = upstreamUsername,
              let p = upstreamPassword else { return }

        var authData = Data([0x01])
        authData.append(UInt8(u.utf8.count))
        authData.append(contentsOf: u.utf8)
        authData.append(UInt8(p.utf8.count))
        authData.append(contentsOf: p.utf8)

        stage = .upstreamAuth
        upstream.write(authData, withTimeout: 10, tag: 0)
        upstream.readData(withTimeout: 10, tag: 0)
    }

    private func processUpstreamAuthResponse() {
        guard upstreamBuffer.count >= 2 else {
            upstreamSocket?.readData(withTimeout: 10, tag: 0)
            return
        }

        upstreamBuffer.removeAll()
        sendUpstreamConnect()
    }

    private func sendUpstreamConnect() {
        guard let upstream = upstreamSocket else { return }

        var req = Data([0x05, 0x01, 0x00])

        if targetHost.contains(":") {
            req.append(0x04)
            var addr = in6_addr()
            _ = targetHost.withCString { inet_pton(AF_INET6, $0, &addr) }
            req.append(contentsOf: withUnsafeBytes(of: addr.s6_addr) { Array($0) })
        } else if targetHost.split(separator: ".").count == 4,
                  targetHost.split(separator: ".").allSatisfy({ Int($0) != nil }) {
            req.append(0x01)
            req.append(contentsOf: targetHost.split(separator: ".").compactMap { UInt8($0) })
        } else {
            req.append(0x03)
            req.append(UInt8(targetHost.utf8.count))
            req.append(contentsOf: targetHost.utf8)
        }

        var portBE = targetPort.bigEndian
        req.append(contentsOf: withUnsafeBytes(of: &portBE) { Array($0) })

        stage = .upstreamConnect
        upstream.write(req, withTimeout: 15, tag: 0)
        upstream.readData(withTimeout: 15, tag: 0)
    }

    private func processUpstreamConnectResponse() {
        guard upstreamBuffer.count >= 2 else {
            upstreamSocket?.readData(withTimeout: 15, tag: 0)
            return
        }

        let reply = upstreamBuffer[1]
        upstreamBuffer.removeAll()

        if reply == 0x00 {
            sendClientReply(reply: 0x00, bindHost: "0.0.0.0", bindPort: 0)
            startRelay()
        } else {
            sendClientReply(reply: 0x01, bindHost: "0.0.0.0", bindPort: 0)
        }
    }

    // MARK: - Relay

    private func startRelay() {
        stage = .relay
        clientSocket.readData(withTimeout: 0, tag: 0)
        upstreamSocket?.readData(withTimeout: 0, tag: 0)
    }

    private func forwardToUpstream(_ data: Data) {
        guard !data.isEmpty else { return }
        upstreamSocket?.write(data, withTimeout: 0, tag: 0)
    }

    private func forwardToClient(_ data: Data) {
        guard !data.isEmpty else { return }
        clientSocket.write(data, withTimeout: 0, tag: 0)
    }

    // MARK: - Client Reply

    private func sendClientReply(reply: UInt8, bindHost: String, bindPort: UInt16) {
        var resp = Data([0x05, reply, 0x00, 0x01])
        resp.append(contentsOf: [0, 0, 0, 0])
        var portBE = bindPort.bigEndian
        resp.append(contentsOf: withUnsafeBytes(of: &portBE) { Array($0) })

        clientSocket.write(resp, withTimeout: 30, tag: 0)

        if reply == 0x00 {
            startRelay()
        } else {
            clientSocket.disconnect()
        }
    }

    private func sendClientError(reply: UInt8) {
        var resp = Data([0x05, reply, 0x00])
        resp.append(contentsOf: [0x01, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        clientSocket.write(resp, withTimeout: 30, tag: 0)
        clientSocket.disconnect()
    }
}
