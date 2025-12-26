//
//  TVConnectionManager.swift
//  RemoteTVController
//

import Foundation
internal import Combine

@MainActor
final class TVConnectionManager: ObservableObject {

    static let shared = TVConnectionManager()

    // MARK: - Published Properties
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var connectorState: ConnectorState = .idle
    @Published private(set) var connectedDevice: TVDevice?
    @Published private(set) var savedDevices: [TVDevice] = []

    // MARK: - Private Properties
    private var activeConnector: TVConnector?
    private let maxFreeDevices = 1

    // MARK: - Platform-based connectors
    private lazy var androidTVConnector = AndroidTVConnector()
    private lazy var webOSConnector = LGConnector()
    private lazy var rokuConnector = RokuConnector()
    private lazy var vidaaConnector = HisenseConnector()
    private lazy var tizenConnector = TizenConnector()
    private lazy var unknownConnector = BaseConnector()

    // MARK: - Init
    private init() {
        loadSavedDevices()
        setupConnectorCallbacks()
    }

    // MARK: - Connector State Handling
    private func setupConnectorCallbacks() {
        let connectors: [TVConnector] = [
            androidTVConnector,
            webOSConnector,
            rokuConnector,
            vidaaConnector,
            tizenConnector,
            unknownConnector
        ]

        connectors.forEach { connector in
            connector.stateDidChange = { [weak self] state in
                Task { @MainActor in
                    self?.handleConnectorStateChange(state)
                }
            }
        }
    }

    private func handleConnectorStateChange(_ state: ConnectorState) {
        connectorState = state

        switch state {
        case .idle:
            connectionStatus = .disconnected
        case .connecting:
            connectionStatus = .connecting
        case .requestingPIN, .waitingForPIN:
            connectionStatus = .awaitingPIN
        case .verifyingPIN:
            connectionStatus = .connecting
        case .connected:
            connectionStatus = .connected
        case .failed(let error):
            connectionStatus = .error(error)
        }
    }

    // MARK: - Device Management
    var canAddMoreDevices: Bool {
        SubscriptionManager.shared.isSubscribed || savedDevices.count < maxFreeDevices
    }

    func addDevice(_ device: TVDevice) -> Bool {
        guard canAddMoreDevices else { return false }

        var updatedDevice = device
        updatedDevice.lastConnected = Date()

        if let index = savedDevices.firstIndex(where: { $0.id == device.id }) {
            savedDevices[index] = updatedDevice
        } else {
            savedDevices.append(updatedDevice)
        }

        saveDevices()
        return true
    }

    func removeDevice(_ device: TVDevice) {
        savedDevices.removeAll { $0.id == device.id }
        saveDevices()

        if connectedDevice?.id == device.id {
            disconnect()
        }
    }

    func updateDevice(_ device: TVDevice) {
        guard let index = savedDevices.firstIndex(where: { $0.id == device.id }) else { return }
        savedDevices[index] = device
        saveDevices()
    }

    private func loadSavedDevices() {
        guard
            let data = UserDefaults.standard.data(forKey: "saved_devices"),
            let devices = try? JSONDecoder().decode([TVDevice].self, from: data)
        else { return }

        savedDevices = devices
    }

    private func saveDevices() {
        guard let data = try? JSONEncoder().encode(savedDevices) else { return }
        UserDefaults.standard.set(data, forKey: "saved_devices")
    }

    // MARK: - Connection
    func connect(to device: TVDevice) async -> Bool {
        disconnect()

        activeConnector = connector(for: device.platform)
        let success = await activeConnector?.connect(to: device) ?? false

        if success {
            connectedDevice = device
            _ = addDevice(device)

            AnalyticsService.shared.trackEvent(
                .deviceConnected,
                properties: [
                    "brand": device.brand.rawValue,
                    "platform": device.platform.rawValue
                ]
            )
        } else {
            AnalyticsService.shared.trackEvent(
                .deviceConnectionFailed,
                properties: [
                    "brand": device.brand.rawValue,
                    "platform": device.platform.rawValue
                ]
            )
        }

        return success
    }

    func disconnect() {
        activeConnector?.disconnect()
        activeConnector = nil
        connectionStatus = .disconnected
        connectorState = .idle
        connectedDevice = nil
    }

    private func connector(for platform: TVPlatform) -> TVConnector {
        switch platform {
        case .androidTV:
            return androidTVConnector
        case .webOS:
            return webOSConnector
        case .roku:
            return rokuConnector
        case .vidaa:
            return vidaaConnector
        case .tizen:
            return tizenConnector
        default:
            return unknownConnector
        }
    }

    // MARK: - Commands
    func sendCommand(_ button: RemoteButton) {
        guard connectionStatus.isConnected else { return }
        activeConnector?.sendCommand(button)

        AnalyticsService.shared.trackEvent(
            .remoteButtonPressed,
            properties: ["button": button.rawValue]
        )
    }

    // MARK: - PIN Handling (VIDAA / Hisense)
    func submitVIDAAPIN(_ pin: String) {
        Task {
            if let vidaa = activeConnector as? HisenseConnector {
                let success = await vidaa.submitPIN(pin)
                if success, let device = connectedDevice {
                    _ = addDevice(device)
                }
            }
        }
    }

    func cancelPairing() {
        activeConnector?.cancelPairing()
    }
}
