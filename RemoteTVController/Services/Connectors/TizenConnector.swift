//
//  TizenConnector.swift
//  RemoteTVController


import Foundation

@MainActor
final class TizenConnector: BaseConnector {
    override var brand: TVBrand { .samsung }
    override var supportedPlatform: TVPlatform { .tizen }

    // MARK: - Private Properties
    private var connectedDevice: TVDevice?
    private var receivedToken: String?
    private var isWaitingForUserApproval = false
    private var connectionContinuation: CheckedContinuation<Bool, Never>?

    private let securePort: UInt16 = 8002
    private let insecurePort: UInt16 = 8001
    private let appName = "SmartRemote"

    // MARK: - Connect

    override func connect(to device: TVDevice) async -> Bool {
        disconnect()
        connectedDevice = device
        receivedToken = device.authToken

        state = .connecting("Подготовка подключения...")

        if await connectSecure(to: device) {
            return true
        }

        state = .connecting("Пробуем альтернативное подключение...")
        return await connectInsecure(to: device)
    }

    // MARK: - Secure/Insecure Connection

    private func connectSecure(to device: TVDevice) async -> Bool {
        await connect(to: device, secure: true)
    }

    private func connectInsecure(to device: TVDevice) async -> Bool {
        await connect(to: device, secure: false)
    }

    private func connect(to device: TVDevice, secure: Bool) async -> Bool {
        let encodedName = Data(appName.utf8).base64EncodedString()
        let port = secure ? securePort : insecurePort
        var urlString = "\(secure ? "wss" : "ws")://\(device.ipAddress):\(port)/api/v2/channels/samsung.remote.control?name=\(encodedName)"
        if let token = device.authToken, !token.isEmpty {
            urlString += "&token=\(token)"
        }
        guard let url = URL(string: urlString) else {
            state = .failed("Неверный URL адрес")
            return false
        }

        state = .connecting("Подключение к Samsung TV (\(secure ? "WSS" : "WS"))...")

        return await withCheckedContinuation { continuation in
            self.connectionContinuation = continuation

            let session: URLSession
            if secure {
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 10
                config.timeoutIntervalForResource = 30
                session = URLSession(configuration: config, delegate: SSLBypassDelegate(), delegateQueue: nil)
            } else {
                session = .shared
            }

            webSocket = session.webSocketTask(with: url)
            webSocket?.resume()

            Task { await self.handleConnectionLoop() }
        }
    }

    // MARK: - Connection Loop

    private func handleConnectionLoop() async {
        while let ws = webSocket {
            do {
                let message = try await receiveWebSocketMessage()
                guard let data = message.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                await processConnectionMessage(json)
            } catch {
                if state == .connected {
                    state = .failed("Соединение потеряно")
                }
                finishConnection(success: false)
                break
            }
        }
    }

    private func processConnectionMessage(_ json: [String: Any]) async {
        let event = json["event"] as? String ?? ""
        let data = json["data"] as? [String: Any]

        switch event {
        case "ms.channel.connect":
            if let token = data?["token"] as? String, !token.isEmpty {
                receivedToken = token
                await saveTokenForDevice(token)
            }
            state = .connected
            startPingTimer()
            startReceivingMessages()
            finishConnection(success: true)

        case "ms.channel.authRequired", "ms.channel.clientConnect":
            isWaitingForUserApproval = true
            state = .connecting("Подтвердите подключение на вашем TV...")
            await waitForUserApprovalLoop()

        case "ms.channel.unauthorized":
            state = .failed("Подключение отклонено. Попробуйте снова.")
            finishConnection(success: false)

        case "ms.error":
            let errorMessage = data?["message"] as? String ?? "Неизвестная ошибка"
            state = .failed(errorMessage)
            finishConnection(success: false)

        default:
            if json["id"] != nil {
                state = .connected
                startPingTimer()
                startReceivingMessages()
                finishConnection(success: true)
            }
        }
    }

    private func waitForUserApprovalLoop() async {
        while isWaitingForUserApproval {
            do {
                let response = try await receiveWebSocketMessage()
                guard let data = response.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                await processConnectionMessage(json)
            } catch {
                state = .failed("Время ожидания истекло")
                finishConnection(success: false)
                break
            }
        }
    }

    // MARK: - Finish Connection

    private func finishConnection(success: Bool) {
        isWaitingForUserApproval = false
        if let continuation = connectionContinuation {
            continuation.resume(returning: success)
            connectionContinuation = nil
        }
    }

