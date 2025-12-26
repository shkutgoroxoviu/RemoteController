//
//  AppState.swift
//  RemoteTVController
//

import SwiftUI
internal import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    // MARK: - Published Properties
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboardingCompleted)
        }
    }
    
    @Published var currentOnboardingPage: Int {
        didSet {
            UserDefaults.standard.set(currentOnboardingPage, forKey: Keys.onboardingPage)
        }
    }
    
    @Published var hasShownInitialPaywall: Bool {
        didSet {
            UserDefaults.standard.set(hasShownInitialPaywall, forKey: Keys.initialPaywallShown)
        }
    }
    
    @Published var hasSubscribed: Bool {
        didSet {
            UserDefaults.standard.set(hasSubscribed, forKey: Keys.hasSub)
        }
    }
    
    @Published var hasShownCustomRateUs: Bool {
        didSet {
            UserDefaults.standard.set(hasShownCustomRateUs, forKey: Keys.customRateUsShown)
        }
    }
    
    @Published var sessionPaywallShown: Bool = false
    @Published var showPaywall: Bool = false
    @Published var paywallTrigger: PaywallTrigger = .onboarding
    
    // MARK: - Timer
    private var paywallTimer: Timer?
    private var sessionStartTime: Date?
    
    // MARK: - Keys
    private enum Keys {
        static let onboardingCompleted = "onboarding_completed"
        static let onboardingPage = "onboarding_page"
        static let initialPaywallShown = "initial_paywall_shown"
        static let customRateUsShown = "custom_rate_us_shown"
        static let hasSub = "subcribed"
    }
    
    // MARK: - Init
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.onboardingCompleted)
        self.currentOnboardingPage = UserDefaults.standard.integer(forKey: Keys.onboardingPage)
        self.hasShownInitialPaywall = UserDefaults.standard.bool(forKey: Keys.initialPaywallShown)
        self.hasShownCustomRateUs = UserDefaults.standard.bool(forKey: Keys.customRateUsShown)
        self.hasSubscribed = UserDefaults.standard.bool(forKey: Keys.hasSub)
        
        startSessionTimer()
    }
    
    // MARK: - Session Timer
    private func startSessionTimer() {
        sessionStartTime = Date()
        
        paywallTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard !(self?.hasSubscribed ?? false) else { return }
                self?.checkSessionPaywall()
            }
        }
    }
    
    private func checkSessionPaywall() {
        guard !sessionPaywallShown,
              !SubscriptionManager.shared.isSubscribed,
              hasCompletedOnboarding else { return }
        
        sessionPaywallShown = true
        paywallTrigger = .sessionTimer
        showPaywall = true
        AnalyticsService.shared.trackEvent(.paywallShown, properties: ["trigger": "session_timer"])
    }
    
    // MARK: - Paywall Triggers
    func triggerPaywall(for reason: PaywallTrigger) {
        guard !SubscriptionManager.shared.isSubscribed else { return }
        
        paywallTrigger = reason
        showPaywall = true
        AnalyticsService.shared.trackEvent(.paywallShown, properties: ["trigger": reason.rawValue])
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        currentOnboardingPage = 0
    }
    
    deinit {
        paywallTimer?.invalidate()
    }
}

// MARK: - Paywall Trigger
enum PaywallTrigger: String {
    case onboarding
    case premiumFeature = "premium_feature"
    case secondDevice = "second_device"
    case sessionTimer = "session_timer"
}


