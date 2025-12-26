//
//  RootView.swift
//  RemoteTVController
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ZStack {
            if !appState.hasCompletedOnboarding {
                OnboardingContainerView()
            } else {
                MainTabView()
            }
        }
        .fullScreenCover(isPresented: $appState.showPaywall) {
            PaywallView()
        }
    }
}



