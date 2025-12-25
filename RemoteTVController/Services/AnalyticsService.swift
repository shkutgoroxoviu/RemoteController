//
//  AnalyticsService.swift
//  RemoteTVController
//

import Foundation
// import AmplitudeSwift // Uncomment when adding Amplitude SDK

enum AnalyticsEvent: String {
    case appLaunched = "app_launched"
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case deviceSearchStarted = "device_search_started"
    case deviceFound = "device_found"
    case deviceConnected = "device_connected"
    case deviceConnectionFailed = "device_connection_failed"
    case remoteButtonPressed = "remote_button_pressed"
    case paywallShown = "paywall_shown"
    case subscriptionPurchased = "subscription_purchased"
    case freeTrialStarted = "free_trial_started"
    case rateUsShown = "rate_us_shown"
    case rateUsRated = "rate_us_rated"
}

final class AnalyticsService {
    static let shared = AnalyticsService()
    private var isInitialized = false
    
    private init() {}
    
    func initialize() {
        guard !isInitialized else { return }
        // TODO: Amplitude.instance().initializeApiKey("YOUR_API_KEY")
        isInitialized = true
        print("📊 Analytics initialized")
    }
    
    func trackEvent(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        guard isInitialized else { return }
        // TODO: Amplitude.instance().logEvent(event.rawValue, withEventProperties: properties)
        #if DEBUG
        print("📊 Event: \(event.rawValue) | \(properties ?? [:])")
        #endif
    }
    
    func setUserId(_ userId: String) {
        // TODO: Amplitude.instance().setUserId(userId)
    }
    
    func setUserProperty(key: String, value: Any) {
        // TODO: Amplitude.instance().setUserProperties([key: value])
    }
}


