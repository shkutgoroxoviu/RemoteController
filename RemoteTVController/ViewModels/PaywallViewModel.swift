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
    @Published var weeklyProduct: Product?
    @Published var yearlyProduct: Product?
    @Published var selectedProduct: Product?

    @Published var isLoading: Bool = false
    @Published var canClose: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - IDs
    private let weeklyId = "week_6.99_nottrial"
    private let yearlyId = "yearly_49.99_nottrial"

    private let manager = StoreKitSubscriptionManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var closeTimer: Timer?

    // MARK: - Init
    init() {
        Task {
            await manager.fetchProducts()
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

                self.weeklyProduct = products.first { $0.id == self.weeklyId }
                self.yearlyProduct = products.first { $0.id == self.yearlyId }

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
    func select(_ product: Product) {
        selectedProduct = product
    }

    @MainActor
    func purchase(completion: @escaping (Bool) -> Void) async {
        guard let product = selectedProduct else {
            completion(false)
            return
        }

        await manager.purchase(product) { success, error in
            if let error {
                self.errorMessage = error
                self.showError = true
            }
            completion(success)
        }
    }

    func restore(completion: @escaping (Bool) -> Void) {
//        manager.restorePurchases { success, error in
//            if let error {
//                self.errorMessage = error
//                self.showError = true
//            }
//            completion(success)
//        }
    }

    // MARK: - Price helpers (просто прокси)
    func price(_ product: Product) -> String {
        manager.getPriceString(for: product)
    }

    func pricePerWeek(_ product: Product) -> String {
        let weekly = NSDecimalNumber(decimal: product.price).doubleValue / 52
        return String(format: "$%.2f/week", weekly)
    }
    
    func weeklySavingsPercent(weekly: Product?, yearly: Product?) -> Int {
        guard let weekly = weekly, let yearly = yearly else { return 0 }
        let weeklyPrice = (weekly.price as NSDecimalNumber).doubleValue
        let yearlyPricePerWeek = (yearly.price as NSDecimalNumber).doubleValue / 52

        let savings = 1 - (yearlyPricePerWeek / weeklyPrice)
        return Int(savings * 100)
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

