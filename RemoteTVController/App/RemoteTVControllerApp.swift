//
//  RemoteTVControllerApp.swift
//  RemoteTVController
//
//  Created for 5032 Remote TV Controller
//

import SwiftUI

@main
struct RemoteTVControllerApp: App {
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var tvManager = TVConnectionManager.shared
    
    @State private var showSplash = true  
    
    init() {
        AnalyticsService.shared.initialize()
//        SubscriptionManager.shared.initialize()
        AnalyticsService.shared.trackEvent(.appLaunched)
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    RootView()
                        .environmentObject(appState)
                        .environmentObject(subscriptionManager)
                        .environmentObject(tvManager)
                        .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation(.easeOut(duration: 0.35)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
