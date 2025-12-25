//
//  PaywallViewModel.swift
//  RemoteTVController
//

import SwiftUI
import Combine

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var products: [SubscriptionProduct] = []
    @Published var selectedProduct: SubscriptionProduct?
    @Published var isLoading: Bool = false
    @Published var canClose: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    let trigger: PaywallTrigger
    private var closeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init(trigger: PaywallTrigger) {
        self.trigger = trigger
        
        SubscriptionManager.shared.$products
            .receive(on: DispatchQueue.main)
            .sink { [weak self] products in
                self?.products = products
                self?.selectedProduct = products.first(where: { $0.type == .yearly }) ?? products.first
            }
            .store(in: &cancellables)
        
        SubscriptionManager.shared.$isLoading.receive(on: DispatchQueue.main).assign(to: &$isLoading)
        SubscriptionManager.shared.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] msg in
                self?.errorMessage = msg
                self?.showError = true
            }
            .store(in: &cancellables)
        
        closeTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                withAnimation { self?.canClose = true }
            }
        }
    }
    
    func selectProduct(_ product: SubscriptionProduct) { selectedProduct = product }
    
    func purchase() async -> Bool {
        guard let product = selectedProduct else { return false }
        return await SubscriptionManager.shared.purchase(product)
    }
    
    func restore() async -> Bool {
        await SubscriptionManager.shared.restorePurchases()
    }
    
    var weeklyProduct: SubscriptionProduct? { products.first(where: { $0.type == .weekly }) }
    var yearlyProduct: SubscriptionProduct? { products.first(where: { $0.type == .yearly }) }
    var hasFreeTrial: Bool { selectedProduct?.hasFreeTrial ?? false }
    var trialDuration: String { selectedProduct?.trialDuration ?? "3-Day" }
    
    deinit { closeTimer?.invalidate() }
}


