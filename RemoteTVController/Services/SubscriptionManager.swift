//
//  SubscriptionManager.swift
//  RemoteTVController
//

import Foundation
internal import StoreKit
internal import Combine
import ApphudSDK

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isSubscribed: Bool = false
    @Published var products: [ApphudProduct] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var isCanceledButActive: Bool = false
    
    // MARK: - Private Properties
    private let paywallID = "main"
    
    private init() {
        setupApphud()
        checkSubscriptionStatus()
    }
    
    // MARK: - Setup Methods
    private func setupApphud() {
        Apphud.setDelegate(self)
        print("🚀 SubscriptionManager: Apphud delegate настроен")
        print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("🔧 Environment: \(isProductionEnvironment ? "Production" : "Sandbox")")
    }
    
    private var isProductionEnvironment: Bool {
#if DEBUG
        return false
#else
        return true
#endif
    }
    
    @MainActor
    func loadProducts() {
        isLoading = true
        errorMessage = ""
        
        Apphud.fetchPlacements { [weak self] placements, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Ошибка загрузки продуктов: \(error.localizedDescription)"
                    return
                }
                
                let placement: ApphudPlacement?
                if let paywallID = self?.paywallID,
                   let found = placements.first(where: { $0.identifier == paywallID }) {
                    placement = found
                } else {
                    placement = placements.first
                    if placement != nil {
                        print("⚠️ Paywall с ID \(self?.paywallID ?? "main") не найден, используем первый доступный")
                    }
                }
                
                if let paywall = placement?.paywall {
                    Apphud.paywallShown(paywall)
                    self?.products = paywall.products
                    print("✅ Загружены продукты: \(paywall.products.count)")
                } else {
                    self?.errorMessage = "Не найден ни один paywall"
                    print("❌ Не найден ни один paywall")
                }
            }
        }
    }

    // MARK: - Purchase Product
    func purchase(product: ApphudProduct, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = ""
        
        guard SKPaymentQueue.canMakePayments() else {
            let msg = "Покупки недоступны на этом устройстве"
            errorMessage = msg
            completion(false, msg)
            return
        }
        
        Apphud.purchase(product) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = result.error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                let active = (result.subscription?.isActive() ?? false) || (result.nonRenewingPurchase?.isActive() ?? false) || Apphud.hasActiveSubscription()
                self?.isSubscribed = active
                completion(active, active ? nil : "Подписка не активна")
            }
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases(completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = ""
        
        Apphud.restorePurchases { [weak self] subscriptions, purchases, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                
                let active = Apphud.hasActiveSubscription()
                self?.isSubscribed = active
                completion(active, active ? nil : "Активные подписки не найдены")
            }
        }
    }
    
    // MARK: - Check Subscription Status
    func checkSubscriptionStatus() {
        isSubscribed = Apphud.hasActiveSubscription()
        print("🔍 SubscriptionManager: Текущий статус подписки: \(isSubscribed)")
    }
    
    // MARK: - Helper Methods for Prices
    func getPriceString(for product: ApphudProduct) -> String {
        guard let skProduct = product.skProduct else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = skProduct.priceLocale
        return formatter.string(from: skProduct.price) ?? ""
    }
    
    func getCurrencySymbol(for product: ApphudProduct) -> String {
        return product.skProduct?.priceLocale.currencySymbol ?? "$"
    }
    
    func getPriceValue(for product: ApphudProduct) -> Double {
        return product.skProduct?.price.doubleValue ?? 0.0
    }
    
    func getSubscriptionPeriod(for product: ApphudProduct) -> String {
        guard let period = product.skProduct?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .day: return period.numberOfUnits == 1 ? "Daily" : "\(period.numberOfUnits) days"
        case .week: return period.numberOfUnits == 1 ? "Weekly" : "\(period.numberOfUnits) weeks"
        case .month: return period.numberOfUnits == 1 ? "Monthly" : "\(period.numberOfUnits) months"
        case .year: return period.numberOfUnits == 1 ? "Annual" : "\(period.numberOfUnits) years"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - ApphudDelegate
extension SubscriptionManager: ApphudDelegate {
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {
        DispatchQueue.main.async {
            self.isSubscribed = Apphud.hasActiveSubscription()
        }
    }
    
    func apphudNonRenewingPurchasesUpdated(_ purchases: [ApphudNonRenewingPurchase]) {
        DispatchQueue.main.async {
            self.isSubscribed = Apphud.hasActiveSubscription()
        }
    }
}

@MainActor
final class StoreKitSubscriptionManager: ObservableObject {
    static let shared = StoreKitSubscriptionManager()
    private var appState = AppState()
    
    // MARK: - Published Properties
    @Published var isSubscribed: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Product IDs
    private let productIDs = [
        "week_6.99_nottrial",
        "yearly_49.99_nottrial"
    ]
    
    private var transactionUpdateTask: Task<Void, Never>? = nil
    
    private init() {
        Task {
            await fetchProducts()
            await updatePurchasedProducts()
            observeTransactionUpdates()
        }
    }
    
    deinit {
        transactionUpdateTask?.cancel()
    }
    
    // MARK: - Fetch Products
    func fetchProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIDs)
            print("✅ Products loaded: \(products.map { $0.id })")
        } catch {
            errorMessage = "Ошибка загрузки продуктов: \(error.localizedDescription)"
            print("❌ \(errorMessage)")
        }
    }
    
    // MARK: - Purchase Product
    func purchase(_ product: Product, completion: @escaping (Bool, String?) -> Void) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ Purchase success: \(transaction.productID)")
                    appState.hasSubscribed = true
                    await transaction.finish()
                    await updatePurchasedProducts()
                    completion(true, nil)
                case .unverified(_, _):
                    print("❌ Transaction unverified")
                }
            case .userCancelled:
                print("⚠️ User cancelled purchase")
            case .pending:
                print("⌛ Purchase pending")
            @unknown default:
                print("❓ Unknown purchase result")
            }
        } catch {
            errorMessage = "Ошибка покупки: \(error.localizedDescription)"
            print("❌ \(errorMessage)")
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        for await transaction in Transaction.currentEntitlements {
            if case .verified(let transaction) = transaction {
                print("🔄 Restored: \(transaction.productID)")
            }
        }
        
        await updatePurchasedProducts()
    }
    
    // MARK: - Update Purchased Products
    func updatePurchasedProducts() async {
        var hasActiveSubscription = false
        
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement {
                if let expirationDate = transaction.expirationDate, expirationDate > Date() {
                    hasActiveSubscription = true
                    break
                }
            }
        }
        appState.hasSubscribed = isSubscribed
        isSubscribed = hasActiveSubscription
        print("📌 isSubscribed = \(isSubscribed)")
    }
    
    // MARK: - Observe Transaction Updates
    private func observeTransactionUpdates() {
        transactionUpdateTask = Task.detached(priority: .background) {
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    print("🔔 Transaction update: \(transaction.productID)")
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }
    
    // MARK: - Helpers
    func getPriceString(for product: Product) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        return formatter.string(from: product.price as NSNumber) ?? ""
    }
    
    func getSubscriptionPeriod(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .day: return period.value == 1 ? "Daily" : "\(period.value) days"
        case .week: return period.value == 1 ? "Weekly" : "\(period.value) weeks"
        case .month: return period.value == 1 ? "Monthly" : "\(period.value) months"
        case .year: return period.value == 1 ? "Annual" : "\(period.value) years"
        @unknown default: return "Unknown"
        }
    }
}
