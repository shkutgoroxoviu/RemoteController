//
//  RemoteViewModel.swift
//  RemoteTVController
//

import SwiftUI
import Combine

@MainActor
final class RemoteViewModel: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var connectedDeviceName: String = "Not connected"
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private let tvManager = TVConnectionManager.shared
    
    init() {
        tvManager.$connectionStatus.receive(on: DispatchQueue.main).assign(to: &$connectionStatus)
        tvManager.$connectedDevice.receive(on: DispatchQueue.main)
            .map { $0 != nil ? "Connected to \($0!.name)" : "Not connected" }
            .assign(to: &$connectedDeviceName)
    }
    
    func sendCommand(_ button: RemoteButton) {
        if button.isPremium && !SubscriptionManager.shared.isSubscribed { return }
        HapticService.shared.remoteButtonPressed()
        tvManager.sendCommand(button)
    }
    
    func isPremiumButton(_ button: RemoteButton) -> Bool {
        button.isPremium && !SubscriptionManager.shared.isSubscribed
    }
    
    func reconnectToLastDevice() {
        Task {
            if let lastDevice = tvManager.savedDevices.first {
                _ = await tvManager.connect(to: lastDevice)
            }
        }
    }
}


