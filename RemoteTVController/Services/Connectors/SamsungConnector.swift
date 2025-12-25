//
//  SamsungConnector.swift
//  RemoteTVController
//

import Foundation

@MainActor
final class SamsungConnector: BaseConnector {
    override var brand: TVBrand { .samsung }
    
    private var connectedDevice: TVDevice?
    
    override func connect(to device: TVDevice) async -> Bool {
        disconnect()
        connectedDevice = device
        
        state = .connecting("Preparing connection...")
        
        let appName = "SmartRemote"
        let encodedName = Data(appName.utf8).base64EncodedString()
        let urlString = "ws://\(device.ipAddress):8001/api/v2/channels/samsung.remote.control?name=\(encodedName)"
        
        guard let url = URL(string: urlString) else {
            state = .failed("Invalid URL")
            return false
        }
        
        state = .connecting("Connecting to Samsung TV...")
        
        return await withCheckedContinuation { continuation in
            let session = URLSession(configuration: .default)
            webSocket = session.webSocketTask(with: url)
            webSocket?.resume()
            
            Task {
                do {
                    state = .connecting("Waiting for TV response...")
                    let _ = try await receiveWebSocketMessage()
                    state = .connected
                    startPingTimer()
                    continuation.resume(returning: true)
                } catch {
                    state = .failed("Connection failed: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    override func sendCommand(_ button: RemoteButton) {
        let keyCode = samsungKeyCode(for: button)
        let message = """
        {"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_\(keyCode)","Option":"false","TypeOfRemote":"SendRemoteKey"}}
        """
        webSocket?.send(.string(message)) { _ in }
    }
    
    private func samsungKeyCode(for button: RemoteButton) -> String {
        switch button {
        case .power: return "POWER"
        case .up: return "UP"
        case .down: return "DOWN"
        case .left: return "LEFT"
        case .right: return "RIGHT"
        case .ok: return "ENTER"
        case .back: return "RETURN"
        case .home: return "HOME"
        case .menu: return "MENU"
        case .exit: return "EXIT"
        case .volumeUp: return "VOLUP"
        case .volumeDown: return "VOLDOWN"
        case .mute: return "MUTE"
        case .channelUp: return "CHUP"
        case .channelDown: return "CHDOWN"
        case .source: return "SOURCE"
        case .num0: return "0"
        case .num1: return "1"
        case .num2: return "2"
        case .num3: return "3"
        case .num4: return "4"
        case .num5: return "5"
        case .num6: return "6"
        case .num7: return "7"
        case .num8: return "8"
        case .num9: return "9"
        case .play: return "PLAY"
        case .pause: return "PAUSE"
        case .stop: return "STOP"
        case .rewind: return "REWIND"
        case .fastForward: return "FF"
        }
    }
}

