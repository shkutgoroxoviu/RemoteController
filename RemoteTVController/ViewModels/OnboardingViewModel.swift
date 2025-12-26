//
//  OnboardingViewModel.swift
//  RemoteTVController
//

import SwiftUI
internal import StoreKit
internal import Combine
import AppTrackingTransparency
import ApphudSDK
import AdSupport

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentPage: Int
    
    let pages = OnboardingPage.pages
    var isLastPage: Bool { currentPage == pages.count - 1 }
    var currentPageData: OnboardingPage { pages[currentPage] }
    
    init(startPage: Int = 0) {
        self.currentPage = startPage
        if startPage == 0 {
            AnalyticsService.shared.trackEvent(.onboardingStarted)
        }
    }
    
    func nextPage() {
        if isLastPage {
            completeOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        }
    }
    
    func completeOnboarding() {
        AnalyticsService.shared.trackEvent(.onboardingCompleted)
        requestSystemReview()
    }
    
    private func requestSystemReview() {
        AnalyticsService.shared.trackEvent(.rateUsShown, properties: ["type": "system"])
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func requestIDFAPermission() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if #available(iOS 14, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                        Apphud.setDeviceIdentifiers(idfa: idfa, idfv: UIDevice.current.identifierForVendor?.uuidString)
                        print("IDFA access granted:", ASIdentifierManager.shared().advertisingIdentifier)
                    case .denied:
                        print("IDFA denied")
                    case .notDetermined:
                        print("IDFA not determined")
                    case .restricted:
                        print("IDFA restricted")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}


