//
//  SettingsView.swift
//  RemoteTVController
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            Color(hex: "15141C").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    settingsSection(title: "ACCOUNT") {
                        SettingsGlassRow(
                            icon: "creditcard",
                            title: "Manage Subscription",
                            action: viewModel.openManageSubscription
                        )

                        SettingsGlassRow(
                            icon: "questionmark.circle",
                            title: "Support",
                            action: viewModel.openSupport
                        )
                    }

                    settingsSection(title: "LEGAL") {
                        SettingsGlassRow(
                            icon: "doc.text",
                            title: "Terms of Service",
                            action: viewModel.openTerms
                        )

                        SettingsGlassRow(
                            icon: "lock.shield",
                            title: "Privacy policy",
                            action: viewModel.openPrivacy
                        )
                    }

                    settingsSection(title: "ABOUT") {
                        SettingsGlassRow(
                            icon: "star",
                            title: "Rate us",
                            action: viewModel.rateApp
                        )

                        SettingsGlassRow(
                            icon: "square.and.arrow.up",
                            title: "Share the app",
                            action: viewModel.shareApp
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.showRateUs) {
            RateUsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: [viewModel.appStoreURL])
        }
    }

    // MARK: - Section

    private func settingsSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.leading, 4)

            VStack(spacing: 12) {
                content()
            }
        }
    }
}


struct SettingsGlassRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 24)
                    .padding(12)
                    .glassCard(cornerRadius: 14)

                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }
}

struct RateUsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "15141C").ignoresSafeArea()
                VStack(spacing: 32) {
                    Spacer()
                    Image(.rate)
                    Text("Love the app?").font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    Text("Your rating means a lot. Help others discover it!").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).padding(.horizontal, 40)
                    Spacer()
                    PrimaryButton(title: "RATE THE APP", style: .filled) { viewModel.submitRating(); dismiss() }.padding(.horizontal, 24)
                    Button("NOT NOW") { dismiss() }.font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.5)).padding(.bottom, 24)
                }
            }
            .navigationTitle("Rate us").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundColor(.white) } } }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


