//
//  DevicesViewModel.swift
//  RemoteTVController
//

import SwiftUI
internal import Combine

@MainActor
final class DevicesViewModel: ObservableObject {
    @Published var savedDevices: [TVDevice] = []
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isSearching: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var connectorState: ConnectorState = .idle
    @Published var connectedDeviceId: UUID?
    
    @Published var showAddManually: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var showManageDevice: Bool = false
    @Published var showRenameDevice: Bool = false
    @Published var showEditIP: Bool = false
    @Published var showConnectionError: Bool = false
    @Published var connectionErrorMessage: String = ""
    @Published var showPINEntry: Bool = false
    @Published var pinCode: String = ""
    
    @Published var selectedDevice: TVDevice?
    @Published var connectingDeviceIP: String?
    @Published var manualTVName: String = ""
    @Published var manualIPAddress: String = ""
    @Published var manualTVBrand: TVBrand = .hisense
    
    private let tvManager = TVConnectionManager.shared
    private let discoveryService = TVDiscoveryService.shared
    
    var canAddMoreDevices: Bool { tvManager.canAddMoreDevices }
    
    // MARK: - Computed Properties
    
    var isConnecting: Bool {
        connectionStatus == .connecting || connectorState.isConnecting
    }
    
    var connectorStateMessage: String {
        connectorState.displayMessage
    }
    
    var selectedDeviceBrandColor: Color {
        guard let device = selectedDevice else { return .blue }
        return brandColor(for: device.brand)
    }
    
    // MARK: - Initialization
    
    init() {
        tvManager.$savedDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$savedDevices)
        
        tvManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
        
        tvManager.$connectorState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectorState)
        
        tvManager.$connectedDevice
            .receive(on: DispatchQueue.main)
            .map { $0?.id }
            .assign(to: &$connectedDeviceId)
        
        discoveryService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$discoveredDevices)
        
        discoveryService.$isSearching
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSearching)
    }
    
    // MARK: - Discovery
    
    func startSearch() {
        discoveryService.startDiscovery()
    }
    
    func stopSearch() {
        discoveryService.stopDiscovery()
    }
    
    // MARK: - Connection
    
    func connect(to device: TVDevice) {
        selectedDevice = device
        connectingDeviceIP = device.ipAddress
        
        Task {
            let success = await tvManager.connect(to: device)
            
            if !success {
                connectionErrorMessage = tvManager.connectionStatus.displayText
                showConnectionError = true
            }
            
            connectingDeviceIP = nil
        }
    }
    
    func connectToDiscovered(_ discovered: DiscoveredDevice) {
//        if !canAddMoreDevices { return }
        connect(to: discovered.toTVDevice())
    }
    
    func disconnect() {
        tvManager.disconnect()
        connectingDeviceIP = nil
    }
    
    func cancelConnection() {
        tvManager.disconnect()
        selectedDevice = nil
        connectingDeviceIP = nil
    }
    
    // MARK: - Connection Helpers
    
    func isConnectingToDevice(_ device: DiscoveredDevice) -> Bool {
        connectingDeviceIP == device.ipAddress && isConnecting
    }
    
    func connectionStepForDevice(_ device: DiscoveredDevice) -> String? {
        guard isConnectingToDevice(device) else { return nil }
        return connectorState.displayMessage
    }
    
    // MARK: - Device Management
    
    func deleteDevice(_ device: TVDevice) {
        tvManager.removeDevice(device)
        showDeleteConfirmation = false
        selectedDevice = nil
    }
    
    func renameDevice(to newName: String) {
        guard var device = selectedDevice else { return }
        device.name = newName
        tvManager.updateDevice(device)
        showRenameDevice = false
    }
    
    func updateDeviceIP(to newIP: String) {
        guard var device = selectedDevice, isValidIP(newIP) else { return }
        device.ipAddress = newIP
        tvManager.updateDevice(device)
        showEditIP = false
    }
    
    func addDeviceManually() {
        guard !manualTVName.isEmpty, isValidIP(manualIPAddress) else { return }
        let device = TVDevice(name: manualTVName, ipAddress: manualIPAddress, brand: manualTVBrand)
        if tvManager.addDevice(device) {
            connect(to: device)
            showAddManually = false
            manualTVName = ""
            manualIPAddress = ""
            manualTVBrand = .hisense
        }
    }
    
    // MARK: - Helpers
    
    func isValidIP(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { Int($0).map { $0 >= 0 && $0 <= 255 } ?? false }
    }
    
    func isDeviceConnected(_ device: TVDevice) -> Bool {
        device.id == connectedDeviceId && connectionStatus.isConnected
    }
    
    func isDeviceOffline(_ device: TVDevice) -> Bool {
        guard let lastConnected = device.lastConnected else { return true }
        return Date().timeIntervalSince(lastConnected) > 86400
    }
    
    private func brandColor(for brand: TVBrand) -> Color {
        switch brand {
        case .samsung: return .blue
        case .lg: return .red
        case .sony: return .purple
        case .hisense: return .green
        case .philips: return .orange
        case .panasonic: return .cyan
        case .tcl: return .teal
        case .roku: return .indigo
        case .unknown: return .gray
        case .xiaomi: return .yellow
        case .sharp: return .pink
        case .nokia: return .mint
        case .thomson: return .brown
        case .jvc: return .blue.opacity(0.7)
        case .skyworth: return .green.opacity(0.7)
        case .haier: return .orange.opacity(0.7)
        case .vestel: return .purple.opacity(0.7)
        }
    }
}
