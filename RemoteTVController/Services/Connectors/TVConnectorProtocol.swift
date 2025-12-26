//
//  TVConnectorProtocol.swift
//  RemoteTVController
//

import Foundation
import Network
internal import Combine

// MARK: - Connection State
enum ConnectorState: Equatable {
    case idle
    case connecting(String)  
    case requestingPIN
    case waitingForPIN
    case verifyingPIN
    case connected
    case failed(String)
    
    var displayMessage: String {
        switch self {
        case .idle: return "Ready to connect"
        case .connecting(let step): return step
        case .requestingPIN: return "Requesting PIN from TV..."
        case .waitingForPIN: return "Enter the PIN shown on your TV"
        case .verifyingPIN: return "Verifying PIN..."
        case .connected: return "Connected"
        case .failed(let error): return error
        }
    }
    
    var isConnecting: Bool {
        switch self {
        case .connecting, .requestingPIN, .verifyingPIN:
            return true
        default:
            return false
        }
    }
}

// MARK: - TV Connector Protocol
@MainActor
protocol TVConnector: AnyObject {
    var brand: TVBrand { get }
    var state: ConnectorState { get set }
    var stateDidChange: ((ConnectorState) -> Void)? { get set }
    
    func connect(to device: TVDevice) async -> Bool
    func disconnect()
    func sendCommand(_ button: RemoteButton)
    
    // Для устройств требующих PIN
    func submitPIN(_ pin: String) async -> Bool
    func cancelPairing()
}

// MARK: - Base Connector
@MainActor
class BaseConnector: TVConnector {
    var brand: TVBrand { .unknown }
    var supportedPlatform: TVPlatform { .androidTV }
    var state: ConnectorState = .idle {
        didSet {
            stateDidChange?(state)
        }
    }
    
    var stateDidChange: ((ConnectorState) -> Void)?
    
    var webSocket: URLSessionWebSocketTask?
    var urlSession: URLSession?
    var pingTimer: Timer?
    
    func connect(to device: TVDevice) async -> Bool {
        state = .connected
        return true
    }
    
    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        pingTimer?.invalidate()
        pingTimer = nil
        state = .idle
    }
    
    func sendCommand(_ button: RemoteButton) {
        // Override in subclass
    }
    
    func submitPIN(_ pin: String) async -> Bool {
        return false
    }
    
    func cancelPairing() {
        state = .idle
    }
    
    // MARK: - Helpers
    
    func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.webSocket?.sendPing { error in
                    if error != nil {
                        Task { @MainActor in
                            self?.state = .failed("Connection lost")
                        }
                    }
                }
            }
        }
    }
    
    func receiveWebSocketMessage() async throws -> String {
        guard let webSocket = webSocket else {
            throw NSError(domain: "TVConnector", code: -1, userInfo: [NSLocalizedDescriptionKey: "No WebSocket connection"])
        }
        
        let message = try await webSocket.receive()
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(data: data, encoding: .utf8) ?? ""
        @unknown default:
            return ""
        }
    }
}

// MARK: - SSL Delegate for WebSocket
class SSLBypassDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, 
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

