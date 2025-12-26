//
//  PaywallView.swift
//  RemoteTVController
//

import SwiftUI
import ApphudSDK
internal import StoreKit

struct PaywallView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PaywallViewModel()

    var body: some View {
        ZStack {

            Image(.paywall)
                .resizable()
                .padding(.bottom, 250)
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // MARK: - Close
                HStack {
                    if viewModel.canClose {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .animation(.easeInOut(duration: 0.3), value: viewModel.canClose)

                Spacer()

                // MARK: - Title
                Text("UPGRADE TO PRO CONTROL")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 20)

                featuresSection
                    .padding(.top, 20)

                Spacer()

                subscriptionOptions
                    .padding(.horizontal, 24)

                Text("Cancel Anytime")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 16)

                // MARK: - CTA
                PrimaryButton(
                    title: "CONTINUE",
                    style: .filled,
                    isLoading: viewModel.isLoading
                ) {
                    Task { @MainActor in
                        await viewModel.purchase { success in
                            if success {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                legalLinks
                    .padding(.top, 16)
                    .padding(.bottom, 24)
            }
        }
        .background(Color(hex: "15141C").ignoresSafeArea())
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Features
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("Unlimited TV connections")
            featureRow("Automatic device saving")
            featureRow("Enhanced speed & reliability")
        }
        .padding(.horizontal, 40)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white)
        }
    }

    // MARK: - Subscription Options
    private var subscriptionOptions: some View {
        VStack(spacing: 12) {

            if let weekly = viewModel.weeklyProduct {
                subscriptionOption(
                    title: "Weekly",
                    subtitle: nil,
                    trailing: "\(viewModel.price(weekly))/week",
                    isSelected: viewModel.selectedProduct?.id == weekly.id
                ) {
                    viewModel.select(weekly)
                }
            }

            if let yearly = viewModel.yearlyProduct {
                subscriptionOption(
                    title: "Yearly",
                    subtitle: "\(viewModel.price(yearly))/year",
                    trailing: "\(viewModel.pricePerWeek(yearly))",
                    badge: "Save \(viewModel.weeklySavingsPercent(weekly: viewModel.weeklyProduct ?? nil, yearly: yearly))%",
                    isSelected: viewModel.selectedProduct?.id == yearly.id
                ) {
                    viewModel.select(yearly)
                }
            }
        }
    }

    private func subscriptionOption(
        title: String,
        subtitle: String? = nil,
        trailing: String,
        badge: String? = nil,
        isSelected: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                
                HStack(spacing: 12) {
                    Image(isSelected ? .selected : .unselected)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    Text(trailing)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(16)
                .glassCard()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(isSelected ? Color.white.opacity(0.3) : .clear, lineWidth: 1)
                        )
                )
                
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: -2, y: 0)
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 2, y: 0)
                        )
                        .offset(x: -12, y: -12)
                }
            }
        }
    }

    // MARK: - Legal
    private var legalLinks: some View {
        HStack(spacing: 6) {
            Link("Terms of Use", destination: URL(string: "https://docs.google.com/document/d/1rPxdnV02PWzUxGKP_aJps4ntmWOZ5LesWFGzdpPNeXA/edit?usp=sharing")!)
            Text("|").foregroundColor(.white.opacity(0.3))
            Link("Privacy Policy", destination: URL(string: "https://docs.google.com/document/d/1ak3VZmfz2ODN2fTTg2RtBSV_HqsRLz0H_6EweqXw-QM/edit?usp=sharing")!)
            Text("|").foregroundColor(.white.opacity(0.3))
            Button("Restore") {
                viewModel.restore { _ in }
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.5))
    }
}




