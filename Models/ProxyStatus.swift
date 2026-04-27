import Foundation
import Combine

enum ProxyStatus: Equatable {
    case disconnected
    case connecting
    case connected(localPort: UInt16)
    case error(String)
}
