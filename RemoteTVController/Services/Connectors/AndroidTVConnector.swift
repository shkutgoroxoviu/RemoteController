//
//  AndroidTVConnector.swift
//  RemoteTVController
//

import SwiftUI
import Network

@MainActor
final class AndroidTVConnector: BaseConnector {

    override var brand: TVBrand { .tcl }

    private let adbClient = ADBTCPClient.shared
    private var device: TVDevice?

    override func connect(to device: TVDevice) async -> Bool {
        self.device = device
        state = .connecting("Connecting to Android TV...")

        do {
            let success = try await adbClient.connect(to: device.ipAddress, port: device.platform.defaultPort)
            state = success ? .connected : .failed("Failed to connect via ADB TCP")
            return success
        } catch {
            state = .failed(error.localizedDescription)
            return false
        }
    }

    override func sendCommand(_ button: RemoteButton) {
        guard let keycode = androidKeyCode(for: button) else { return }
        Task {
            await adbClient.sendKeyEvent(keycode)
        }
    }

    override func disconnect() {
        Task {
            await adbClient.disconnect()
            state = .idle
        }
    }

    private func androidKeyCode(for button: RemoteButton) -> Int? {
        let map: [RemoteButton: Int] = [
            .power: 26, .up: 19, .down: 20, .left: 21, .right: 22, .ok: 23,
            .back: 4, .home: 3, .menu: 82,
            .volumeUp: 24, .volumeDown: 25, .mute: 164,
            .play: 126, .pause: 127, .stop: 86,
            .rewind: 89, .fastForward: 90
        ]
        return map[button]
    }
}

actor ADBTCPClient {
    static let shared = ADBTCPClient()
    private var connection: NWConnection?
    private var connected = false
    func setConnected(_ value: Bool) { connected = value }

    private init() {}

    func connect(to ip: String, port: UInt16 = 5555) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            let nwPort = NWEndpoint.Port(rawValue: port)!
            connection = NWConnection(host: host, port: nwPort, using: .tcp)

            guard let connection = connection else {
                continuation.resume(throwing: NSError(domain: "ADBTCPClient", code: -1, userInfo: nil))
                return
            }

            var didResume = false
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    Task { [weak self] in
                        await self?.setConnected(true)
                        if !didResume {
                            didResume = true
                            continuation.resume(returning: true)
                        }
                        print("✅ Connected to \(ip):\(port)")
                    }
                case .failed(let error):
                    Task { [weak self] in
                        await self?.setConnected(false)
                        if !didResume {
                            didResume = true
                            continuation.resume(returning: true)
                        }
                        print("❌ Connection failed: \(error)")
                    }
                case .cancelled:
                    Task { [weak self] in
                        await self?.setConnected(false)
                        if !didResume {
                            didResume = true
                            continuation.resume(throwing: NSError(domain: "ADBTCPClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Connection cancelled"]))
                        }
                        print("🔌 Disconnected")
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())
        }
    }

    func sendKeyEvent(_ keycode: Int) async {
        guard connected, let connection else { return }
        let command = "input keyevent \(keycode)\n"
        if let data = command.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Failed to send keyevent: \(error)")
                } else {
                    print("📤 Sent keyevent: \(keycode)")
                }
            })
        }
    }

    func disconnect() async {
        connection?.cancel()
        connection = nil
        connected = false
        print("🔌 Disconnected")
    }
}

final class MockTVServer {
    private var listener: NWListener?

    func start(port: UInt16 = 5555) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("❌ Failed to start MockTVServer: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            print("✅ Mock TV got a new connection")
            connection.start(queue: .main)
            self?.handle(connection: connection)
        }

        listener?.start(queue: .main)
        print("📡 Mock TV server listening on port \(port)")
    }

    private func handle(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, isComplete, error in
            if let data = data, let cmd = String(data: data, encoding: .utf8) {
                print("📥 Mock TV received command: \(cmd.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            if error != nil || isComplete {
                print("🔌 Connection closed by client")
                return
            }
            // Продолжаем слушать
            self?.handle(connection: connection)
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("🔌 Mock TV server stopped")
    }
}
