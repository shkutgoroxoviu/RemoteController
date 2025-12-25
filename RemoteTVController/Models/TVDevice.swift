//
//  TVDevice.swift
//  RemoteTVController
//

import Foundation

enum TVPlatform: String, Codable, CaseIterable {
    case tizen        // Samsung
    case webOS        // LG
    case androidTV    // Sony, Philips, TCL, Hisense
    case roku         // Roku, TCL, Hisense
    case vidaa        // Hisense
    case unknown
}


struct TVDevice: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ipAddress: String
    var brand: TVBrand
    var platform: TVPlatform
    var model: String?
    var lastConnected: Date?
    var authToken: String?

    init(
        id: UUID = UUID(),
        name: String,
        ipAddress: String,
        brand: TVBrand = .unknown,
        platform: TVPlatform = .unknown,
        model: String? = nil,
        lastConnected: Date? = nil,
        authToken: String? = nil
    ) {
        self.id = id
        self.name = name
        self.ipAddress = ipAddress
        self.brand = brand
        self.platform = platform
        self.model = model
        self.lastConnected = lastConnected
        self.authToken = authToken
    }

    static func == (lhs: TVDevice, rhs: TVDevice) -> Bool {
        lhs.id == rhs.id
    }
}


enum TVBrand: String, Codable, CaseIterable {
    case samsung = "Samsung"
    case lg = "LG"
    case sony = "Sony"
    case philips = "Philips"
    case panasonic = "Panasonic"
    case hisense = "Hisense"
    case tcl = "TCL"
    case xiaomi = "Xiaomi"
    case sharp = "Sharp"
    case nokia = "Nokia"
    case thomson = "Thomson"
    case jvc = "JVC"
    case skyworth = "Skyworth"
    case haier = "Haier"
    case vestel = "Vestel"
    case roku = "Roku"
    case unknown = "Smart TV"

    var displayName: String { rawValue }
}

// MARK: - Connection Status
enum ConnectionStatus: Equatable {
    case disconnected
    case searching
    case connecting
    case awaitingConfirmation
    case awaitingPIN
    case connected
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected: return "Not connected"
        case .searching: return "Searching for TVs..."
        case .connecting: return "Connecting..."
        case .awaitingConfirmation: return "Please confirm on your TV"
        case .awaitingPIN: return "Enter the PIN shown on your TV"
        case .connected: return "Connected"
        case .error(let message): return message
        }
    }
    
    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
    
    var isAwaitingPIN: Bool {
        if case .awaitingPIN = self { return true }
        return false
    }
}

// MARK: - Remote Button
enum RemoteButton: String, CaseIterable {
    case power = "POWER"
    case up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT", ok = "ENTER"
    case back = "RETURN", home = "HOME", menu = "MENU", exit = "EXIT"
    case volumeUp = "VOLUP", volumeDown = "VOLDOWN", mute = "MUTE"
    case channelUp = "CHUP", channelDown = "CHDOWN"
    case source = "SOURCE"
    case num0 = "0", num1 = "1", num2 = "2", num3 = "3", num4 = "4"
    case num5 = "5", num6 = "6", num7 = "7", num8 = "8", num9 = "9"
    case play = "PLAY", pause = "PAUSE", stop = "STOP", rewind = "REWIND", fastForward = "FF"
    
    var sfSymbol: String {
        switch self {
        case .power: return "power"
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .left: return "chevron.left"
        case .right: return "chevron.right"
        case .ok: return "circle"
        case .back: return "arrow.uturn.backward"
        case .home: return "house"
        case .menu: return "line.3.horizontal"
        case .exit: return "xmark"
        case .volumeUp: return "speaker.plus"
        case .volumeDown: return "speaker.minus"
        case .mute: return "speaker.slash"
        case .channelUp, .channelDown: return "chevron.up"
        case .source: return "rectangle.on.rectangle"
        case .num0, .num1, .num2, .num3, .num4, .num5, .num6, .num7, .num8, .num9:
            return "\(rawValue).circle"
        case .play: return "play"
        case .pause: return "pause"
        case .stop: return "stop"
        case .rewind: return "backward"
        case .fastForward: return "forward"
        }
    }
    
    var isPremium: Bool {
        switch self {
        case .num0, .num1, .num2, .num3, .num4, .num5, .num6, .num7, .num8, .num9,
             .play, .pause, .stop, .rewind, .fastForward:
            return true
        default:
            return false
        }
    }
}

struct DiscoveredDevice: Identifiable {
    let id = UUID()
    let name: String
    let ipAddress: String
    let brand: TVBrand
    let platform: TVPlatform
    let model: String?
    let usn: String?

    func toTVDevice() -> TVDevice {
        TVDevice(
            name: name,
            ipAddress: ipAddress,
            brand: brand,
            platform: platform,
            model: model
        )
    }
}

extension TVPlatform {

    var defaultPort: UInt16 {
        switch self {
        case .tizen:
            return 8002        // Samsung WebSocket
        case .webOS:
            return 3000        // LG WebSocket
        case .roku:
            return 8060        // Roku ECP
        case .androidTV:
            return 5555        // ADB (backend only)
        case .vidaa:
            return 8883        // MQTT TLS (обычно)
        case .unknown:
            return 0
        }
    }
}

extension DiscoveredDevice {
    func correctedTVDevice() -> TVDevice {
        var detectedBrand = brand
        var detectedPlatform = platform

        let lowercasedName = name.lowercased()

        if lowercasedName.contains("samsung") {
            detectedBrand = .samsung
            detectedPlatform = .tizen
        } else if lowercasedName.contains("lg") {
            detectedBrand = .lg
            detectedPlatform = .webOS
        } else if lowercasedName.contains("roku") {
            detectedBrand = .roku
            detectedPlatform = .roku
        } else if lowercasedName.contains("hisense") {
            detectedBrand = .hisense
            detectedPlatform = .vidaa
        }

        return TVDevice(
            name: name,
            ipAddress: ipAddress,
            brand: detectedBrand,
            platform: detectedPlatform,
            model: model
        )
    }
}
