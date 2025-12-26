//
//  SettingsViewModel.swift
//  RemoteTVController
//

import SwiftUI
internal import StoreKit
internal import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var isSubscribed: Bool = false
    @Published var showRateUs: Bool = false
    @Published var showShareSheet: Bool = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let termsURL = URL(string: "https://docs.google.com/document/d/1rPxdnV02PWzUxGKP_aJps4ntmWOZ5LesWFGzdpPNeXA/edit?usp=sharing")!
    let privacyURL = URL(string: "https://docs.google.com/document/d/1ak3VZmfz2ODN2fTTg2RtBSV_HqsRLz0H_6EweqXw-QM/edit?usp=sharing")!
    let supportURL = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSdTPp5Lww2RdbRaOoS1va_vwj8t5Ps2B6HIO_liDZGJmepiaA/viewform?usp=publish-editor")!
    let appStoreURL = URL(string: "https://apps.apple.com/us/app/remote-tv-controller/id6757008745")!
    
    init() { isSubscribed = SubscriptionManager.shared.isSubscribed }
    
    func openManageSubscription() {
        UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!)
    }
    func openSupport() { UIApplication.shared.open(supportURL) }
    func openTerms() { UIApplication.shared.open(termsURL) }
    func openPrivacy() { UIApplication.shared.open(privacyURL) }
    func rateApp() {
        showRateUs = true
        AnalyticsService.shared.trackEvent(.rateUsShown, properties: ["type": "custom"])
    }
    func shareApp() { showShareSheet = true }
    func submitRating() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
        AnalyticsService.shared.trackEvent(.rateUsRated)
    }
}


