//
//  DevicesListView.swift
//  RemoteTVController
//

import SwiftUI

struct DevicesListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DevicesViewModel()
    
    var body: some View {
        ZStack {
            Color(hex: "15141C").ignoresSafeArea()
            VStack(spacing: 0) {
                if !SubscriptionManager.shared.isSubscribed && viewModel.savedDevices.count >= 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").font(.system(size: 14))
                        Text("Only one TV can be saved in the free version.").font(.system(size: 13))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.bottom, 12)
                }
                if viewModel.savedDevices.isEmpty {
                    emptyStateView
                } else {
                    devicesList
                }
                
                Spacer()
                
                PrimaryButton(title: "ADD TV MANUALLY", style: .filled) {
                    viewModel.showAddManually = true
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
        .navigationTitle("My TVs")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.showAddManually) { AddDeviceManuallyView(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showManageDevice) { ManageDeviceSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showRenameDevice) { RenameDeviceSheet(viewModel: viewModel) }
        .sheet(isPresented: $viewModel.showEditIP) { EditIPSheet(viewModel: viewModel) }
        .alert("Delete TV?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { if let d = viewModel.selectedDevice { viewModel.deleteDevice(d) } }
        } message: { Text("Are you sure you want to remove it? This TV will be removed from your list.") }
            .alert("Connection Error", isPresented: $viewModel.showConnectionError) {
                Button("Try Again") { if let d = viewModel.selectedDevice { viewModel.connect(to: d) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text(viewModel.connectionErrorMessage) }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tv.slash").font(.system(size: 48, weight: .light)).foregroundColor(.white.opacity(0.3))
            Text("There are no TVs yet").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
            Text("Add your first TV to get started.").font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }
    
    private var devicesList: some View {
        List {
            ForEach(viewModel.savedDevices) { device in
                DeviceCard(
                    device: device,
                    isConnected: viewModel.isDeviceConnected(device),
                    isOffline: viewModel.isDeviceOffline(device),
                    onTap: { viewModel.connect(to: device) }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        viewModel.selectedDevice = device
                        viewModel.showManageDevice = true
                    } label: {
                        Label("Manage", systemImage: "ellipsis")
                    }
                    .tint(.gray)
                    
                    Button(role: .destructive) {
                        viewModel.selectedDevice = device
                        viewModel.showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(hex: "15141C"))
    }
}

struct ManageDeviceSheet: View {
    @ObservedObject var viewModel: DevicesViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Manage TV").font(.system(size: 18, weight: .semibold)).foregroundColor(.white).padding(.top, 24)
                VStack(spacing: 12) {
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { viewModel.showRenameDevice = true } } label: {
                        Text("RENAME TV").font(.system(size: 14, weight: .semibold)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 50).background(Color.white).cornerRadius(25)
                    }
                    Button { dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { viewModel.showEditIP = true } } label: {
                        Text("EDIT IP").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 50).background(Color(white: 0.2)).cornerRadius(25)
                    }
                    Button { dismiss() } label: {
                        Text("CANCEL").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity).frame(height: 50).background(Color(white: 0.15)).cornerRadius(25)
                    }
                }.padding(.horizontal, 24)
                Spacer()
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
    }
}

struct RenameDeviceSheet: View {
    @ObservedObject var viewModel: DevicesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newName = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TV NAME").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
                        TextField("Enter TV name", text: $newName)
                            .font(.system(size: 16)).foregroundColor(.white)
                            .padding(16).background(Color(white: 0.12)).cornerRadius(12).focused($focused)
                    }
                    Spacer()
                    PrimaryButton(title: "SAVE", style: .filled) { viewModel.renameDevice(to: newName); dismiss() }
                        .disabled(newName.isEmpty).opacity(newName.isEmpty ? 0.5 : 1)
                }.padding(24)
            }
            .navigationTitle("Rename TV").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.white) } } }
        }
        .presentationDetents([.medium]).presentationDragIndicator(.visible)
        .onAppear { newName = viewModel.selectedDevice?.name ?? ""; focused = true }
    }
}

struct EditIPSheet: View {
    @ObservedObject var viewModel: DevicesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newIP = ""
    @FocusState private var focused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("IP ADDRESS").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.5))
                        TextField("000.000.0.00", text: $newIP)
                            .font(.system(size: 16)).foregroundColor(.white).keyboardType(.decimalPad)
                            .padding(16).background(Color(white: 0.12)).cornerRadius(12).focused($focused)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(!newIP.isEmpty && !viewModel.isValidIP(newIP) ? Color.red.opacity(0.5) : .clear, lineWidth: 1))
                        if !newIP.isEmpty && !viewModel.isValidIP(newIP) {
                            Text("Please enter a valid IP address").font(.system(size: 12)).foregroundColor(.red.opacity(0.8))
                        }
                    }
                    Spacer()
                    PrimaryButton(title: "SAVE", style: .filled) { viewModel.updateDeviceIP(to: newIP); dismiss() }
                        .disabled(!viewModel.isValidIP(newIP)).opacity(!viewModel.isValidIP(newIP) ? 0.5 : 1)
                }.padding(24)
            }
            .navigationTitle("Edit IP").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.white) } } }
        }
        .presentationDetents([.medium]).presentationDragIndicator(.visible)
        .onAppear { newIP = viewModel.selectedDevice?.ipAddress ?? ""; focused = true }
    }
}


