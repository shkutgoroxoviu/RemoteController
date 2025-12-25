//
//  SubscriptionManager.swift
//  RemoteTVController
//

import Foundation
import StoreKit
import Combine
// import ApphudSDK // Uncomment when adding Apphud

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var subscriptionStatus: SubscriptionStatus = .notSubscribed
    @Published private(set) var products: [SubscriptionProduct] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {}
    
    func initialize() {
        // TODO: Apphud.start(apiKey: "YOUR_APPHUD_KEY")
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
        print("💳 Subscription Manager initialized")
    }
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIds = SubscriptionType.allCases.map { $0.productId }
            let storeProducts = try await Product.products(for: productIds)
            
            products = storeProducts.compactMap { product in
                guard let type = SubscriptionType.allCases.first(where: { $0.productId == product.id }) else { return nil }
                return SubscriptionProduct(id: product.id, type: type, product: product)
            }.sorted { $0.type == .weekly && $1.type == .yearly }
            
            isLoading = false
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func purchase(_ product: SubscriptionProduct) async -> Bool {
        guard let storeProduct = product.product else {
            errorMessage = "Product not available"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await storeProduct.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()
                
                AnalyticsService.shared.trackEvent(.subscriptionPurchased, properties: [
                    "product_id": product.id, "type": product.type.rawValue
                ])
                
                if product.hasFreeTrial {
                    AnalyticsService.shared.trackEvent(.freeTrialStarted)
                }
                
                isLoading = false
                return true
                
            case .userCancelled, .pending:
                isLoading = false
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            isLoading = false
            return isSubscribed
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func checkSubscriptionStatus() async {
        var foundActive = false
        
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productType == .autoRenewable {
                foundActive = true
                if let exp = transaction.expirationDate {
                    subscriptionStatus = transaction.offerType == .introductory
                        ? .inTrial(expirationDate: exp)
                        : .subscribed(expirationDate: exp)
                } else {
                    subscriptionStatus = .subscribed(expirationDate: nil)
                }
            }
        }
        
        if !foundActive { subscriptionStatus = .notSubscribed }
        isSubscribed = foundActive
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? await self.checkVerified(result) {
                    await self.checkSubscriptionStatus()
                    await transaction.finish()
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }
    
    deinit { updateListenerTask?.cancel() }
}

enum StoreError: Error { case failedVerification }


