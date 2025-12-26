//
//  PaywallViewModel.swift
//  RemoteTVController
//

import SwiftUI
internal import Combine
import ApphudSDK
internal import StoreKit

@MainActor
final class PaywallViewModel: ObservableObject {

    // MARK: - Published (для View)
    @Published var weeklyProduct: ApphudProduct?
    @Published var yearlyProduct: ApphudProduct?
    @Published var selectedProduct: ApphudProduct?

    @Published var isLoading: Bool = false
    @Published var canClose: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - IDs
    private let weeklyId = "week_6.99_nottrial"
    private let yearlyId = "yearly_49.99_nottrial"

    private let manager = SubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var closeTimer: Timer?

    // MARK: - Init
    init() {
        Task {
            manager.loadProducts()
            bind()
            startCloseTimer()
        }
    }

    deinit {
        closeTimer?.invalidate()
    }

    // MARK: - Bind SubscriptionManager
    private func bind() {

        manager.$products
            .receive(on: DispatchQueue.main)
            .sink { [weak self] products in
                guard let self else { return }

                self.weeklyProduct = products.first { $0.productId == self.weeklyId }
                self.yearlyProduct = products.first { $0.productId == self.yearlyId }

                self.selectedProduct = self.yearlyProduct ?? self.weeklyProduct
            }
            .store(in: &cancellables)

        manager.$isLoading
            .assign(to: &$isLoading)

        manager.$errorMessage
            .sink { [weak self] message in
                guard !message.isEmpty else { return }
                self?.errorMessage = message
                self?.showError = true
            }
            .store(in: &cancellables)
    }

    // MARK: - UI actions
    func select(_ product: ApphudProduct) {
        selectedProduct = product
    }

    @MainActor
    func purchase(completion: @escaping (Bool) -> Void) async {
        guard let product = selectedProduct else {
            completion(false)
            return
        }

        manager.purchase(product: product) { success, error in
            if let error {
                self.errorMessage = error
                self.showError = true
            }
            AppState.shared.hasSubscribed = true
            completion(success)
        }
    }

    func restore(completion: @escaping (Bool) -> Void) {
        manager.restorePurchases { success, error in
            if let error {
                self.errorMessage = error
                self.showError = true
            }
            AppState.shared.hasSubscribed = true
            completion(success)
        }
    }

    // MARK: - Price helpers (просто прокси)
    func price(_ product: ApphudProduct) -> String {
        manager.getPriceString(for: product)
    }

    func pricePerWeek(_ product: ApphudProduct) -> String {
        let weekly = (product.skProduct?.price.doubleValue ?? 0) / 52
        return String(format: "$%.2f/week", weekly)
    }
    
    func weeklySavingsPercent(weekly: ApphudProduct?, yearly: ApphudProduct?) -> Int {
        guard let weekly = weekly, let yearly = yearly,
              let weeklyPrice = weekly.skProduct?.price.doubleValue,
              let yearlyPrice = yearly.skProduct?.price.doubleValue else { return 0 }

        let yearlyPricePerWeek = yearlyPrice / 52.0  

        let savings = 1.0 - (yearlyPricePerWeek / weeklyPrice)
        return max(0, Int(savings * 100))
    }

    // MARK: - Close delay
    private func startCloseTimer() {
        closeTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            withAnimation {
                self?.canClose = true
            }
        }
    }
}

