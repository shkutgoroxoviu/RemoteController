//
//  LGConnector.swift
//  RemoteTVController
//

import Foundation

@MainActor
final class LGConnector: BaseConnector {
    override var brand: TVBrand { .lg }
    
    private var connectedDevice: TVDevice?
    
    override func connect(to device: TVDevice) async -> Bool {
        disconnect()
        connectedDevice = device
        
        state = .connecting("Preparing secure connection...")
        
        let urlString = "wss://\(device.ipAddress):3001/"
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid URL")
            return false
        }
        
        state = .connecting("Connecting to LG TV...")
        
        return await withCheckedContinuation { continuation in
            let config = URLSessionConfiguration.default
            let delegate = SSLBypassDelegate()
            urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            webSocket = urlSession?.webSocketTask(with: url)
            webSocket?.resume()
            
            state = .connecting("Sending registration...")
            
            let registration = """
            {"type":"register","payload":{"client-key":"\(device.authToken ?? "")","forcePairing":false,"manifest":{"appVersion":"1.0.0","permissions":["CONTROL_POWER","CONTROL_INPUT_MEDIA_PLAYBACK","CONTROL_AUDIO"]}}}
            """
            
            webSocket?.send(.string(registration)) { [weak self] error in
                if error != nil {
                    Task { @MainActor in
                        self?.state = .failed("Failed to send registration")
                        continuation.resume(returning: false)
                    }
                    return
                }
                
                Task { @MainActor in
                    self?.state = .connecting("Waiting for TV confirmation...")
                    
                    do {
                        let response = try await self?.receiveWebSocketMessage() ?? ""
                        if response.contains("registered") {
                            self?.state = .connected
                            self?.startPingTimer()
                            continuation.resume(returning: true)
                        } else if response.contains("promptForPIN") || response.contains("pairing") {
                            self?.state = .waitingForPIN
                            continuation.resume(returning: false)
                        } else {
                            self?.state = .failed("Connection rejected")
                            continuation.resume(returning: false)
                        }
                    } catch {
                        self?.state = .failed("Connection failed")
                        continuation.resume(returning: false)
                    }
                }
            }
        }
    }
    
    override func sendCommand(_ button: RemoteButton) {
        let uri = lgCommandURI(for: button)
        let message = "{\"type\":\"request\",\"uri\":\"\(uri)\",\"payload\":{}}"
        webSocket?.send(.string(message)) { _ in }
    }
    
    private func lgCommandURI(for button: RemoteButton) -> String {
        switch button {
        case .power: return "ssap://system/turnOff"
        case .volumeUp: return "ssap://audio/volumeUp"
        case .volumeDown: return "ssap://audio/volumeDown"
        case .mute: return "ssap://audio/setMute"
        case .channelUp: return "ssap://tv/channelUp"
        case .channelDown: return "ssap://tv/channelDown"
        case .home: return "ssap://system.launcher/launch"
        case .up: return "ssap://com.webos.service.ime/sendEnterKey"
        case .down: return "ssap://com.webos.service.ime/sendEnterKey"
        case .left: return "ssap://com.webos.service.ime/sendEnterKey"
        case .right: return "ssap://com.webos.service.ime/sendEnterKey"
        case .ok: return "ssap://com.webos.service.ime/sendEnterKey"
        default: return "ssap://com.webos.service.ime/sendEnterKey"
        }
    }
}

