//
//  OnboardingViewModel.swift
//  RemoteTVController
//

import SwiftUI
import StoreKit
import Combine

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
}


