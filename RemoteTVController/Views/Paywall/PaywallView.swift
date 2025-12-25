//
//  PaywallView.swift
//  RemoteTVController
//

import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: PaywallViewModel
    
    init(trigger: PaywallTrigger) {
        _viewModel = StateObject(wrappedValue: PaywallViewModel(trigger: trigger))
    }
    
    var body: some View {
        ZStack {
            Image(.paywall)
                .resizable()
                .padding(.bottom, 250)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    if viewModel.canClose {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .medium)).foregroundColor(.white.opacity(0.6))
                                .frame(width: 32, height: 32).background(Color.white.opacity(0.1)).clipShape(Circle())
                        }.transition(.opacity.combined(with: .scale))
                    }
                    Spacer()
                }.padding(.horizontal, 20).padding(.top, 40).animation(.easeInOut(duration: 0.3), value: viewModel.canClose)
                Spacer()
                
                Text("UPGRADE TO PRO CONTROL").font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.top, 20)
                
                featuresSection.padding(.top, 20)
                
                Spacer()
                
                subscriptionOptions.padding(.horizontal, 24)
                
                Text("Cancel Anytime").font(.system(size: 12)).foregroundColor(.white.opacity(0.5)).padding(.top, 16)
                
                PrimaryButton(title: viewModel.hasFreeTrial ? "START \(viewModel.trialDuration.uppercased()) FREE TRIAL" : "CONTINUE", style: .filled, isLoading: viewModel.isLoading) {
                    Task { if await viewModel.purchase() { dismiss() } }
                }.padding(.horizontal, 24).padding(.top, 16)
                
                legalLinks.padding(.top, 16).padding(.bottom, 24)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(hex: "15141C"), Color(hex: "15141C")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("Error", isPresented: $viewModel.showError) { Button("OK", role: .cancel) {} } message: { Text(viewModel.errorMessage) }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("Unlimited TV connections")
            featureRow("Automatic device saving")
            featureRow("Enhanced speed & reliability")
        }.padding(.horizontal, 40)
    }
    
    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
            Text(text).font(.system(size: 15)).foregroundColor(.white)
        }
    }
    
    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            if let weekly = viewModel.weeklyProduct {
                subscriptionOption(product: weekly, isSelected: viewModel.selectedProduct?.id == weekly.id)
            }
            if let yearly = viewModel.yearlyProduct {
                subscriptionOption(product: yearly, isSelected: viewModel.selectedProduct?.id == yearly.id, showSavings: true)
            }
        }
    }
    
    private func subscriptionOption(product: SubscriptionProduct, isSelected: Bool, showSavings: Bool = false) -> some View {
        Button { viewModel.selectProduct(product) } label: {
            HStack {
                ZStack {
                    Circle().stroke(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 2).frame(width: 22, height: 22)
                    if isSelected { Circle().fill(Color.white).frame(width: 12, height: 12) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.type.displayName).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    if product.type == .yearly {
                        Text("\(product.displayPrice)/year").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                    }
                }
                Spacer()
                if showSavings, let savings = product.savingsPercentage {
                    Text("Save \(savings)%").font(.system(size: 10, weight: .semibold)).foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Color.green).cornerRadius(8)
                }
                Text("\(product.pricePerWeek)/week").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.1))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.white.opacity(0.3) : .clear, lineWidth: 1)))
        }
    }
    
    private var legalLinks: some View {
        HStack(spacing: 4) {
            Link("Terms of Use", destination: URL(string: "https://example.com/terms")!)
            Text("|").foregroundColor(.white.opacity(0.3))
            Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            Text("|").foregroundColor(.white.opacity(0.3))
            Button("Restore") { Task { _ = await viewModel.restore() } }
        }.font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
    }
}


