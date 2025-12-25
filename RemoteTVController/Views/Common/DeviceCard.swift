//
//  DeviceCard.swift
//  RemoteTVController
//
import SwiftUI

struct DeviceCard: View {
    let device: TVDevice
    let isConnected: Bool
    let isOffline: Bool
    let onTap: () -> Void

    private var brandColor: Color {
        switch device.brand {
        case .samsung: return .blue
        case .lg: return .red
        case .sony: return .purple
        case .hisense: return .green
        case .philips: return .orange
        case .panasonic: return .cyan
        case .tcl: return .teal
        case .roku: return .indigo
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1F1E26").opacity(0.65),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(brandColor.opacity(0.25))
                            .frame(width: 44, height: 44)

                        Image(systemName: "tv")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(brandColor)
                    }
                    .glassCard(cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Text(device.ipAddress)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    if isConnected {
                        statusBadge
                    } else if isOffline {
                        offlineBadge
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(16)
            }
            .glassCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isConnected ? Color.green.opacity(0.4) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Text("Connected")
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.green)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.18))
            .cornerRadius(12)
    }

    private var offlineBadge: some View {
        Text("Offline")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.45))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.12))
            .cornerRadius(12)
    }
}

struct DiscoveredDeviceCard: View {
    let device: DiscoveredDevice
    let isConnecting: Bool
    var connectionStep: String? = nil
    let onTap: () -> Void

    private var brandColor: Color {
        switch device.brand {
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

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "1F1E26").opacity(0.65),
                                Color.black.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(brandColor.opacity(0.25))
                                .frame(width: 44, height: 44)

                            if isConnecting {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(brandColor)
                            } else {
                                Image(systemName: "tv")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(brandColor)
                            }
                        }
                        .glassCard(cornerRadius: 8)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(device.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)

                                if device.brand != .unknown {
                                    Text(device.brand.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(brandColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(brandColor.opacity(0.18))
                                        .cornerRadius(4)
                                }
                            }

                            Text(device.ipAddress)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.55))
                        }

                        Spacer()

                        if isConnecting {
                            Text("Connecting...")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(brandColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(brandColor.opacity(0.18))
                                .cornerRadius(6)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                    .padding(16)

                    if isConnecting, let step = connectionStep {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white.opacity(0.6))

                            Text(step)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .glassCard(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isConnecting ? brandColor.opacity(0.35) : .clear,
                        lineWidth: 1
                    )
            )
            .animation(.easeInOut(duration: 0.3), value: isConnecting)
            .animation(.easeInOut(duration: 0.3), value: connectionStep)
        }
        .buttonStyle(.plain)
        .disabled(isConnecting)
    }
}


struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}
