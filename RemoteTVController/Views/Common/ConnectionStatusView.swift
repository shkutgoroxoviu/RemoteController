//
//  ConnectionStatusView.swift
//  RemoteTVController
//

import SwiftUI

struct ConnectionStatusView: View {
    let status: ConnectionStatus
    let deviceName: String?
    
    var body: some View {
        HStack(spacing: 8) {
            statusIndicator
            Text(displayText).font(.system(size: 12, weight: .medium)).foregroundColor(textColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch status {
        case .connected:
            Image(systemName: "wifi").font(.system(size: 12, weight: .semibold)).foregroundColor(.green)
        case .connecting, .searching, .awaitingConfirmation:
            ProgressView().scaleEffect(0.7)
        case .error:
            Image(systemName: "exclamationmark.triangle").font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
        case .disconnected:
            Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
        case .awaitingPIN:
            Image(systemName: "wifi.slash").font(.system(size: 12, weight: .semibold)).foregroundColor(.gray)
        }
    }
    
    private var displayText: String {
        status.isConnected ? "Connected to \(deviceName ?? "TV")" : status.displayText
    }
    
    private var textColor: Color {
        switch status {
        case .connected: return .green
        case .error: return .red
        default: return .white.opacity(0.7)
        }
    }
    
    private var backgroundColor: Color {
        switch status {
        case .connected: return .green.opacity(0.15)
        case .error: return .red.opacity(0.15)
        default: return .white.opacity(0.1)
        }
    }
}


