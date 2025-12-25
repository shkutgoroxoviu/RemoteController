//
//  DeviceSearchView.swift
//  RemoteTVController
//

import SwiftUI

struct DeviceSearchView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DevicesViewModel()
    @Environment(\.dismiss) var dismiss
    
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(hex: "15141C").ignoresSafeArea()
            
            VStack(spacing: 0) {
                Text("Finding nearby TVs")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.top, 16)
                
                Spacer()
                
                if viewModel.isConnecting {
                    connectingView
                } else if !viewModel.discoveredDevices.isEmpty {
                    VStack(spacing: 12) {
                        if viewModel.isSearching {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.blue)
                                Text("Still searching...")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        devicesList
                    }
                } else if viewModel.isSearching {
                    searchingAnimation
                } else {
                    noDevicesFound
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    if !viewModel.isSearching && !viewModel.isConnecting {
                        PrimaryButton(title: "SEARCH AGAIN", style: .filled) {
                            viewModel.startSearch()
                        }
                    }
                    
                    if !viewModel.isConnecting {
                        PrimaryButton(title: "ADD TV MANUALLY", style: .outline) {
                            viewModel.showAddManually = true
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.startSearch() }
        .onDisappear { viewModel.stopSearch() }
        .sheet(isPresented: $viewModel.showAddManually) {
            AddDeviceManuallyView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $viewModel.showPINEntry) {
            PINEntryView(viewModel: viewModel)
        }
        .alert("Connection Error", isPresented: $viewModel.showConnectionError) {
            Button("Try Again") {
                if let d = viewModel.selectedDevice {
                    viewModel.connect(to: d)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(viewModel.connectionErrorMessage)
        }
        .onChange(of: viewModel.connectionStatus) { newStatus in
            if newStatus.isConnected {
                if !appState.hasShownCustomRateUs {
                    appState.hasShownCustomRateUs = true
                    AnalyticsService.shared.trackEvent(.rateUsShown, properties: ["type": "custom"])
                }
                dismiss()
            } else if newStatus.isAwaitingPIN {
                viewModel.showPINEntry = true
            }
        }
    }
    
    // MARK: - Connecting View
    
    private var connectingView: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(viewModel.selectedDeviceBrandColor.opacity(0.3 - Double(i) * 0.08), lineWidth: 2)
                        .frame(width: CGFloat(80 + i * 40), height: CGFloat(80 + i * 40))
                        .scaleEffect(1.1)
                        .opacity(0.8)
                        .animation(
                            .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.2),
                            value: viewModel.isConnecting
                        )
                }
                
                ZStack {
                    Circle()
                        .fill(viewModel.selectedDeviceBrandColor.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "tv")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(viewModel.selectedDeviceBrandColor)
                }
            }
            
            VStack(spacing: 8) {
                if let device = viewModel.selectedDevice {
                    Text(device.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(device.ipAddress)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(viewModel.selectedDeviceBrandColor)
                
                Text(viewModel.connectorStateMessage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.connectorStateMessage)
            }
            .padding(.top, 8)
            
            Button {
                viewModel.cancelConnection()
            } label: {
                Text("Cancel")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Searching Animation

    private var searchingAnimation: some View {
        VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.blue.opacity(0.4 - Double(i) * 0.1), lineWidth: 2)
                        .frame(
                            width: CGFloat(100 + i * 50),
                            height: CGFloat(100 + i * 50)
                        )
                        .scaleEffect(animate ? 1.2 : 1.0)
                        .opacity(animate ? 0.3 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.3),
                            value: animate
                        )
                }

                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 70, height: 70)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.blue)
                }
            }

            Text("Searching for TVs...")
                .padding(.top, 10)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)

            Text("Make sure your iPhone and TV are on the same\nWi-Fi network.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
                .padding(.horizontal, 32)
        }
        .onAppear {
            animate = true
        }
        .onDisappear {
            animate = false
        }
    }

    
    // MARK: - Devices List
    
    private var devicesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("Select a TV")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                ForEach(viewModel.discoveredDevices) { device in
                    DiscoveredDeviceCard(
                        device: device,
                        isConnecting: viewModel.isConnectingToDevice(device),
                        connectionStep: viewModel.connectionStepForDevice(device)
                    ) {
//                        if !viewModel.canAddMoreDevices {
//                            appState.triggerPaywall(for: .secondDevice)
//                        } else {
                            viewModel.selectedDevice = device.toTVDevice()
                            viewModel.connectToDiscovered(device)
//                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - No Devices Found
    
    private var noDevicesFound: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.3))
            Text("No TVs found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            Text("Make sure your iPhone and TV are on the same Wi-Fi network.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}

