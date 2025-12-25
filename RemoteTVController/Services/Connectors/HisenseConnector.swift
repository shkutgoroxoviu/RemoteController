//
//  HisenseConnector.swift
//  RemoteTVController
//

import Foundation
import Network

@MainActor
final class HisenseConnector: BaseConnector {
    override var brand: TVBrand { .hisense }

    private(set) var connectedDevice: TVDevice?
    private(set) var currentPendingDevice: TVDevice?
    private var pairingContinuation: CheckedContinuation<Bool, Never>?
    private var deviceId: String = ""
    private var tcpConnection: NWConnection?

    private let controlPort: UInt16 = 36669

    // MARK: - Connect / Pairing

    override func connect(to device: TVDevice) async -> Bool {
        disconnect()
        connectedDevice = device
        currentPendingDevice = device
        deviceId = UUID().uuidString

        state = .connecting("Connecting to Hisense TV...")

        let success = await connectViaTCP(device)
        guard success else { return false }

        await sendPairingRequest()

        state = .waitingForPIN
        return await withCheckedContinuation { continuation in
            pairingContinuation = continuation
        }
    }

    private func connectViaTCP(_ device: TVDevice) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let port = NWEndpoint.Port(rawValue: controlPort) else {
                continuation.resume(returning: false)
                return
            }

            let connection = NWConnection(host: NWEndpoint.Host(device.ipAddress), port: port, using: .tcp)
            tcpConnection = connection
            var hasResumed = false

            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("TCP connected to Hisense TV \(device.ipAddress)")
                    Task { @MainActor in
                        self?.startReceivingTCP(connection: connection)
                        if !hasResumed {
                            hasResumed = true
                            continuation.resume(returning: true)
                        }
                    }
                case .failed(let error):
                    print("TCP connection failed: \(error)")
                    connection.cancel()
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                case .cancelled:
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func sendPairingRequest() async {
        guard let connection = tcpConnection else { return }

        let pairingMessage: [String: String] = [
            "type": "request_pairing",
            "deviceId": deviceId,
            "deviceName": "SmartRemote"
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: pairingMessage) else { return }
        connection.send(content: data + ("\n".data(using: .utf8) ?? Data()), completion: .contentProcessed({ sendError in
            if let error = sendError {
                print("Failed to send pairing request: \(error)")
            } else {
                print("Pairing request sent to Hisense TV")
            }
        }))
    }

    private func startReceivingTCP(connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty, let message = String(data: data, encoding: .utf8) {
                print("Received TCP message: \(message)")
                self.handleTCPResponse(message)
            }

            if !isComplete && error == nil {
                self.startReceivingTCP(connection: connection)
            }
        }
    }

    private func handleTCPResponse(_ message: String) {
        let lower = message.lowercased()
        if lower.contains("pin") || lower.contains("pairing") {
            state = .waitingForPIN
        } else if lower.contains("success") || lower.contains("paired") {
            state = .connected
            connectedDevice = currentPendingDevice
            pairingContinuation?.resume(returning: true)
            pairingContinuation = nil
            currentPendingDevice = nil
        }
    }

    // MARK: - Submit PIN

    override func submitPIN(_ pin: String) async -> Bool {
        guard let device = currentPendingDevice ?? connectedDevice, let connection = tcpConnection else {
            state = .failed("No pending device")
            pairingContinuation?.resume(returning: false)
            pairingContinuation = nil
            return false
        }

        state = .verifyingPIN

        let verifyMessage: [String: String] = [
            "type": "pairingVerify",
            "deviceId": deviceId,
            "pin": pin
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: verifyMessage) else {
            pairingContinuation?.resume(returning: false)
            pairingContinuation = nil
            return false
        }

        connection.send(content: data + ("\n".data(using: .utf8) ?? Data()), completion: .contentProcessed({ sendError in
            if let error = sendError {
                print("Failed to send PIN: \(error)")
            } else {
                print("PIN sent to Hisense TV")
            }
        }))

        return true
    }

    // MARK: - Disconnect / Cancel

    override func disconnect() {
        super.disconnect()
        tcpConnection?.cancel()
        tcpConnection = nil
        currentPendingDevice = nil
        pairingContinuation?.resume(returning: false)
        pairingContinuation = nil
    }

    override func cancelPairing() {
        state = .idle
        currentPendingDevice = nil
        pairingContinuation?.resume(returning: false)
        pairingContinuation = nil
    }

    // MARK: - Управление телевизором

    func sendCommand(_ command: String) {
        guard let connection = tcpConnection, state == .connected else {
            print("TV is not connected")
            return
        }

        let commandMessage: [String: String] = [
            "type": "command",
            "action": command
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: commandMessage) else { return }
        connection.send(content: data + ("\n".data(using: .utf8) ?? Data()), completion: .contentProcessed({ sendError in
            if let error = sendError {
                print("Failed to send command: \(error)")
            } else {
                print("Command sent: \(command)")
            }
        }))
    }

    // Примеры команд
    func volumeUp() { sendCommand("volume_up") }
    func volumeDown() { sendCommand("volume_down") }
    func channelUp() { sendCommand("channel_up") }
    func channelDown() { sendCommand("channel_down") }
    func mute() { sendCommand("mute") }
    func launchApp(appId: String) { sendCommand("launch_\(appId)") }
}
