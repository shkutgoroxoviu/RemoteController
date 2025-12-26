//
//  RemoteView.swift
//  RemoteTVController
//

import SwiftUI

struct RemoteView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tvManager: TVConnectionManager
    @StateObject private var viewModel = RemoteViewModel()
    
    @State private var showProAlert = false
    
    var body: some View {
        ZStack {
            Color(hex: "15141C").ignoresSafeArea()
            if viewModel.connectionStatus.isConnected {
                RadialGradient(colors: [Color.green.opacity(0.15), .clear], center: .top, startRadius: 0, endRadius: 300).ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                topSection
                Spacer()
                NavigationPadView { sendCommand($0) }
                Spacer().frame(height: 24)
                controlButtonsRow
                Spacer().frame(height: 24)
                volumeChannelRow
                Spacer()
                ConnectionStatusView(status: viewModel.connectionStatus, deviceName: tvManager.connectedDevice?.name).padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .alert("You already have PRO", isPresented: $showProAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You already have an active subscription.")
        }
        .alert("Connection Error", isPresented: $viewModel.showError) {
            Button("Try Again") { viewModel.reconnectToLastDevice() }
            Button("Cancel", role: .cancel) {}
        } message: { Text(viewModel.errorMessage) }
    }
    
    private var topSection: some View {
        HStack(spacing: 16) {
            RemoteButtonView(button: .power, size: .init(width: 72, height: 56)) { sendCommand(.power) }
            Spacer()
            Button {
                SubscriptionManager.shared.loadProducts()
                if !SubscriptionManager.shared.isSubscribed {
                    appState.triggerPaywall(for: .premiumFeature)
                } else {
                    showProAlert = true
                }
            } label: {
                Text("PRO").font(.system(size: 12, weight: .bold)).foregroundColor(Color(hex: "15141C"))
                    .frame(width: 72, height: 56)
                    .background(.white).cornerRadius(40)
                    .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
            }
            Spacer()
            NavigationLink(destination: DeviceSearchView()) {
                ZStack {
                    Rectangle()
                        .fill(viewModel.connectionStatus.isConnected ? Color(hex: "12AE53").opacity(0.24) : Color(hex: "1F1E26"))
                        .frame(width: 72, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.gray, .gray.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 72, height: 56)
                        }
                    Image(systemName: "wifi").font(.system(size: 20, weight: .medium)).foregroundColor(.white)
                }
            }
        }
    }
    
    private var controlButtonsRow: some View {
        HStack(spacing: 24) {
            controlButton(icon: "arrow.uturn.backward", button: .back)
            controlButton(icon: "house", button: .home)
            Button { sendCommand(.exit) } label: {
                ZStack {
                    Rectangle()
                        .fill(Color(hex: "1F1E26").opacity(0.35))
                        .frame(width: 72, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 40, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.gray, .gray.opacity(0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                                .frame(width: 72, height: 56)
                        }
                    Text("EXIT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func controlButton(icon: String, button: RemoteButton) -> some View {
        Button {
            sendCommand(button)
        } label: {
            ZStack {
                Rectangle()
                    .fill(Color(hex: "1F1E26").opacity(0.35))
                    .frame(width: 72, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.gray, .gray.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                            .frame(width: 72, height: 56)
                    }
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }

    private var volumeChannelRow: some View {
        HStack(spacing: 0) {
            volumeControl
            Spacer()
            VStack {
                Button { sendCommand(.menu) } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: "1F1E26").opacity(0.35))
                            .frame(width: 72, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.gray, .gray.opacity(0.35)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                    .frame(width: 72, height: 56)
                            }
                        Text("MENU")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                Button { sendCommand(.mute) } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color(hex: "1F1E26").opacity(0.35))
                            .frame(width: 72, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 40, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.gray, .gray.opacity(0.35)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                    .frame(width: 72, height: 56)
                            }
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
            Spacer()
            channelControl
        }
    }

    private var volumeControl: some View {
        VStack(spacing: 0) {
            Button { sendCommand(.volumeUp) } label: {
                Image(systemName: "speaker.plus")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 44)
            }
            Text("VOL")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 60, height: 32)
                .onTapGesture { sendCommand(.menu) }
            Button { sendCommand(.volumeDown) } label: {
                Image(systemName: "speaker.minus")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 44)
            }
        }
        .background(Color(hex: "1F1E26").opacity(0.35))
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.gray, .gray.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var channelControl: some View {
        VStack(spacing: 0) {
            Button { sendCommand(.channelUp) } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 44)
            }
            Text("CH")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 60, height: 32)
                .onTapGesture { sendCommand(.source) }
            Button { sendCommand(.channelDown) } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 44)
            }
        }
        .background(Color(hex: "1F1E26").opacity(0.35))
        .cornerRadius(30)
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(
                    LinearGradient(
                        colors: [.gray, .gray.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func sendCommand(_ button: RemoteButton) {
        if viewModel.isPremiumButton(button) {
            appState.triggerPaywall(for: .premiumFeature)
            return
        }
        HapticService.shared.remoteButtonPressed()
        viewModel.sendCommand(button)
    }
}