// MARK: - Add Device Manually View

struct AddDeviceManuallyView: View {
    @ObservedObject var viewModel: DevicesViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: Field?
    enum Field { case name, ip }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "15141C").ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TV NAME")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("Enter TV name", text: $viewModel.manualTVName)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                            .focused($focusedField, equals: .name)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IP ADDRESS")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        TextField("000.000.0.00", text: $viewModel.manualIPAddress)
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .padding(16)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                            .focused($focusedField, equals: .ip)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        !viewModel.manualIPAddress.isEmpty && !viewModel.isValidIP(viewModel.manualIPAddress)
                                            ? Color.red.opacity(0.5)
                                            : .clear,
                                        lineWidth: 1
                                    )
                            )
                        
                        if !viewModel.manualIPAddress.isEmpty && !viewModel.isValidIP(viewModel.manualIPAddress) {
                            Text("Please enter a valid IP address")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TV BRAND")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Menu {
                            ForEach(TVBrand.allCases, id: \.self) { brand in
                                Button(action: { viewModel.manualTVBrand = brand }) {
                                    HStack {
                                        Text(brand.displayName)
                                        if viewModel.manualTVBrand == brand {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(viewModel.manualTVBrand.displayName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(16)
                            .background(Color(white: 0.12))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                    
                    PrimaryButton(
                        title: "ADD TV",
                        style: .filled,
                        isLoading: viewModel.connectionStatus == .connecting
                    ) {
                        focusedField = nil
                        viewModel.addDeviceManually()
                    }
                    .disabled(viewModel.manualTVName.isEmpty || !viewModel.isValidIP(viewModel.manualIPAddress))
                    .opacity(viewModel.manualTVName.isEmpty || !viewModel.isValidIP(viewModel.manualIPAddress) ? 0.5 : 1)
                }
                .padding(24)
            }
            .navigationTitle("Add TV Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focusedField = .name }
    }
}

// MARK: - PIN Entry View for Hisense

struct PINEntryView: View {
    @ObservedObject var viewModel: DevicesViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var isPINFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 40) {
                
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .stroke(Color.green.opacity(0.3), lineWidth: 2)
                            .frame(width: 140, height: 140)
                            .scaleEffect(1.1)
                            .opacity(0.7)
                        
                        Image(systemName: "tv")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Enter PIN Code")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("A PIN code should appear on your Hisense TV screen.\nEnter the 4-digit code below to connect.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Text("If no PIN appears, check TV Settings → Network → External Device Control")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            ForEach(0..<4, id: \.self) { index in
                                PINDigitBox(
                                    digit: getPINDigit(at: index),
                                    isFocused: viewModel.pinCode.count == index
                                )
                            }
                        }
                        
                        TextField("", text: $viewModel.pinCode)
                            .keyboardType(.numberPad)
                            .focused($isPINFieldFocused)
                            .opacity(0)
                            .frame(width: 1, height: 1)
                            .onChange(of: viewModel.pinCode) { newValue in
                                viewModel.pinCode = String(newValue.prefix(4)).filter { $0.isNumber }
                            }
                    }
                    .onTapGesture { isPINFieldFocused = true }
                    
                    Spacer()
                    
                    VStack(spacing: 12) {
                        PrimaryButton(
                            title: "CONNECT WITH PIN",
                            style: .filled,
                            isLoading: viewModel.connectionStatus == .connecting
                        ) {
//                            viewModel.submitPIN()
                        }
                        .disabled(viewModel.pinCode.count != 4)
                        .opacity(viewModel.pinCode.count != 4 ? 0.5 : 1)
                        
                        Button {
//                            viewModel.connectWithoutPIN()
                        } label: {
                            Text("Connect without PIN")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.green)
                                .padding(.vertical, 8)
                        }
                        
                        Button {
//                            viewModel.cancelPINEntry()
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .padding(.top, 32)
            }
            .navigationTitle("Hisense TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
//                        viewModel.cancelPINEntry()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { isPINFieldFocused = true }
    }
    
    private func getPINDigit(at index: Int) -> String? {
        guard index < viewModel.pinCode.count else { return nil }
        let pinIndex = viewModel.pinCode.index(viewModel.pinCode.startIndex, offsetBy: index)
        return String(viewModel.pinCode[pinIndex])
    }
}

// MARK: - Single PIN Digit Box

struct PINDigitBox: View {
    let digit: String?
    let isFocused: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
                .frame(width: 60, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.green : Color.white.opacity(0.1), lineWidth: isFocused ? 2 : 1)
                )
            
            if let digit = digit {
                Text(digit)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            } else if isFocused {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: 2, height: 28)
                    .opacity(0.8)
            }
        }
    }
}