    private func saveTokenForDevice(_ token: String) async {
        guard var device = connectedDevice else { return }
        device.authToken = token
        connectedDevice = device
        TVConnectionManager.shared.updateDevice(device)
    }
    
    // MARK: - Message Receiving
    
    private func startReceivingMessages() {
        Task {
            while webSocket != nil && state == .connected {
                do {
                    let message = try await receiveWebSocketMessage()
                    handleIncomingMessage(message)
                } catch {
                    if state == .connected {
                        state = .failed("Соединение потеряно")
                    }
                    break
                }
            }
        }
    }
    
    private func handleIncomingMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        let event = json["event"] as? String ?? ""
        
        switch event {
        case "ms.channel.disconnect":
            disconnect()
        case "ms.error":
            if let errorData = json["data"] as? [String: Any],
               let errorMessage = errorData["message"] as? String {
                print("Samsung TV Error: \(errorMessage)")
            }
        default:
            break
        }
    }
    
    // MARK: - Commands
    
    override func sendCommand(_ button: RemoteButton) {
        guard state == .connected, webSocket != nil else { return }
        
        let keyCode = samsungKeyCode(for: button)
        let command: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": "KEY_\(keyCode)",
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: command),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { [weak self] error in
                if let error = error {
                    print("Send command error: \(error)")
                    Task { @MainActor in
                        self?.state = .failed("Ошибка отправки команды")
                    }
                }
            }
        }
    }
    
    func sendLongPress(_ button: RemoteButton) {
        guard state == .connected, webSocket != nil else { return }
        
        let keyCode = samsungKeyCode(for: button)
        
        sendKeyEvent(keyCode: keyCode, command: "Press")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendKeyEvent(keyCode: keyCode, command: "Release")
        }
    }
    
    private func sendKeyEvent(keyCode: String, command: String) {
        let cmd: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": command,
                "DataOfCmd": "KEY_\(keyCode)",
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: cmd),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { _ in }
        }
    }
    
    // MARK: - Key Codes
    
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
    
    // MARK: - Additional Samsung Keys (для будущего расширения)
    
    enum SamsungExtraKey: String {
        case red = "RED"
        case green = "GREEN"
        case yellow = "YELLOW"
        case blue = "BLUE"
        
        case record = "REC"
        case previous = "REWIND_"
        case next = "FF_"
        
        case smartHub = "SMART"
        case guide = "GUIDE"
        case info = "INFO"
        case tools = "TOOLS"
        
        case sleep = "SLEEP"
        case pictureSize = "PICTURE_SIZE"
        case caption = "CAPTION"
        case ambient = "AMBIENT"
        
        case keypad = "MORE"
        case search = "SEARCH"
    }
    
    func sendExtraCommand(_ key: SamsungExtraKey) {
        guard state == .connected, webSocket != nil else { return }
        
        let command: [String: Any] = [
            "method": "ms.remote.control",
            "params": [
                "Cmd": "Click",
                "DataOfCmd": "KEY_\(key.rawValue)",
                "Option": "false",
                "TypeOfRemote": "SendRemoteKey"
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: command),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { _ in }
        }
    }
    
    // MARK: - App Launch
    
    func launchApp(appId: String, metaTag: String? = nil) {
        guard state == .connected, webSocket != nil else { return }
        
        var params: [String: Any] = ["id": appId]
        if let meta = metaTag {
            params["metaTag"] = meta
        }
        
        let command: [String: Any] = [
            "method": "ms.channel.emit",
            "params": [
                "event": "ed.apps.launch",
                "to": "host",
                "data": params
            ]
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: command),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            webSocket?.send(.string(jsonString)) { _ in }
        }
    }
    
    enum SamsungAppId: String {
        case netflix = "3201907018807"
        case youtube = "111299001912"
        case primeVideo = "3201910019365"
        case appleTVPlus = "3201807016597"
        case disneyPlus = "3201901017640"
        case spotify = "3201606009684"
        case browser = "org.tizen.browser"
    }
    
    // MARK: - Disconnect
    
    override func disconnect() {
        connectionContinuation?.resume(returning: false)
        connectionContinuation = nil
        isWaitingForUserApproval = false
        super.disconnect()
    }
    
    // MARK: - Device Info
    
    func fetchDeviceInfo() async -> [String: Any]? {
        guard let device = connectedDevice else { return nil }
        
        let urls = [
            "http://\(device.ipAddress):8001/api/v2/",
            "https://\(device.ipAddress):8002/api/v2/"
        ]
        
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    return json
                }
            } catch {
                continue
            }
        }
        
        return nil
    }
}

