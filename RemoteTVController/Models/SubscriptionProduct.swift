//
//  SubscriptionProduct.swift
//  RemoteTVController
//

import Foundation
import StoreKit

// MARK: - Subscription Type
enum SubscriptionType: String, CaseIterable {
    case weekly = "weekly_subscription"
    case yearly = "yearly_subscription"
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .yearly: return "Annual"
        }
    }
    
    var productId: String { rawValue }
}

// MARK: - Subscription Product
struct SubscriptionProduct: Identifiable {
    let id: String
    let type: SubscriptionType
    let product: Product?
    
    var displayPrice: String {
        product?.displayPrice ?? "$0.00"
    }
    
    var pricePerWeek: String {
        guard let product = product else { return "$0.00" }
        
        switch type {
        case .weekly:
            return product.displayPrice
        case .yearly:
            let weeklyPrice = product.price / 52
            return weeklyPrice.formatted(.currency(code: product.priceFormatStyle.currencyCode))
        }
    }
    
    var hasFreeTrial: Bool {
        product?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
    
    var trialDuration: String? {
        guard let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        
        let value = offer.period.value
        switch offer.period.unit {
        case .day: return "\(value)-Day"
        case .week: return "\(value)-Week"
        case .month: return "\(value)-Month"
        case .year: return "\(value)-Year"
        @unknown default: return nil
        }
    }
    
    var savingsPercentage: Int? {
        type == .yearly ? 70 : nil
    }
}

// MARK: - Subscription Status
enum SubscriptionStatus {
    case notSubscribed
    case subscribed(expirationDate: Date?)
    case inTrial(expirationDate: Date?)
    case expired
    
    var isActive: Bool {
        switch self {
        case .subscribed, .inTrial: return true
        default: return false
        }
    }
}


