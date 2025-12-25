//
//  RokuConnector.swift
//  RemoteTVController
//

import Foundation

@MainActor class RokuConnector: BaseConnector {
    override var brand: TVBrand { .roku }
    
    private var connectedDevice: TVDevice?
    private let port: UInt16 = 8060
    
    override func connect(to device: TVDevice) async -> Bool {
        disconnect()
        connectedDevice = device
        
        state = .connecting("Connecting to Roku TV...")
        
        guard let url = URL(string: "http://\(device.ipAddress):\(port)/query/device-info") else {
            state = .failed("Invalid URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        state = .connecting("Checking device...")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                state = .connected
                return true
            } else {
                state = .failed("Device not responding")
                return false
            }
        } catch {
            state = .failed("Connection failed: \(error.localizedDescription)")
            return false
        }
    }
    
    override func sendCommand(_ button: RemoteButton) {
        guard let device = connectedDevice else { return }
        
        let rokuKey = rokuKeyCode(for: button)
        guard let url = URL(string: "http://\(device.ipAddress):\(port)/keypress/\(rokuKey)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func rokuKeyCode(for button: RemoteButton) -> String {
        switch button {
        case .power: return "Power"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .ok: return "Select"
        case .back: return "Back"
        case .home: return "Home"
        case .menu: return "Info"
        case .exit: return "Home"
        case .volumeUp: return "VolumeUp"
        case .volumeDown: return "VolumeDown"
        case .mute: return "VolumeMute"
        case .channelUp: return "ChannelUp"
        case .channelDown: return "ChannelDown"
        case .source: return "InputTuner"
        case .num0: return "Lit_0"
        case .num1: return "Lit_1"
        case .num2: return "Lit_2"
        case .num3: return "Lit_3"
        case .num4: return "Lit_4"
        case .num5: return "Lit_5"
        case .num6: return "Lit_6"
        case .num7: return "Lit_7"
        case .num8: return "Lit_8"
        case .num9: return "Lit_9"
        case .play: return "Play"
        case .pause: return "Pause"
        case .stop: return "Stop"
        case .rewind: return "Rev"
        case .fastForward: return "Fwd"
        }
    }
}

// MARK: - TCL Connector (использует Roku протокол)
@MainActor
final class TCLConnector: RokuConnector {
    override var brand: TVBrand { .tcl }
}

